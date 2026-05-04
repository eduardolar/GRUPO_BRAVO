import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../components/Cliente/campos_tarjeta.dart';
import '../../components/Cliente/empty_state.dart';
import '../../core/colors_style.dart';
import '../../models/opciones_pedido.dart';
import '../../providers/auth_provider.dart';
import '../../providers/cart_provider.dart';
import '../../services/api_service.dart';
import 'direccion_screen.dart';
import 'pedido_confirmado_screen.dart';

export '../../models/opciones_pedido.dart';

const double _kCosteEnvio = 3.99;
const double _kMaxContentWidth = 560;
const Duration _kAnimFast = Duration(milliseconds: 200);
const Duration _kAnimMed = Duration(milliseconds: 250);
const BorderRadius _kRadius = BorderRadius.all(Radius.circular(12));

enum _Paso { confirmar, entrega, pago }

extension on _Paso {
  String get titulo => switch (this) {
        _Paso.confirmar => 'CONFIRMAR',
        _Paso.entrega => 'ENTREGA',
        _Paso.pago => 'PAGO',
      };

  _Paso? get anterior => switch (this) {
        _Paso.confirmar => null,
        _Paso.entrega => _Paso.confirmar,
        _Paso.pago => _Paso.entrega,
      };
}

class PantallaOpcionesEntrega extends StatefulWidget {
  const PantallaOpcionesEntrega({super.key});

  @override
  State<PantallaOpcionesEntrega> createState() =>
      _PantallaOpcionesEntregaState();
}

class _PantallaOpcionesEntregaState extends State<PantallaOpcionesEntrega> {
  _Paso _paso = _Paso.confirmar;
  late OpcionEntrega _entregaSeleccionada;
  MetodoPago _pagoSeleccionado = MetodoPago.efectivo;
  OpcionDireccion _direccionSeleccionada = OpcionDireccion.registrada;
  bool _estaCargando = false;

  bool _googlePayAutorizado = false;
  bool _googlePayProcesando = false;
  bool _paypalAutorizado = false;
  bool _applePayAutorizado = false;
  String? _paypalOrderId;
  String? _googlePayClientSecret;
  String? _googlePayPaymentIntentId;
  CardFieldInputDetails? _cardDetails;

  final _controladorDireccion = TextEditingController();
  final _controladorNotas = TextEditingController();

  @override
  void initState() {
    super.initState();
    final cart = context.read<CartProvider>();
    _entregaSeleccionada =
        cart.tienemesa ? OpcionEntrega.enMesa : OpcionEntrega.domicilio;
  }

  @override
  void dispose() {
    _controladorDireccion.dispose();
    _controladorNotas.dispose();
    super.dispose();
  }

  // ── Helpers ────────────────────────────────────────────────────────────

  double _costeEnvio() =>
      _entregaSeleccionada == OpcionEntrega.domicilio ? _kCosteEnvio : 0.0;

  double _calcularTotal(CartProvider cart) => cart.totalPrice + _costeEnvio();

  String _formatoEuro(double v) =>
      '${v.toStringAsFixed(2).replaceAll('.', ',')} €';

  void _resetAutorizacionesWallet() {
    _googlePayAutorizado = false;
    _googlePayProcesando = false;
    _googlePayClientSecret = null;
    _googlePayPaymentIntentId = null;
    _paypalAutorizado = false;
    _paypalOrderId = null;
    _applePayAutorizado = false;
  }

  void _seleccionarMetodoPago(MetodoPago metodo) {
    setState(() {
      _pagoSeleccionado = metodo;
      _resetAutorizacionesWallet();
    });
  }

  void _showSnack(String mensaje, {bool error = false}) {
    final messenger = ScaffoldMessenger.of(context)..clearSnackBars();
    messenger.showSnackBar(
      SnackBar(
        content: Text(mensaje),
        backgroundColor: error ? AppColors.error : Colors.green.shade700,
        behavior: SnackBarBehavior.floating,
        shape: const RoundedRectangleBorder(borderRadius: _kRadius),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      ),
    );
  }

  String _tipoEntregaLabel(OpcionEntrega e) => switch (e) {
        OpcionEntrega.domicilio => 'Entrega a domicilio',
        OpcionEntrega.recoger => 'Recoger en restaurante',
        OpcionEntrega.enMesa => 'Comer en el local',
      };

  String _tipoPagoLabel(MetodoPago m) => switch (m) {
        MetodoPago.efectivo => 'Efectivo',
        MetodoPago.tarjeta => 'Tarjeta',
        MetodoPago.googlePay => 'Google Pay',
        MetodoPago.paypal => 'PayPal',
        MetodoPago.applePay => 'Apple Pay',
      };

  Future<bool> _confirmarSalida() async {
    final cart = context.read<CartProvider>();
    if (cart.itemCount == 0) return true;
    final salir = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.panel,
        shape: const RoundedRectangleBorder(borderRadius: _kRadius),
        title: const Text('¿Salir del proceso?'),
        content: const Text(
          'Tu carrito se conservará, pero perderás los datos introducidos en este flujo.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text(
              'Salir',
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
    return salir ?? false;
  }

  // ── Build ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (_paso != _Paso.confirmar) {
          setState(() => _paso = _paso.anterior!);
          return;
        }
        final navigator = Navigator.of(context);
        final salir = await _confirmarSalida();
        if (!mounted) return;
        if (salir) navigator.pop();
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            const _FondoConVelado(),
            SafeArea(
              child: Column(
                children: [
                  _Header(
                    titulo: _paso.titulo,
                    onBack: () async {
                      if (_paso != _Paso.confirmar) {
                        setState(() => _paso = _paso.anterior!);
                        return;
                      }
                      final navigator = Navigator.of(context);
                      final salir = await _confirmarSalida();
                      if (!mounted) return;
                      if (salir) navigator.pop();
                    },
                  ),
                  _StepIndicator(paso: _paso),
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: _kAnimMed,
                      transitionBuilder: (child, animation) => SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0.06, 0),
                          end: Offset.zero,
                        ).animate(
                          CurvedAnimation(
                            parent: animation,
                            curve: Curves.easeOut,
                          ),
                        ),
                        child:
                            FadeTransition(opacity: animation, child: child),
                      ),
                      child: KeyedSubtree(
                        key: ValueKey(_paso),
                        child: _buildPasoActual(),
                      ),
                    ),
                  ),
                  _BottomBar(
                    paso: _paso,
                    cargando: _estaCargando,
                    costeEnvio: _costeEnvio(),
                    onSiguiente: switch (_paso) {
                      _Paso.confirmar =>
                        () => setState(() => _paso = _Paso.entrega),
                      _Paso.entrega => _irAPago,
                      _Paso.pago => _confirmarPedido,
                    },
                    onAtras: _paso != _Paso.confirmar
                        ? () => setState(() => _paso = _paso.anterior!)
                        : null,
                  ),
                ],
              ),
            ),
            if (_estaCargando) const _OverlayCargando(),
          ],
        ),
      ),
    );
  }

  Widget _buildPasoActual() {
    return switch (_paso) {
      _Paso.confirmar => _buildPasoConfirmar(),
      _Paso.entrega => _buildPasoEntrega(),
      _Paso.pago => _buildPasoPago(),
    };
  }

  Widget _buildPasoConfirmar() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final hPad = _hPad(constraints);
        return Consumer<CartProvider>(
          builder: (context, cart, _) {
            if (cart.itemCount == 0) {
              return const EmptyState.dark(
                icon: Icons.shopping_bag_outlined,
                title: 'Tu carrito está vacío',
                subtitle: 'Explora el menú y añade productos para continuar.',
              );
            }
            return ListView.separated(
              physics: const BouncingScrollPhysics(),
              padding: EdgeInsets.fromLTRB(hPad, 16, hPad, 24),
              itemCount: cart.items.length + 1,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, i) {
                if (i == 0) return _subtituloPaso('Revisa tu pedido');
                final item = cart.items.values.elementAt(i - 1);
                return Dismissible(
                  key: ValueKey('cart-${item.key}'),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20),
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.85),
                      borderRadius: _kRadius,
                    ),
                    child: const Icon(
                      Icons.delete_outline,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                  onDismissed: (_) {
                    final removed = item;
                    cart.removeProduct(removed.key);
                    ScaffoldMessenger.of(context)
                      ..clearSnackBars()
                      ..showSnackBar(
                        SnackBar(
                          content:
                              Text('${removed.producto.nombre} eliminado'),
                          action: SnackBarAction(
                            label: 'DESHACER',
                            onPressed: () => cart.addItem(
                              removed.producto,
                              ingredientesExcluidos:
                                  removed.ingredientesExcluidos,
                              cantidad: removed.cantidad,
                            ),
                          ),
                          duration: const Duration(seconds: 4),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                  },
                  child: _ArticuloCard(item: item, cart: cart),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildPasoEntrega() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final hPad = _hPad(constraints);
        return Consumer<CartProvider>(
          builder: (context, cart, _) {
            return SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: EdgeInsets.symmetric(horizontal: hPad, vertical: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _subtituloPaso('¿Cómo quieres recibir tu pedido?'),
                  const SizedBox(height: 18),
                  if (cart.tienemesa) ...[
                    _EntregaCard(
                      icono: Icons.restaurant,
                      titulo: 'Mesa ${cart.numeroMesa}',
                      subtitulo: 'Te lo servimos directamente · ~15-20 min',
                      coste: 'Gratis',
                      seleccionada:
                          _entregaSeleccionada == OpcionEntrega.enMesa,
                      onTap: () => setState(
                        () => _entregaSeleccionada = OpcionEntrega.enMesa,
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  _EntregaCard(
                    icono: Icons.delivery_dining,
                    titulo: 'A domicilio',
                    subtitulo: 'En la puerta de tu casa · ~35-50 min',
                    coste: '+${_formatoEuro(_kCosteEnvio)}',
                    seleccionada:
                        _entregaSeleccionada == OpcionEntrega.domicilio,
                    onTap: () => setState(
                      () => _entregaSeleccionada = OpcionEntrega.domicilio,
                    ),
                  ),
                  AnimatedSize(
                    duration: _kAnimFast,
                    curve: Curves.easeOut,
                    alignment: Alignment.topCenter,
                    child: _entregaSeleccionada == OpcionEntrega.domicilio
                        ? Padding(
                            padding: const EdgeInsets.only(top: 14),
                            child: _seccionDireccion(),
                          )
                        : const SizedBox(width: double.infinity),
                  ),
                  const SizedBox(height: 12),
                  _EntregaCard(
                    icono: Icons.store_outlined,
                    titulo: 'Recoger en local',
                    subtitulo: 'Listo cuando llegues · ~20-30 min',
                    coste: 'Gratis',
                    seleccionada:
                        _entregaSeleccionada == OpcionEntrega.recoger,
                    onTap: () => setState(
                      () => _entregaSeleccionada = OpcionEntrega.recoger,
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildPasoPago() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final hPad = _hPad(constraints);
        return SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.symmetric(horizontal: hPad, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _subtituloPaso('Elige cómo quieres pagar'),
              const SizedBox(height: 18),
              _PagoCard(
                icono: Icons.payments_outlined,
                titulo: 'Efectivo',
                subtitulo: 'Pagas al recibir el pedido',
                seleccionada: _pagoSeleccionado == MetodoPago.efectivo,
                onTap: () => _seleccionarMetodoPago(MetodoPago.efectivo),
              ),
              const SizedBox(height: 10),
              _PagoCard(
                icono: Icons.credit_card,
                titulo: 'Tarjeta',
                subtitulo: 'Crédito o débito',
                seleccionada: _pagoSeleccionado == MetodoPago.tarjeta,
                onTap: () => _seleccionarMetodoPago(MetodoPago.tarjeta),
              ),
              AnimatedSize(
                duration: _kAnimFast,
                curve: Curves.easeOut,
                alignment: Alignment.topCenter,
                child: _pagoSeleccionado == MetodoPago.tarjeta
                    ? Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: _FormPanel(
                          child: CamposTarjeta(
                            onCardChanged: (details) =>
                                setState(() => _cardDetails = details),
                          ),
                        ),
                      )
                    : const SizedBox(width: double.infinity),
              ),
              const SizedBox(height: 10),
              _PagoCard(
                icono: Icons.android,
                titulo: 'Google Pay',
                subtitulo: 'Pago rápido con Google',
                seleccionada: _pagoSeleccionado == MetodoPago.googlePay,
                onTap: () => _seleccionarMetodoPago(MetodoPago.googlePay),
              ),
              AnimatedSize(
                duration: _kAnimFast,
                curve: Curves.easeOut,
                alignment: Alignment.topCenter,
                child: _pagoSeleccionado == MetodoPago.googlePay
                    ? Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: _buildGooglePayButton(),
                      )
                    : const SizedBox(width: double.infinity),
              ),
              const SizedBox(height: 10),
              _PagoCard(
                icono: Icons.account_balance_wallet_outlined,
                titulo: 'PayPal',
                subtitulo: 'Paga con tu cuenta de PayPal',
                seleccionada: _pagoSeleccionado == MetodoPago.paypal,
                onTap: () => _seleccionarMetodoPago(MetodoPago.paypal),
              ),
              AnimatedSize(
                duration: _kAnimFast,
                curve: Curves.easeOut,
                alignment: Alignment.topCenter,
                child: _pagoSeleccionado == MetodoPago.paypal
                    ? Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: _buildPaypalButton(),
                      )
                    : const SizedBox(width: double.infinity),
              ),
              const SizedBox(height: 10),
              _PagoCard(
                icono: Icons.apple,
                titulo: 'Apple Pay',
                subtitulo: 'Paga con Apple Pay',
                seleccionada: _pagoSeleccionado == MetodoPago.applePay,
                onTap: () => _seleccionarMetodoPago(MetodoPago.applePay),
              ),
              AnimatedSize(
                duration: _kAnimFast,
                curve: Curves.easeOut,
                alignment: Alignment.topCenter,
                child: _pagoSeleccionado == MetodoPago.applePay
                    ? Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: _buildApplePayButton(),
                      )
                    : const SizedBox(width: double.infinity),
              ),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }

  Widget _seccionDireccion() {
    return Consumer<AuthProvider>(
      builder: (context, auth, _) {
        final dir = auth.usuarioActual?.direccion ?? '';
        return Column(
          children: [
            _DireccionOption(
              icono: Icons.home_outlined,
              titulo: 'Dirección registrada',
              subtitulo:
                  dir.isNotEmpty ? dir : 'No tienes dirección guardada',
              seleccionada:
                  _direccionSeleccionada == OpcionDireccion.registrada,
              onTap: () => setState(
                () => _direccionSeleccionada = OpcionDireccion.registrada,
              ),
            ),
            const SizedBox(height: 8),
            _DireccionOption(
              icono: Icons.map_outlined,
              titulo: 'Cambiar o usar mapa / GPS',
              subtitulo: 'Selecciona tu ubicación exacta en el mapa',
              seleccionada:
                  _direccionSeleccionada == OpcionDireccion.alternativa,
              onTap: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const DireccionScreen(),
                  ),
                );
                if (!mounted) return;
                setState(
                  () => _direccionSeleccionada = OpcionDireccion.registrada,
                );
              },
            ),
          ],
        );
      },
    );
  }

  void _irAPago() {
    if (_entregaSeleccionada == OpcionEntrega.domicilio) {
      final auth = context.read<AuthProvider>();
      final usuario = auth.usuarioActual;
      if (usuario == null || usuario.direccion.isEmpty) {
        _showSnack(
          'Por favor, selecciona una ubicación en el mapa.',
          error: true,
        );
        return;
      }
    }
    setState(() => _paso = _Paso.pago);
  }

  Future<void> _confirmarPedido() async {
    if (_estaCargando) return;
    switch (_pagoSeleccionado) {
      case MetodoPago.efectivo:
        await _procesarEfectivoYCrearPedido();
      case MetodoPago.tarjeta:
        await _procesarTarjetaYCrearPedido();
      case MetodoPago.googlePay:
        await _procesarGooglePayYCrearPedido();
      case MetodoPago.paypal:
        await _procesarPaypalYCrearPedido();
      case MetodoPago.applePay:
        if (_applePayAutorizado) {
          await _procesarApplePayYCrearPedido();
        } else {
          _showSnack('Primero autoriza Apple Pay', error: true);
        }
    }
  }

  // ── Procesadores de pago ────────────────────────────────────────────────

  Future<void> _procesarEfectivoYCrearPedido() async {
    setState(() => _estaCargando = true);
    await _crearPedidoFinal(referenciaPago: null, estadoPago: 'pendiente');
  }

  Future<void> _procesarTarjetaYCrearPedido() async {
    if (kIsWeb) {
      await _procesarStripeCheckoutWeb();
      return;
    }

    if (_cardDetails == null || !_cardDetails!.complete) {
      _showSnack('Completa los datos de la tarjeta', error: true);
      return;
    }

    setState(() => _estaCargando = true);

    try {
      final cart = context.read<CartProvider>();
      final total = _calcularTotal(cart);

      final intent = await ApiService.crearIntentoTarjeta(
        amount: total,
        currency: 'eur',
      );

      final paymentIntentId = intent['payment_intent_id']?.toString();
      final clientSecret = intent['client_secret']?.toString();

      if (paymentIntentId == null || clientSecret == null) {
        throw Exception('No se pudo iniciar el pago con tarjeta');
      }

      final paymentIntent = await Stripe.instance.confirmPayment(
        paymentIntentClientSecret: clientSecret,
        data: const PaymentMethodParams.card(
          paymentMethodData: PaymentMethodData(),
        ),
      );

      if (paymentIntent.status != PaymentIntentsStatus.Succeeded) {
        throw Exception('El pago no fue completado');
      }

      await _crearPedidoFinal(
        referenciaPago: paymentIntentId,
        estadoPago: 'pagado',
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _estaCargando = false);
      _showSnack('Error en el pago con tarjeta: $e', error: true);
    }
  }

  Future<void> _procesarStripeCheckoutWeb() async {
    setState(() => _estaCargando = true);
    String? pedidoId;
    String? sessionId;
    String tipoEntregaStr = '';
    double total = 0;
    List<Map<String, dynamic>> itemsResumen = [];

    try {
      final cart = context.read<CartProvider>();
      final auth = context.read<AuthProvider>();
      total = _calcularTotal(cart);
      final origin = Uri.base.origin;

      tipoEntregaStr = _tipoEntregaLabel(_entregaSeleccionada);

      final items = cart.items.values
          .map((item) => {
                'producto_id': item.producto.id,
                'nombre': item.producto.nombre,
                'cantidad': item.cantidad,
                'precio': item.producto.precio,
                if (item.ingredientesExcluidos.isNotEmpty)
                  'sin': item.ingredientesExcluidos,
              })
          .toList();

      itemsResumen = cart.items.values
          .map((item) => {
                'nombre': item.producto.nombre,
                'cantidad': item.cantidad,
                'precio': item.producto.precio,
                if (item.ingredientesExcluidos.isNotEmpty)
                  'sin': item.ingredientesExcluidos,
              })
          .toList();

      final direccionEntrega = _entregaSeleccionada == OpcionEntrega.domicilio
          ? (_direccionSeleccionada == OpcionDireccion.registrada
              ? (auth.usuarioActual?.direccion ?? '')
              : _controladorDireccion.text.trim())
          : null;

      // 1. Crear sesión Stripe
      final totalStr = total.toStringAsFixed(2);
      final session = await ApiService.crearCheckoutSession(
        total: total,
        currency: 'eur',
        successUrl: '$origin/?stripe_session={CHECKOUT_SESSION_ID}'
            '&entrega=${Uri.encodeComponent(tipoEntregaStr)}'
            '&total=$totalStr',
        cancelUrl: '$origin/?stripe_cancel=1',
      );

      final checkoutUrl = session['checkout_url']?.toString();
      sessionId = session['session_id']?.toString();

      if (checkoutUrl == null || sessionId == null) {
        throw Exception('No se pudo iniciar la sesión de pago');
      }

      // 2. Crear el pedido (estado pendiente_stripe) — el carrito se mantiene
      //    intacto hasta que confirmemos el pago.
      if (_entregaSeleccionada != OpcionEntrega.enMesa) {
        cart.desasignarMesa();
      }

      final resultado = await ApiService.crearPedido(
        userId: auth.usuarioActual?.id ?? '',
        items: items,
        tipoEntrega: tipoEntregaStr,
        metodoPago: 'Tarjeta',
        total: total,
        direccionEntrega: direccionEntrega,
        mesaId: _entregaSeleccionada == OpcionEntrega.enMesa
            ? cart.mesaId
            : null,
        numeroMesa: _entregaSeleccionada == OpcionEntrega.enMesa
            ? cart.numeroMesa
            : null,
        notas: _controladorNotas.text.trim(),
        referenciaPago: sessionId,
        estadoPago: 'pendiente_stripe',
        restauranteId: cart.restauranteId,
      );

      pedidoId =
          resultado['id']?.toString() ?? resultado['pedido_id']?.toString();

      if (!mounted) return;
      setState(() => _estaCargando = false);

      // 3. Abrir Stripe en otra pestaña
      await launchUrl(Uri.parse(checkoutUrl), webOnlyWindowName: '_blank');

      if (!mounted) return;

      // 4. Diálogo de verificación
      final confirmado = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (_) => _StripeCheckoutDialog(sessionId: sessionId!),
      );

      if (confirmado != true || !mounted) return;

      try {
        await ApiService.actualizarEstadoPago(referenciaPago: sessionId);
      } catch (e) {
        debugPrint('actualizarEstadoPago fallo: $e');
      }
      if (!mounted) return;

      // Limpiar el carrito sólo cuando el pago está confirmado
      context.read<CartProvider>().clearCart();

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (_) => PedidoConfirmadoScreen(
            tipoEntrega: tipoEntregaStr,
            tipoPago: 'Tarjeta',
            total: total,
            pedidoId: pedidoId,
            items: itemsResumen,
          ),
        ),
        (route) => route.isFirst,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _estaCargando = false);
      _showSnack('Error en el pago con Stripe: $e', error: true);
    }
  }

  Future<void> _procesarGooglePayYCrearPedido() async {
    if (!_googlePayAutorizado || _googlePayClientSecret == null) {
      _showSnack('Primero autoriza Google Pay', error: true);
      return;
    }
    setState(() => _estaCargando = true);
    try {
      await Stripe.instance.presentPaymentSheet();
      await _crearPedidoFinal(
        referenciaPago: _googlePayPaymentIntentId,
        estadoPago: 'pagado',
      );
    } on StripeException catch (e) {
      if (!mounted) return;
      setState(() {
        _estaCargando = false;
        _resetAutorizacionesWallet();
      });
      _showSnack(
        'Pago de Google Pay cancelado o fallido: '
        '${e.error.localizedMessage ?? e.error.message}',
        error: true,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _estaCargando = false;
        _resetAutorizacionesWallet();
      });
      _showSnack('Error en Google Pay: $e', error: true);
    }
  }

  Future<void> _procesarPaypalYCrearPedido() async {
    if (!_paypalAutorizado || _paypalOrderId == null) {
      _showSnack('Primero completa el pago en PayPal', error: true);
      return;
    }
    setState(() => _estaCargando = true);
    try {
      final orderId = _paypalOrderId!;
      final captura = await ApiService.capturarOrdenPaypal(orderId: orderId);
      final status = (captura['status'] ?? '').toString().toUpperCase();

      final completado = status == 'COMPLETED' ||
          captura['success'] == true ||
          captura['approved'] == true;

      if (!completado) {
        throw Exception('PayPal no devolvió un pago completado');
      }

      await _crearPedidoFinal(
        referenciaPago: (captura['id'] ?? orderId).toString(),
        estadoPago: 'pagado',
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _estaCargando = false);
      _showSnack('Error en PayPal: $e', error: true);
    }
  }

  Future<void> _crearPedidoFinal({
    String? referenciaPago,
    String? estadoPago,
  }) async {
    final auth = context.read<AuthProvider>();
    final cart = context.read<CartProvider>();

    final tipoPagoStr = _tipoPagoLabel(_pagoSeleccionado);
    final tipoEntrega = _tipoEntregaLabel(_entregaSeleccionada);
    final total = _calcularTotal(cart);

    final direccionEntrega = _entregaSeleccionada == OpcionEntrega.domicilio
        ? (_direccionSeleccionada == OpcionDireccion.registrada
            ? (auth.usuarioActual?.direccion ?? '')
            : _controladorDireccion.text.trim())
        : null;

    try {
      final items = cart.items.values
          .map((item) => {
                'producto_id': item.producto.id,
                'nombre': item.producto.nombre,
                'cantidad': item.cantidad,
                'precio': item.producto.precio,
                if (item.ingredientesExcluidos.isNotEmpty)
                  'sin': item.ingredientesExcluidos,
              })
          .toList();

      if (_entregaSeleccionada != OpcionEntrega.enMesa) {
        cart.desasignarMesa();
      }

      final itemsResumen = cart.items.values
          .map((item) => {
                'nombre': item.producto.nombre,
                'cantidad': item.cantidad,
                'precio': item.producto.precio,
                if (item.ingredientesExcluidos.isNotEmpty)
                  'sin': item.ingredientesExcluidos,
              })
          .toList();

      final resultado = await ApiService.crearPedido(
        userId: auth.usuarioActual?.id ?? '',
        items: items,
        tipoEntrega: tipoEntrega,
        metodoPago: tipoPagoStr,
        total: total,
        direccionEntrega: direccionEntrega,
        mesaId: _entregaSeleccionada == OpcionEntrega.enMesa
            ? cart.mesaId
            : null,
        numeroMesa: _entregaSeleccionada == OpcionEntrega.enMesa
            ? cart.numeroMesa
            : null,
        notas: _controladorNotas.text.trim(),
        referenciaPago: referenciaPago,
        estadoPago: estadoPago ??
            (_pagoSeleccionado == MetodoPago.efectivo
                ? 'pendiente'
                : 'pagado'),
        restauranteId: cart.restauranteId,
      );

      final pedidoId =
          resultado['id']?.toString() ?? resultado['pedido_id']?.toString();

      cart.clearCart();

      if (!mounted) return;
      setState(() => _estaCargando = false);
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (_) => PedidoConfirmadoScreen(
            tipoEntrega: tipoEntrega,
            tipoPago: tipoPagoStr,
            total: total,
            pedidoId: pedidoId,
            items: itemsResumen,
          ),
        ),
        (route) => route.isFirst,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _estaCargando = false);
      _showSnack('Error al crear pedido: $e', error: true);
    }
  }

  // ── Botones específicos de wallet ───────────────────────────────────────

  Widget _buildGooglePayButton() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: const [
              BoxShadow(
                color: Color(0x33000000),
                blurRadius: 18,
                offset: Offset(0, 10),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: (_estaCargando || _googlePayProcesando)
                  ? null
                  : _autorizarGooglePayFrontend,
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF5F5F5),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          alignment: Alignment.center,
                          child: const Text(
                            'G',
                            style: TextStyle(
                              color: Colors.black,
                              fontSize: 24,
                              fontWeight: FontWeight.w700,
                              height: 1,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Google Pay',
                                style: TextStyle(
                                  color: Colors.black,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Paga al instante con tu tarjeta guardada',
                                style: TextStyle(
                                  color: Color(0xFF5F6368),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          _googlePayAutorizado
                              ? Icons.verified_rounded
                              : Icons.chevron_right_rounded,
                          color: _googlePayAutorizado
                              ? const Color(0xFF1A8E3E)
                              : Colors.black54,
                          size: 22,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    AnimatedContainer(
                      duration: _kAnimFast,
                      width: double.infinity,
                      height: 54,
                      decoration: BoxDecoration(
                        color: Colors.black,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Center(
                        child: _googlePayProcesando
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2.2,
                                ),
                              )
                            : const _LogoGooglePayButton(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Icon(
                          _googlePayAutorizado
                              ? Icons.lock_clock_outlined
                              : Icons.lock_outline_rounded,
                          size: 16,
                          color: _googlePayAutorizado
                              ? const Color(0xFF1A8E3E)
                              : const Color(0xFF5F6368),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _googlePayAutorizado
                                ? 'Método autorizado. Pulsa CONFIRMAR PEDIDO para abrir la hoja de pago segura.'
                                : 'Tus datos se tokenizan y se procesan en una hoja segura de Google Pay.',
                            style: const TextStyle(
                              color: Color(0xFF5F6368),
                              fontSize: 11.5,
                              height: 1.35,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.08),
            borderRadius: _kRadius,
            border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                _googlePayAutorizado
                    ? Icons.check_circle
                    : Icons.info_outline_rounded,
                color: _googlePayAutorizado
                    ? Colors.greenAccent
                    : Colors.white70,
                size: 18,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _googlePayAutorizado
                      ? 'Google Pay listo. Verás tu tarjeta predeterminada y podrás validar con huella, PIN o desbloqueo del dispositivo.'
                      : 'Experiencia de cartera digital: tarjeta guardada, autenticación del dispositivo y confirmación rápida.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.82),
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPaypalButton() {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.paypal,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 15),
              shape: const RoundedRectangleBorder(borderRadius: _kRadius),
              elevation: 0,
            ),
            onPressed: _estaCargando ? null : _autorizarPaypalFrontend,
            icon: const Icon(Icons.account_balance_wallet_outlined),
            label: const Text(
              'PAGAR CON PAYPAL',
              style: TextStyle(fontWeight: FontWeight.w700, letterSpacing: 1),
            ),
          ),
        ),
        if (_paypalAutorizado)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.greenAccent, size: 18),
                SizedBox(width: 8),
                Flexible(
                  child: Text(
                    'Orden creada. Completa el pago en PayPal y luego confirma el pedido.',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildApplePayButton() {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(vertical: 15),
              shape: const RoundedRectangleBorder(borderRadius: _kRadius),
              elevation: 0,
            ),
            onPressed: _estaCargando ? null : _autorizarApplePayFrontend,
            icon: const Icon(Icons.apple),
            label: const Text(
              'AUTORIZAR APPLE PAY',
              style: TextStyle(fontWeight: FontWeight.w700, letterSpacing: 1),
            ),
          ),
        ),
        if (_applePayAutorizado)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.greenAccent, size: 18),
                SizedBox(width: 8),
                Text(
                  'Apple Pay autorizado',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
      ],
    );
  }

  // ── Autorizaciones de wallet ────────────────────────────────────────────

  Future<void> _autorizarApplePayFrontend() async {
    if (_estaCargando) return;
    setState(() => _estaCargando = true);
    try {
      // Sin llamadas backend en autorización: la autenticación real ocurre al
      // pulsar CONFIRMAR PEDIDO en _procesarApplePayYCrearPedido.
      if (!mounted) return;
      setState(() {
        _applePayAutorizado = true;
        _googlePayAutorizado = false;
        _paypalAutorizado = false;
        _estaCargando = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _estaCargando = false);
      _showSnack('No se pudo autorizar Apple Pay', error: true);
    }
  }

  Future<void> _procesarApplePayYCrearPedido() async {
    setState(() => _estaCargando = true);
    try {
      final cart = context.read<CartProvider>();
      final total = _calcularTotal(cart);
      final applePayInit = await ApiService.iniciarApplePay(total: total);

      final clientSecret = applePayInit['client_secret']?.toString();
      final paymentIntentId = applePayInit['payment_intent_id']?.toString();
      final applePayStatus = applePayInit['status']?.toString().toLowerCase();

      if (clientSecret != null && clientSecret.isNotEmpty) {
        await ApiService.confirmarApplePay(clientSecret: clientSecret);
      }

      bool pagado = false;
      if (paymentIntentId != null && paymentIntentId.isNotEmpty) {
        pagado = await ApiService.verificarApplePay(
          paymentIntentId: paymentIntentId,
        );
      }

      if (!pagado) {
        pagado = applePayStatus == 'succeeded' ||
            applePayStatus == 'paid' ||
            applePayStatus == 'completed';
      }

      if (!pagado) {
        throw Exception('El pago con Apple Pay no se completó');
      }

      await _crearPedidoFinal(
        referenciaPago: paymentIntentId ??
            applePayInit['id']?.toString() ??
            'applepay_success',
        estadoPago: 'pagado',
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _estaCargando = false);
      _showSnack('Error en Apple Pay: $e', error: true);
    }
  }

  Future<void> _autorizarGooglePayFrontend() async {
    if (_estaCargando || _googlePayProcesando) return;
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      _showSnack('Google Pay solo está disponible en Android.', error: true);
      return;
    }

    setState(() {
      _estaCargando = true;
      _googlePayProcesando = true;
    });

    try {
      final cart = context.read<CartProvider>();
      final total = _calcularTotal(cart);

      final intent = await ApiService.crearIntentoTarjeta(
        amount: total,
        currency: 'eur',
      );

      final clientSecret = intent['client_secret']?.toString();
      final paymentIntentId = intent['payment_intent_id']?.toString();

      if (clientSecret == null || clientSecret.isEmpty) {
        throw Exception('No se pudo iniciar el pago de Google Pay');
      }

      final googlePaySupported = await Stripe.instance.isPlatformPaySupported(
        googlePay: const IsGooglePaySupportedParams(),
      );
      if (!googlePaySupported) {
        throw Exception('Google Pay no está disponible en este dispositivo.');
      }

      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          paymentIntentClientSecret: clientSecret,
          merchantDisplayName: 'Bravo Restaurante',
          googlePay: const PaymentSheetGooglePay(
            merchantCountryCode: 'ES',
            currencyCode: 'EUR',
            testEnv: true,
          ),
        ),
      );

      if (!mounted) return;
      setState(() {
        _googlePayAutorizado = true;
        _googlePayProcesando = false;
        _googlePayClientSecret = clientSecret;
        _googlePayPaymentIntentId = paymentIntentId;
        _paypalAutorizado = false;
        _applePayAutorizado = false;
        _estaCargando = false;
      });
    } on StripeException catch (e) {
      if (!mounted) return;
      setState(() {
        _estaCargando = false;
        _googlePayProcesando = false;
      });
      _showSnack(
        'No se pudo autorizar Google Pay: '
        '${e.error.localizedMessage ?? e.error.message}',
        error: true,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _estaCargando = false;
        _googlePayProcesando = false;
      });
      _showSnack('No se pudo autorizar Google Pay: $e', error: true);
    }
  }

  Future<void> _autorizarPaypalFrontend() async {
    if (_estaCargando) return;
    setState(() => _estaCargando = true);
    try {
      final cart = context.read<CartProvider>();
      final total = _calcularTotal(cart);

      const successUrl = 'https://example.com/paypal-success';
      const cancelUrl = 'https://example.com/paypal-cancel';

      final orden = await ApiService.crearOrdenPaypal(
        total: total,
        currency: 'EUR',
        successUrl: successUrl,
        cancelUrl: cancelUrl,
      );

      final orderId = orden['id']?.toString();
      if (orderId == null || orderId.isEmpty) {
        throw Exception('No se pudo crear la orden de PayPal');
      }

      String? approvalUrl;
      if (orden['approval_url'] != null) {
        approvalUrl = orden['approval_url'].toString();
      } else if (orden['links'] is List) {
        for (final link in orden['links'] as List) {
          if (link is Map<String, dynamic>) {
            final rel = link['rel']?.toString().toLowerCase();
            if (rel == 'approve' || rel == 'approval_url') {
              approvalUrl = link['href']?.toString();
              break;
            }
          }
        }
      }

      if (approvalUrl == null || approvalUrl.isEmpty) {
        throw Exception('No se recibió URL de aprobación de PayPal');
      }

      final approvalUri = Uri.parse(approvalUrl);
      if (!await canLaunchUrl(approvalUri)) {
        throw Exception('No se puede abrir la URL de PayPal');
      }

      final launched = await launchUrl(
        approvalUri,
        mode: kIsWeb
            ? LaunchMode.platformDefault
            : LaunchMode.externalApplication,
      );
      if (!launched) {
        throw Exception('No se pudo abrir el pago de PayPal');
      }

      if (!mounted) return;
      setState(() {
        _paypalAutorizado = true;
        _paypalOrderId = orderId;
        _googlePayAutorizado = false;
        _applePayAutorizado = false;
        _estaCargando = false;
      });
      _showSnack(
        'PayPal abierto. Completa el pago en la ventana que se abrió y luego confirma el pedido.',
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _estaCargando = false);
      _showSnack('Error al iniciar PayPal: $e', error: true);
    }
  }

  // ── Layout helpers ──────────────────────────────────────────────────────

  double _hPad(BoxConstraints c) {
    return (c.maxWidth - c.maxWidth.clamp(0.0, _kMaxContentWidth)) / 2 + 20;
  }

  Widget _subtituloPaso(String texto) {
    return Text(
      texto,
      style: TextStyle(
        color: Colors.white.withValues(alpha: 0.65),
        fontSize: 13,
        letterSpacing: 0.3,
      ),
    );
  }
}

// ── Widgets internos ─────────────────────────────────────────────────────

class _FondoConVelado extends StatelessWidget {
  const _FondoConVelado();

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: RepaintBoundary(
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              'assets/images/Bravo restaurante.jpg',
              fit: BoxFit.cover,
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.72),
                    Colors.black.withValues(alpha: 0.86),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final String titulo;
  final VoidCallback onBack;
  const _Header({required this.titulo, required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 6, 16, 0),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Volver',
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: onBack,
          ),
          Text(
            titulo,
            style: GoogleFonts.playfairDisplay(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _OverlayCargando extends StatelessWidget {
  const _OverlayCargando();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: Color(0x8C000000),
      child: SizedBox.expand(
        child: Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      ),
    );
  }
}

class _StepIndicator extends StatelessWidget {
  final _Paso paso;
  const _StepIndicator({required this.paso});

  @override
  Widget build(BuildContext context) {
    final pasoIdx = _Paso.values.indexOf(paso);
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.35),
        border: Border(
          bottom: BorderSide(color: Colors.white.withValues(alpha: 0.10)),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
      child: Row(
        children: [
          _StepDot(label: 'Confirmar', activo: pasoIdx == 0, hecho: pasoIdx > 0),
          _Linea(activa: pasoIdx > 0),
          _StepDot(label: 'Entrega', activo: pasoIdx == 1, hecho: pasoIdx > 1),
          _Linea(activa: pasoIdx > 1),
          _StepDot(label: 'Pago', activo: pasoIdx == 2, hecho: false),
        ],
      ),
    );
  }
}

class _Linea extends StatelessWidget {
  final bool activa;
  const _Linea({required this.activa});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 350),
        height: 1,
        margin: const EdgeInsets.symmetric(horizontal: 10),
        color: activa
            ? AppColors.button
            : Colors.white.withValues(alpha: 0.20),
      ),
    );
  }
}

class _StepDot extends StatelessWidget {
  final String label;
  final bool activo;
  final bool hecho;

  const _StepDot({
    required this.label,
    required this.activo,
    required this.hecho,
  });

  @override
  Widget build(BuildContext context) {
    final filled = activo || hecho;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedContainer(
          duration: _kAnimMed,
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: filled ? AppColors.button : Colors.transparent,
            border: Border.all(
              color: filled
                  ? AppColors.button
                  : Colors.white.withValues(alpha: 0.30),
              width: 1.5,
            ),
          ),
          child: Center(
            child: hecho
                ? const Icon(Icons.check, size: 14, color: Colors.white)
                : Icon(
                    activo ? Icons.circle : Icons.circle_outlined,
                    size: 7,
                    color: filled
                        ? Colors.white
                        : Colors.white.withValues(alpha: 0.35),
                  ),
          ),
        ),
        const SizedBox(height: 5),
        Text(
          label.toUpperCase(),
          style: TextStyle(
            color:
                filled ? Colors.white : Colors.white.withValues(alpha: 0.35),
            fontSize: 8,
            letterSpacing: 1.2,
            fontWeight: filled ? FontWeight.w700 : FontWeight.w400,
          ),
        ),
      ],
    );
  }
}

class _BottomBar extends StatelessWidget {
  final _Paso paso;
  final bool cargando;
  final double costeEnvio;
  final VoidCallback onSiguiente;
  final VoidCallback? onAtras;

  const _BottomBar({
    required this.paso,
    required this.cargando,
    required this.costeEnvio,
    required this.onSiguiente,
    this.onAtras,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<CartProvider>(
      builder: (context, cart, _) {
        final envio = paso == _Paso.confirmar ? 0.0 : costeEnvio;
        final total = cart.totalPrice + envio;
        final bottom = MediaQuery.of(context).padding.bottom;

        return Container(
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.80),
            border: Border(
              top: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
            ),
          ),
          padding: EdgeInsets.fromLTRB(20, 16, 20, bottom + 16),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'TOTAL',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.50),
                        fontSize: 9,
                        letterSpacing: 2.0,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${total.toStringAsFixed(2).replaceAll('.', ',')} €',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                    ),
                    if (envio > 0)
                      Text(
                        'incl. ${envio.toStringAsFixed(2).replaceAll('.', ',')} € envío',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.40),
                          fontSize: 10,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              if (onAtras != null) ...[
                Tooltip(
                  message: 'Volver',
                  child: InkWell(
                    onTap: onAtras,
                    borderRadius: _kRadius,
                    child: Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        borderRadius: _kRadius,
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.20),
                        ),
                      ),
                      child: Icon(
                        Icons.arrow_back,
                        color: Colors.white.withValues(alpha: 0.70),
                        size: 20,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: ElevatedButton(
                  onPressed: cargando ? null : onSiguiente,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.button,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor:
                        AppColors.button.withValues(alpha: 0.5),
                    minimumSize: const Size.fromHeight(50),
                    shape: const RoundedRectangleBorder(borderRadius: _kRadius),
                    elevation: 0,
                  ),
                  child: cargando
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : Text(
                          paso != _Paso.pago
                              ? 'CONTINUAR'
                              : 'CONFIRMAR PEDIDO',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.8,
                          ),
                        ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _EntregaCard extends StatelessWidget {
  final IconData icono;
  final String titulo;
  final String subtitulo;
  final String coste;
  final bool seleccionada;
  final VoidCallback onTap;

  const _EntregaCard({
    required this.icono,
    required this.titulo,
    required this.subtitulo,
    required this.coste,
    required this.seleccionada,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: _kRadius,
        child: AnimatedContainer(
          duration: _kAnimFast,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            borderRadius: _kRadius,
            color: seleccionada
                ? AppColors.button.withValues(alpha: 0.18)
                : Colors.white.withValues(alpha: 0.07),
            border: Border.all(
              color: seleccionada
                  ? AppColors.button
                  : Colors.white.withValues(alpha: 0.18),
              width: seleccionada ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              AnimatedContainer(
                duration: _kAnimFast,
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: seleccionada
                      ? AppColors.button
                      : Colors.white.withValues(alpha: 0.10),
                ),
                child: Icon(
                  icono,
                  size: 22,
                  color: seleccionada
                      ? Colors.white
                      : Colors.white.withValues(alpha: 0.60),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      titulo,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: seleccionada
                            ? FontWeight.w700
                            : FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitulo,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.55),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              AnimatedContainer(
                duration: _kAnimFast,
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(6),
                  color: seleccionada
                      ? AppColors.button
                      : Colors.white.withValues(alpha: 0.10),
                ),
                child: Text(
                  coste,
                  style: TextStyle(
                    color: seleccionada
                        ? Colors.white
                        : Colors.white.withValues(alpha: 0.60),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PagoCard extends StatelessWidget {
  final IconData icono;
  final String titulo;
  final String subtitulo;
  final bool seleccionada;
  final VoidCallback onTap;

  const _PagoCard({
    required this.icono,
    required this.titulo,
    required this.subtitulo,
    required this.seleccionada,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: _kRadius,
        child: AnimatedContainer(
          duration: _kAnimFast,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: _kRadius,
            color: seleccionada
                ? AppColors.button.withValues(alpha: 0.18)
                : Colors.white.withValues(alpha: 0.07),
            border: Border.all(
              color: seleccionada
                  ? AppColors.button
                  : Colors.white.withValues(alpha: 0.18),
              width: seleccionada ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                icono,
                size: 24,
                color: seleccionada
                    ? AppColors.button
                    : Colors.white.withValues(alpha: 0.55),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      titulo,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: seleccionada
                            ? FontWeight.w700
                            : FontWeight.w500,
                      ),
                    ),
                    Text(
                      subtitulo,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.50),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              AnimatedContainer(
                duration: _kAnimFast,
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: seleccionada ? AppColors.button : Colors.transparent,
                  border: Border.all(
                    color: seleccionada
                        ? AppColors.button
                        : Colors.white.withValues(alpha: 0.25),
                    width: 1.5,
                  ),
                ),
                child: seleccionada
                    ? const Icon(Icons.check, size: 13, color: Colors.white)
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DireccionOption extends StatelessWidget {
  final IconData icono;
  final String titulo;
  final String subtitulo;
  final bool seleccionada;
  final VoidCallback onTap;

  const _DireccionOption({
    required this.icono,
    required this.titulo,
    required this.subtitulo,
    required this.seleccionada,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: _kRadius,
        child: AnimatedContainer(
          duration: _kAnimFast,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          decoration: BoxDecoration(
            borderRadius: _kRadius,
            color: seleccionada
                ? AppColors.button.withValues(alpha: 0.15)
                : Colors.white.withValues(alpha: 0.06),
            border: Border.all(
              color: seleccionada
                  ? AppColors.button
                  : Colors.white.withValues(alpha: 0.15),
              width: seleccionada ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                icono,
                size: 18,
                color: seleccionada
                    ? AppColors.button
                    : Colors.white.withValues(alpha: 0.50),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      titulo,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: seleccionada
                            ? FontWeight.w700
                            : FontWeight.w500,
                      ),
                    ),
                    Text(
                      subtitulo,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.50),
                        fontSize: 11,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (seleccionada)
                const Icon(Icons.check_circle,
                    size: 16, color: AppColors.button),
            ],
          ),
        ),
      ),
    );
  }
}

class _StripeCheckoutDialog extends StatefulWidget {
  final String sessionId;
  const _StripeCheckoutDialog({required this.sessionId});

  @override
  State<_StripeCheckoutDialog> createState() => _StripeCheckoutDialogState();
}

class _StripeCheckoutDialogState extends State<_StripeCheckoutDialog> {
  bool _verificando = false;
  String? _error;

  Future<void> _verificar() async {
    setState(() {
      _verificando = true;
      _error = null;
    });
    try {
      final pagado = await ApiService.verificarCheckoutSession(
        sessionId: widget.sessionId,
      );
      if (!mounted) return;
      if (pagado) {
        Navigator.of(context).pop(true);
      } else {
        setState(() {
          _verificando = false;
          _error =
              'El pago aún no se ha completado. Termínalo en la pestaña de Stripe y vuelve a intentarlo.';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _verificando = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.panel,
      shape: const RoundedRectangleBorder(borderRadius: _kRadius),
      title: const Row(
        children: [
          Icon(Icons.open_in_new, color: AppColors.button, size: 20),
          SizedBox(width: 10),
          Text(
            'Completa el pago',
            style: TextStyle(color: AppColors.textPrimary, fontSize: 16),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Se ha abierto la página de pago de Stripe en una nueva pestaña. Completa el pago y pulsa el botón de abajo.',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(
              _error!,
              style: const TextStyle(color: AppColors.error, fontSize: 12),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed:
              _verificando ? null : () => Navigator.of(context).pop(false),
          child: const Text(
            'Cancelar',
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.button,
            foregroundColor: Colors.white,
            shape: const RoundedRectangleBorder(borderRadius: _kRadius),
          ),
          onPressed: _verificando ? null : _verificar,
          child: _verificando
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
              : const Text('Ya he pagado'),
        ),
      ],
    );
  }
}

class _ArticuloCard extends StatelessWidget {
  final CartItem item;
  final CartProvider cart;

  const _ArticuloCard({required this.item, required this.cart});

  @override
  Widget build(BuildContext context) {
    final imageUrl = item.producto.imagenUrl;
    return ClipRRect(
      borderRadius: _kRadius,
      child: SizedBox(
        height: 130,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (imageUrl != null && imageUrl.isNotEmpty)
              Image.network(
                imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => _imgFallback(),
              )
            else
              _imgFallback(),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: const [0.0, 0.35, 0.65, 1.0],
                  colors: [
                    Colors.black.withValues(alpha: 0.45),
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.55),
                    Colors.black.withValues(alpha: 0.88),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 12, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Align(
                    alignment: Alignment.topRight,
                    child: Tooltip(
                      message: 'Eliminar',
                      child: InkWell(
                        onTap: () => cart.removeProduct(item.key),
                        borderRadius: BorderRadius.circular(6),
                        child: Container(
                          width: 26,
                          height: 26,
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.40),
                            border: Border.all(color: Colors.white24),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Icon(
                            Icons.close,
                            size: 13,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    item.producto.nombre,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.playfairDisplay(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      height: 1.2,
                      shadows: const [
                        Shadow(color: Colors.black54, blurRadius: 6),
                      ],
                    ),
                  ),
                  if (item.ingredientesExcluidos.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      'Sin: ${item.ingredientesExcluidos.join(', ')}',
                      style: const TextStyle(
                        color: AppColors.excludedIngredient,
                        fontSize: 10,
                        fontStyle: FontStyle.italic,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Text(
                        '${item.producto.precio.toStringAsFixed(2).replaceAll('.', ',')} € / ud',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.60),
                          fontSize: 11,
                        ),
                      ),
                      const Spacer(),
                      _StepperCard(item: item, cart: cart),
                      const SizedBox(width: 14),
                      Text(
                        '${item.subtotal.toStringAsFixed(2).replaceAll('.', ',')} €',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _imgFallback() => Container(
        color: Colors.white.withValues(alpha: 0.10),
        child: Icon(
          Icons.restaurant,
          color: Colors.white.withValues(alpha: 0.20),
          size: 28,
        ),
      );
}

class _StepperCard extends StatelessWidget {
  final CartItem item;
  final CartProvider cart;

  const _StepperCard({required this.item, required this.cart});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _StepperButton(
          icon: Icons.remove,
          onTap: () => cart.removeItem(item.key),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Text(
            '${item.cantidad}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
            ),
          ),
        ),
        _StepperButton(
          icon: Icons.add,
          filled: true,
          onTap: () => cart.addItem(
            item.producto,
            ingredientesExcluidos: item.ingredientesExcluidos,
          ),
        ),
      ],
    );
  }
}

class _StepperButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool filled;
  const _StepperButton({
    required this.icon,
    required this.onTap,
    this.filled = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: filled
                ? AppColors.button
                : Colors.black.withValues(alpha: 0.30),
            borderRadius: BorderRadius.circular(6),
            border: filled ? null : Border.all(color: Colors.white38),
          ),
          child: Icon(icon, size: filled ? 15 : 13, color: Colors.white),
        ),
      ),
    );
  }
}

class _FormPanel extends StatelessWidget {
  final Widget child;
  const _FormPanel({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.45),
        borderRadius: _kRadius,
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      padding: const EdgeInsets.all(16),
      child: child,
    );
  }
}

class _LogoGooglePayButton extends StatelessWidget {
  const _LogoGooglePayButton();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'Buy with',
          style: TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(width: 8),
        RichText(
          text: const TextSpan(
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
            children: [
              TextSpan(text: 'G', style: TextStyle(color: Color(0xFF4285F4))),
              TextSpan(text: 'o', style: TextStyle(color: Color(0xFFEA4335))),
              TextSpan(text: 'o', style: TextStyle(color: Color(0xFFFBBC05))),
              TextSpan(text: 'g', style: TextStyle(color: Color(0xFF4285F4))),
              TextSpan(text: 'l', style: TextStyle(color: Color(0xFF34A853))),
              TextSpan(text: 'e', style: TextStyle(color: Color(0xFFEA4335))),
              TextSpan(text: ' Pay', style: TextStyle(color: Colors.white)),
            ],
          ),
        ),
      ],
    );
  }
}

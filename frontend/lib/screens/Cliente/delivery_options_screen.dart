import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/colors_style.dart';
import '../../models/opciones_pedido.dart';
import '../../providers/cart_provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../components/Cliente/campos_tarjeta.dart';
import 'pedido_confirmado_screen.dart';
import 'direccion_screen.dart';

export '../../models/opciones_pedido.dart';

class PantallaOpcionesEntrega extends StatefulWidget {
  const PantallaOpcionesEntrega({super.key});

  @override
  State<PantallaOpcionesEntrega> createState() =>
      _PantallaOpcionesEntregaState();
}

class _PantallaOpcionesEntregaState extends State<PantallaOpcionesEntrega> {
  int _paso = 0; // 0=confirmar  1=entrega  2=pago
  late OpcionEntrega _entregaSeleccionada;
  MetodoPago _pagoSeleccionado = MetodoPago.efectivo;
  OpcionDireccion _direccionSeleccionada = OpcionDireccion.registrada;
  bool _estaCargando = false;

  bool _googlePayAutorizado = false;
  bool _paypalAutorizado = false;
  bool _applePayAutorizado = false;
  String? _paypalOrderId;
  String? _googlePayClientSecret;
  String? _googlePayPaymentIntentId;
  CardFieldInputDetails? _cardDetails;

  final _controladorDireccion = TextEditingController();
  final _controladorNotas = TextEditingController();

  static const _titulos = ['CONFIRMAR', 'ENTREGA', 'PAGO'];

  @override
  void initState() {
    super.initState();
    final cart = Provider.of<CartProvider>(context, listen: false);
    _entregaSeleccionada = cart.tienemesa
        ? OpcionEntrega.enMesa
        : OpcionEntrega.domicilio;
  }

  @override
  void dispose() {
    _controladorDireccion.dispose();
    _controladorNotas.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/images/Bravo restaurante.jpg',
              fit: BoxFit.cover,
            ),
          ),
          Positioned.fill(
            child: DecoratedBox(
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
          ),
          SafeArea(
            child: Column(
              children: [
                _buildHeader(context),
                _StepIndicator(paso: _paso),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    transitionBuilder: (child, animation) => SlideTransition(
                      position:
                          Tween<Offset>(
                            begin: const Offset(0.06, 0),
                            end: Offset.zero,
                          ).animate(
                            CurvedAnimation(
                              parent: animation,
                              curve: Curves.easeOut,
                            ),
                          ),
                      child: FadeTransition(opacity: animation, child: child),
                    ),
                    child: _buildPasoActual(),
                  ),
                ),
                _BottomBar(
                  paso: _paso,
                  cargando: _estaCargando,
                  entrega: _entregaSeleccionada,
                  onSiguiente: switch (_paso) {
                    0 => () => setState(() => _paso = 1),
                    1 => _irAPago,
                    _ => _confirmarPedido,
                  },
                  onAtras: _paso > 0 ? () => setState(() => _paso -= 1) : null,
                ),
              ],
            ),
          ),
          if (_estaCargando)
            Container(
              color: Colors.black.withValues(alpha: 0.55),
              child: const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 6, 16, 0),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          Text(
            _titulos[_paso],
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

  Widget _buildPasoActual() {
    return switch (_paso) {
      0 => _buildPasoConfirmar(),
      1 => _buildPasoEntrega(),
      _ => _buildPasoPago(),
    };
  }

  Widget _buildPasoConfirmar() {
    return LayoutBuilder(
      key: const ValueKey('confirmar'),
      builder: (context, constraints) {
        final hPad = _hPad(constraints);
        return Consumer<CartProvider>(
          builder: (context, cart, _) {
            if (cart.itemCount == 0) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.white24),
                      ),
                      child: const Icon(
                        Icons.shopping_bag_outlined,
                        size: 32,
                        color: Colors.white38,
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'SIN PRODUCTOS',
                      style: TextStyle(
                        color: Colors.white60,
                        fontSize: 14,
                        letterSpacing: 2.0,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              );
            }

            return SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: EdgeInsets.fromLTRB(hPad, 16, hPad, 120),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _subtituloPaso('Revisa tu pedido'),
                  const SizedBox(height: 12),
                  ...cart.items.values.map(
                    (item) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _ArticuloCard(item: item, cart: cart),
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

  Widget _buildPasoEntrega() {
    return LayoutBuilder(
      key: const ValueKey('entrega'),
      builder: (context, constraints) {
        final hPad = _hPad(constraints);
        return SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.symmetric(horizontal: hPad, vertical: 28),
          child: Consumer<CartProvider>(
            builder: (context, cart, _) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _subtituloPaso('¿Cómo quieres recibir tu pedido?'),
                  const SizedBox(height: 20),
                  if (cart.tienemesa) ...[
                    _EntregaCard(
                      icono: Icons.restaurant,
                      titulo: 'Mesa ${cart.numeroMesa}',
                      subtitulo: 'Te lo servimos directamente',
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
                    subtitulo: 'En la puerta de tu casa',
                    coste: '+3,99 €',
                    seleccionada:
                        _entregaSeleccionada == OpcionEntrega.domicilio,
                    onTap: () => setState(
                      () => _entregaSeleccionada = OpcionEntrega.domicilio,
                    ),
                  ),
                  if (_entregaSeleccionada == OpcionEntrega.domicilio) ...[
                    const SizedBox(height: 16),
                    _seccionDireccion(),
                  ],
                  const SizedBox(height: 12),
                  _EntregaCard(
                    icono: Icons.store_outlined,
                    titulo: 'Recoger en local',
                    subtitulo: 'Listo cuando llegues',
                    coste: 'Gratis',
                    seleccionada: _entregaSeleccionada == OpcionEntrega.recoger,
                    onTap: () => setState(
                      () => _entregaSeleccionada = OpcionEntrega.recoger,
                    ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildPasoPago() {
    return LayoutBuilder(
      key: const ValueKey('pago'),
      builder: (context, constraints) {
        final hPad = _hPad(constraints);
        return SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.symmetric(horizontal: hPad, vertical: 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _subtituloPaso('Elige cómo quieres pagar'),
              const SizedBox(height: 20),
              _PagoCard(
                icono: Icons.payments_outlined,
                titulo: 'Efectivo',
                subtitulo: 'Pagas al recibir el pedido',
                seleccionada: _pagoSeleccionado == MetodoPago.efectivo,
                onTap: () {
                  setState(() {
                    _pagoSeleccionado = MetodoPago.efectivo;
                    _googlePayAutorizado = false;
                    _paypalAutorizado = false;
                    _paypalOrderId = null;
                  });
                },
              ),
              const SizedBox(height: 10),
              _PagoCard(
                icono: Icons.credit_card,
                titulo: 'Tarjeta',
                subtitulo: 'Crédito o débito',
                seleccionada: _pagoSeleccionado == MetodoPago.tarjeta,
                onTap: () {
                  setState(() {
                    _pagoSeleccionado = MetodoPago.tarjeta;
                    _googlePayAutorizado = false;
                    _paypalAutorizado = false;
                    _paypalOrderId = null;
                  });
                },
              ),
              if (_pagoSeleccionado == MetodoPago.tarjeta) ...[
                const SizedBox(height: 2),
                _FormPanel(
                  child: CamposTarjeta(
                    onCardChanged: (details) =>
                        setState(() => _cardDetails = details),
                  ),
                ),
              ],
              const SizedBox(height: 10),
              _PagoCard(
                icono: Icons.android,
                titulo: 'Google Pay',
                subtitulo: 'Pago rápido con Google',
                seleccionada: _pagoSeleccionado == MetodoPago.googlePay,
                onTap: () {
                  setState(() {
                    _pagoSeleccionado = MetodoPago.googlePay;
                    _googlePayAutorizado = false;
                    _paypalAutorizado = false;
                    _paypalOrderId = null;
                  });
                },
              ),
              if (_pagoSeleccionado == MetodoPago.googlePay) ...[
                const SizedBox(height: 8),
                _buildGooglePayButton(),
              ],
              const SizedBox(height: 10),
              _PagoCard(
                icono: Icons.account_balance_wallet_outlined,
                titulo: 'PayPal',
                subtitulo: 'Paga con tu cuenta de PayPal',
                seleccionada: _pagoSeleccionado == MetodoPago.paypal,
                onTap: () {
                  setState(() {
                    _pagoSeleccionado = MetodoPago.paypal;
                    _googlePayAutorizado = false;
                    _paypalAutorizado = false;
                    _applePayAutorizado = false;
                    _paypalOrderId = null;
                  });
                },
              ),
              if (_pagoSeleccionado == MetodoPago.paypal) ...[
                const SizedBox(height: 8),
                _buildPaypalButton(),
              ],
              const SizedBox(height: 10),
              _PagoCard(
                icono: Icons.apple,
                titulo: 'Apple Pay',
                subtitulo: 'Paga con Apple Pay',
                seleccionada: _pagoSeleccionado == MetodoPago.applePay,
                onTap: () {
                  setState(() {
                    _pagoSeleccionado = MetodoPago.applePay;
                    _googlePayAutorizado = false;
                    _paypalAutorizado = false;
                    _paypalOrderId = null;
                    _applePayAutorizado = false;
                  });
                },
              ),
              if (_pagoSeleccionado == MetodoPago.applePay) ...[
                const SizedBox(height: 8),
                _buildApplePayButton(),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _seccionDireccion() {
    return Consumer<AuthProvider>(
      builder: (context, auth, _) {
        // Obtenemos la dirección directamente del perfil del usuario (MongoDB)
        final dir = auth.usuarioActual?.direccion ?? '';

        return Column(
          children: [
            // Opción 1: La dirección que ya está en la Base de Datos
            _DireccionOption(
              icono: Icons.home_outlined,
              titulo: 'Dirección registrada',
              subtitulo: dir.isNotEmpty ? dir : 'No tienes dirección guardada',
              seleccionada:
                  _direccionSeleccionada == OpcionDireccion.registrada,
              onTap: () => setState(
                () => _direccionSeleccionada = OpcionDireccion.registrada,
              ),
            ),
            const SizedBox(height: 8),

            // Opción 2: El botón que activa nuestra nueva pantalla de GPS/Mapa
            _DireccionOption(
              icono: Icons.map_outlined,
              titulo: 'Cambiar o usar mapa / GPS',
              subtitulo: 'Selecciona tu ubicación exacta en el mapa',
              seleccionada:
                  _direccionSeleccionada == OpcionDireccion.alternativa,
              onTap: () async {
                // Navegamos al mapa y esperamos a que el usuario guarde
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const DireccionScreen(),
                  ),
                );

                // Al volver, forzamos la selección a "registrada" porque
                // la pantalla de mapa ya actualiza la dirección en el perfil del usuario
                setState(() {
                  _direccionSeleccionada = OpcionDireccion.registrada;
                });
              },
            ),

            // He quitado el panel de formulario antiguo (_FormPanel)
            // para que la interfaz quede limpia y obligue a usar el mapa.
          ],
        );
      },
    );
  }

  void _irAPago() {
    final auth = Provider.of<AuthProvider>(context, listen: false);

    if (_entregaSeleccionada == OpcionEntrega.domicilio) {
      final usuario = auth.usuarioActual;

      // Validación de dirección: Si no hay dirección en el perfil, no pasa al pago
      if (usuario == null || usuario.direccion.isEmpty) {
        _mostrarError('Por favor, selecciona una ubicación en el mapa.');
        return;
      }
    }

    setState(() => _paso = 2);
  }

  Future<void> _confirmarPedido() async {
    if (_estaCargando) return;

    switch (_pagoSeleccionado) {
      case MetodoPago.efectivo:
        await _procesarEfectivoYCrearPedido();
        break;
      case MetodoPago.tarjeta:
        await _procesarTarjetaYCrearPedido();
        break;
      case MetodoPago.googlePay:
        await _procesarGooglePayYCrearPedido();
        break;
      case MetodoPago.paypal:
        await _procesarPaypalYCrearPedido();
        break;
      case MetodoPago.applePay:
        if (_applePayAutorizado) {
          await _procesarApplePayYCrearPedido();
        } else {
          _mostrarError('Primero autoriza Apple Pay');
        }
        break;
    }
  }

  Future<void> _procesarEfectivoYCrearPedido() async {
    setState(() => _estaCargando = true);
    await _crearPedidoFinal(referenciaPago: null, estadoPago: 'pendiente');
  }

  Future<void> _procesarTarjetaYCrearPedido() async {
    if (kIsWeb) {
      await _procesarStripeCheckoutWeb();
      return;
    }

    if (_cardDetails == null || !(_cardDetails!.complete)) {
      _mostrarError('Completa los datos de la tarjeta');
      return;
    }

    setState(() => _estaCargando = true);

    try {
      final cart = Provider.of<CartProvider>(context, listen: false);
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
      if (mounted) {
        setState(() => _estaCargando = false);
        _mostrarError('Error en el pago con tarjeta: $e');
      }
    }
  }

  Future<void> _procesarStripeCheckoutWeb() async {
    setState(() => _estaCargando = true);

    try {
      final cart = Provider.of<CartProvider>(context, listen: false);
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final total = _calcularTotal(cart);
      final origin = Uri.base.origin;

      final tipoEntregaStr = switch (_entregaSeleccionada) {
        OpcionEntrega.domicilio => 'Entrega a domicilio',
        OpcionEntrega.recoger => 'Recoger en restaurante',
        OpcionEntrega.enMesa => 'Comer en el local',
      };

      // Capturar datos del carrito ANTES de limpiarlo
      final items = cart.items.values
          .map(
            (item) => {
              'producto_id': item.producto.id,
              'nombre': item.producto.nombre,
              'cantidad': item.cantidad,
              'precio': item.producto.precio,
              if (item.ingredientesExcluidos.isNotEmpty)
                'sin': item.ingredientesExcluidos,
            },
          )
          .toList();

      final itemsResumen = cart.items.values
          .map(
            (item) => {
              'nombre': item.producto.nombre,
              'cantidad': item.cantidad,
              'precio': item.producto.precio,
              if (item.ingredientesExcluidos.isNotEmpty)
                'sin': item.ingredientesExcluidos,
            },
          )
          .toList();

      final direccionEntrega = _entregaSeleccionada == OpcionEntrega.domicilio
          ? (_direccionSeleccionada == OpcionDireccion.registrada
                ? (auth.usuarioActual?.direccion ?? '')
                : _controladorDireccion.text.trim())
          : null;

      // 1. Crear sesión Stripe — la URL de éxito lleva entrega y total
      final totalStr = total.toStringAsFixed(2);
      final session = await ApiService.crearCheckoutSession(
        total: total,
        currency: 'eur',
        successUrl:
            '$origin/?stripe_session={CHECKOUT_SESSION_ID}'
            '&entrega=${Uri.encodeComponent(tipoEntregaStr)}'
            '&total=$totalStr',
        cancelUrl: '$origin/?stripe_cancel=1',
      );

      final checkoutUrl = session['checkout_url']?.toString();
      final sessionId = session['session_id']?.toString();

      if (checkoutUrl == null || sessionId == null) {
        throw Exception('No se pudo iniciar la sesión de pago');
      }

      // 2. Crear el pedido ANTES de abrir Stripe para que quede en BD
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
      );

      final pedidoId =
          resultado['id']?.toString() ?? resultado['pedido_id']?.toString();

      cart.clearCart();
      setState(() => _estaCargando = false);

      // 3. Abrir Stripe (nueva pestaña si el navegador lo permite)
      await launchUrl(Uri.parse(checkoutUrl), webOnlyWindowName: '_blank');

      if (!mounted) return;

      // 4. Diálogo para quien vuelve a esta misma pestaña
      final confirmado = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => _StripeCheckoutDialog(sessionId: sessionId),
      );

      if (confirmado != true || !mounted) return;

      // Marcar el pedido como pagado en la BD
      try {
        await ApiService.actualizarEstadoPago(referenciaPago: sessionId);
      } catch (_) {}
      if (!mounted) return;

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
      if (mounted) {
        setState(() => _estaCargando = false);
        _mostrarError('Error en el pago con Stripe: $e');
      }
    }
  }

  Future<void> _procesarGooglePayYCrearPedido() async {
    if (!_googlePayAutorizado || _googlePayClientSecret == null) {
      _mostrarError('Primero autoriza Google Pay');
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
      if (mounted) {
        setState(() => _estaCargando = false);
        _mostrarError(
          'Pago de Google Pay cancelado o fallido: ${e.error.localizedMessage ?? e.error.message}',
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _estaCargando = false);
        _mostrarError('Error en Google Pay: $e');
      }
    }
  }

  Future<void> _procesarPaypalYCrearPedido() async {
    if (!_paypalAutorizado || _paypalOrderId == null) {
      _mostrarError('Primero completa el pago en PayPal');
      return;
    }

    setState(() => _estaCargando = true);

    try {
      final orderId = _paypalOrderId!;
      final captura = await ApiService.capturarOrdenPaypal(orderId: orderId);
      final status = (captura['status'] ?? '').toString().toUpperCase();

      final completado =
          status == 'COMPLETED' ||
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
      if (mounted) {
        setState(() => _estaCargando = false);
        _mostrarError('Error en PayPal: $e');
      }
    }
  }

  Future<void> _crearPedidoFinal({
    String? referenciaPago,
    String? estadoPago,
  }) async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final cart = Provider.of<CartProvider>(context, listen: false);

    final tipoPagoStr = switch (_pagoSeleccionado) {
      MetodoPago.efectivo => 'Efectivo',
      MetodoPago.tarjeta => 'Tarjeta',
      MetodoPago.googlePay => 'Google Pay',
      MetodoPago.paypal => 'PayPal',
      MetodoPago.applePay => 'Apple Pay',
    };

    final tipoEntrega = switch (_entregaSeleccionada) {
      OpcionEntrega.domicilio => 'Entrega a domicilio',
      OpcionEntrega.recoger => 'Recoger en restaurante',
      OpcionEntrega.enMesa => 'Comer en el local',
    };

    final total = _calcularTotal(cart);

    final direccionEntrega = _entregaSeleccionada == OpcionEntrega.domicilio
        ? (_direccionSeleccionada == OpcionDireccion.registrada
              ? (auth.usuarioActual?.direccion ?? '')
              : _controladorDireccion.text.trim())
        : null;

    try {
      final items = cart.items.values
          .map(
            (item) => {
              'producto_id': item.producto.id,
              'nombre': item.producto.nombre,
              'cantidad': item.cantidad,
              'precio': item.producto.precio,
              if (item.ingredientesExcluidos.isNotEmpty)
                'sin': item.ingredientesExcluidos,
            },
          )
          .toList();

      if (_entregaSeleccionada != OpcionEntrega.enMesa) {
        cart.desasignarMesa();
      }

      final itemsResumen = cart.items.values
          .map(
            (item) => {
              'nombre': item.producto.nombre,
              'cantidad': item.cantidad,
              'precio': item.producto.precio,
              if (item.ingredientesExcluidos.isNotEmpty)
                'sin': item.ingredientesExcluidos,
            },
          )
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
        estadoPago:
            estadoPago ??
            (_pagoSeleccionado == MetodoPago.efectivo ? 'pendiente' : 'pagado'),
      );

      final pedidoId =
          resultado['id']?.toString() ?? resultado['pedido_id']?.toString();

      cart.clearCart();

      if (mounted) {
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
      }
    } catch (e) {
      if (mounted) {
        setState(() => _estaCargando = false);
        _mostrarError('Error al crear pedido: ${e.toString()}');
      }
    }
  }

  double _calcularTotal(CartProvider cart) {
    final costeEnvio = _entregaSeleccionada == OpcionEntrega.domicilio
        ? 3.99
        : 0.0;
    return cart.totalPrice + costeEnvio;
  }

  Widget _buildGooglePayButton() {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            style: OutlinedButton.styleFrom(
              backgroundColor: Colors.white,
              side: BorderSide.none,
              padding: const EdgeInsets.symmetric(vertical: 15),
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.zero,
              ),
            ),
            onPressed: _autorizarGooglePayFrontend,
            child: const Text(
              'AUTORIZAR GOOGLE PAY',
              style: TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.w700,
                letterSpacing: 1,
              ),
            ),
          ),
        ),
        if (_googlePayAutorizado)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(
              children: const [
                Icon(Icons.check_circle, color: Colors.greenAccent, size: 18),
                SizedBox(width: 8),
                Text(
                  'Google Pay autorizado',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
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
          child: OutlinedButton(
            style: OutlinedButton.styleFrom(
              backgroundColor: AppColors.paypal,
              side: BorderSide.none,
              padding: const EdgeInsets.symmetric(vertical: 15),
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.zero,
              ),
            ),
            onPressed: _autorizarPaypalFrontend,
            child: const Text(
              'AUTORIZAR PAYPAL',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                letterSpacing: 1,
              ),
            ),
          ),
        ),
        if (_paypalAutorizado)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(
              children: const [
                Icon(Icons.check_circle, color: Colors.greenAccent, size: 18),
                SizedBox(width: 8),
                Text(
                  'PayPal autorizado',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
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
          child: OutlinedButton(
            style: OutlinedButton.styleFrom(
              backgroundColor: Colors.white,
              side: BorderSide.none,
              padding: const EdgeInsets.symmetric(vertical: 15),
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.zero,
              ),
            ),
            onPressed: _autorizarApplePayFrontend,
            child: const Text(
              'AUTORIZAR APPLE PAY',
              style: TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.w700,
                letterSpacing: 1,
              ),
            ),
          ),
        ),
        if (_applePayAutorizado)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(
              children: const [
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

  Future<void> _autorizarApplePayFrontend() async {
    if (_estaCargando) return;

    setState(() => _estaCargando = true);
    try {
      await Future.delayed(const Duration(seconds: 1));
      if (mounted) {
        setState(() {
          _applePayAutorizado = true;
          _googlePayAutorizado = false;
          _paypalAutorizado = false;
          _estaCargando = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _estaCargando = false);
        _mostrarError('No se pudo autorizar Apple Pay');
      }
    }
  }

  Future<void> _procesarApplePayYCrearPedido() async {
    setState(() => _estaCargando = true);
    try {
      final cart = Provider.of<CartProvider>(context, listen: false);
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
        pagado =
            applePayStatus == 'succeeded' ||
            applePayStatus == 'paid' ||
            applePayStatus == 'completed';
      }

      if (!pagado) {
        throw Exception('El pago con Apple Pay no se completó');
      }

      await _crearPedidoFinal(
        referenciaPago:
            paymentIntentId ??
            applePayInit['id']?.toString() ??
            'applepay_success',
        estadoPago: 'pagado',
      );
    } catch (e) {
      if (mounted) {
        setState(() => _estaCargando = false);
        _mostrarError('Error en Apple Pay: $e');
      }
    }
  }

  Future<void> _autorizarGooglePayFrontend() async {
    if (_estaCargando) return;
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      _mostrarError('Google Pay solo está disponible en Android.');
      return;
    }

    setState(() => _estaCargando = true);

    try {
      final cart = Provider.of<CartProvider>(context, listen: false);
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

      final googlePaySupported = await Stripe.instance.isGooglePaySupported();
      if (!googlePaySupported) {
        throw Exception('Google Pay no está disponible en este dispositivo.');
      }

      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          paymentIntentClientSecret: clientSecret,
          merchantDisplayName: 'Bravo',
          googlePay: const PaymentSheetGooglePay(
            merchantCountryCode: 'ES',
            currencyCode: 'EUR',
            testEnv: true,
          ),
        ),
      );

      if (mounted) {
        setState(() {
          _googlePayAutorizado = true;
          _googlePayClientSecret = clientSecret;
          _googlePayPaymentIntentId = paymentIntentId;
          _paypalAutorizado = false;
          _applePayAutorizado = false;
          _estaCargando = false;
        });
      }
    } on StripeException catch (e) {
      if (mounted) {
        setState(() => _estaCargando = false);
        _mostrarError(
          'No se pudo autorizar Google Pay: ${e.error.localizedMessage ?? e.error.message}',
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _estaCargando = false);
        _mostrarError('No se pudo autorizar Google Pay: $e');
      }
    }
  }

  Future<void> _autorizarPaypalFrontend() async {
    if (_estaCargando) return;

    setState(() => _estaCargando = true);
    try {
      final cart = Provider.of<CartProvider>(context, listen: false);
      final total = _calcularTotal(cart);

      final orden = await ApiService.crearOrdenPaypal(
        total: total,
        currency: 'EUR',
      );

      final orderId = orden['id']?.toString();
      if (orderId == null || orderId.isEmpty) {
        throw Exception('No se pudo crear la orden de PayPal');
      }

      String? approvalUrl;
      if (orden['approval_url'] != null) {
        approvalUrl = orden['approval_url'].toString();
      } else if (orden['links'] != null && orden['links'] is List) {
        for (final link in orden['links'] as List) {
          if (link is Map<String, dynamic> &&
              (link['rel']?.toString().toLowerCase() == 'approve' ||
                  link['rel']?.toString().toLowerCase() == 'approval_url')) {
            approvalUrl = link['href']?.toString();
            break;
          }
        }
      }

      if (approvalUrl == null || approvalUrl.isEmpty) {
        throw Exception('No se recibió URL de aprobación de PayPal');
      }

      await launchUrl(Uri.parse(approvalUrl), webOnlyWindowName: '_blank');

      if (mounted) {
        setState(() {
          _paypalAutorizado = true;
          _paypalOrderId = orderId;
          _googlePayAutorizado = false;
          _estaCargando = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _estaCargando = false);
        _mostrarError('Error al iniciar PayPal: $e');
      }
    }
  }

  void _mostrarError(String mensaje) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensaje),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: const RoundedRectangleBorder(),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      ),
    );
  }

  double _hPad(BoxConstraints c) {
    const maxW = 560.0;
    return (c.maxWidth - c.maxWidth.clamp(0.0, maxW)) / 2 + 20;
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

class _StepIndicator extends StatelessWidget {
  final int paso;
  const _StepIndicator({required this.paso});

  @override
  Widget build(BuildContext context) {
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
          _StepDot(label: 'Confirmar', activo: paso == 0, hecho: paso > 0),
          _Linea(activa: paso > 0),
          _StepDot(label: 'Entrega', activo: paso == 1, hecho: paso > 1),
          _Linea(activa: paso > 1),
          _StepDot(label: 'Pago', activo: paso == 2, hecho: false),
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
        color: activa ? AppColors.button : Colors.white.withValues(alpha: 0.20),
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
          duration: const Duration(milliseconds: 250),
          width: 28,
          height: 28,
          decoration: BoxDecoration(
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
                ? const Icon(Icons.check, size: 13, color: Colors.white)
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
            color: filled ? Colors.white : Colors.white.withValues(alpha: 0.35),
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
  final int paso;
  final bool cargando;
  final OpcionEntrega entrega;
  final VoidCallback onSiguiente;
  final VoidCallback? onAtras;

  const _BottomBar({
    required this.paso,
    required this.cargando,
    required this.entrega,
    required this.onSiguiente,
    this.onAtras,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<CartProvider>(
      builder: (context, cart, _) {
        final envio = paso == 0
            ? 0.0
            : (entrega == OpcionEntrega.domicilio ? 3.99 : 0.0);
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
              Column(
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
                      'incl. 3,99 € envío',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.40),
                        fontSize: 10,
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 16),
              if (onAtras != null) ...[
                GestureDetector(
                  onTap: onAtras,
                  child: Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
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
                const SizedBox(width: 8),
              ],
              Expanded(
                child: GestureDetector(
                  onTap: cargando ? null : onSiguiente,
                  child: Container(
                    height: 50,
                    color: AppColors.button,
                    child: Center(
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
                              paso < 2 ? 'CONTINUAR' : 'CONFIRMAR PEDIDO',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.8,
                              ),
                            ),
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
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
        decoration: BoxDecoration(
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
              duration: const Duration(milliseconds: 200),
              width: 48,
              height: 48,
              color: seleccionada
                  ? AppColors.button
                  : Colors.white.withValues(alpha: 0.10),
              child: Icon(
                icono,
                size: 22,
                color: seleccionada
                    ? Colors.white
                    : Colors.white.withValues(alpha: 0.60),
              ),
            ),
            const SizedBox(width: 16),
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
            const SizedBox(width: 12),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              color: seleccionada
                  ? AppColors.button
                  : Colors.white.withValues(alpha: 0.10),
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
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        decoration: BoxDecoration(
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
            const SizedBox(width: 16),
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
              duration: const Duration(milliseconds: 200),
              width: 22,
              height: 22,
              decoration: BoxDecoration(
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
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
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
              const Icon(Icons.check_circle, size: 16, color: AppColors.button),
          ],
        ),
      ),
    );
  }
}

// ── Diálogo de confirmación Stripe Checkout ───────────────────────────────────

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
              'El pago aún no se ha completado. Completa el pago en la pestaña de Stripe y vuelve a intentarlo.';
        });
      }
    } catch (e) {
      if (mounted)
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
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
          onPressed: _verificando
              ? null
              : () => Navigator.of(context).pop(false),
          child: const Text(
            'Cancelar',
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.button,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(4),
            ),
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
    return Container(
      height: 130,
      clipBehavior: Clip.hardEdge,
      decoration: const BoxDecoration(),
      child: Stack(
        fit: StackFit.expand,
        children: [
          imageUrl != null && imageUrl.isNotEmpty
              ? Image.network(
                  imageUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => _imgFallback(),
                )
              : _imgFallback(),
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
                  child: GestureDetector(
                    onTap: () => cart.removeProduct(item.key),
                    child: Container(
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.40),
                        border: Border.all(color: Colors.white24),
                      ),
                      child: const Icon(
                        Icons.close,
                        size: 13,
                        color: Colors.white,
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
                  crossAxisAlignment: CrossAxisAlignment.center,
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
        GestureDetector(
          onTap: () => cart.removeItem(item.producto.id),
          child: Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.30),
              border: Border.all(color: Colors.white38),
            ),
            child: const Icon(Icons.remove, size: 13, color: Colors.white),
          ),
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
        GestureDetector(
          onTap: () => cart.addItem(item.producto),
          child: Container(
            width: 30,
            height: 30,
            color: AppColors.button,
            child: const Icon(Icons.add, size: 15, color: Colors.white),
          ),
        ),
      ],
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
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      padding: const EdgeInsets.all(16),
      child: child,
    );
  }
}

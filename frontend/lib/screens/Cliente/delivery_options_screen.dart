import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/colors_style.dart';
import '../../models/opciones_pedido.dart';
import '../../providers/cart_provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../../components/Cliente/campos_direccion.dart';
import '../../components/Cliente/campos_tarjeta.dart';
import 'pedido_confirmado_screen.dart';

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
  bool _applePayAutorizado = false; // Agregado desde el bloque de conflicto
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
                  });
                },
              ),
              if (_pagoSeleccionado == MetodoPago.paypal) ...[
                const SizedBox(height: 8),
                _buildPaypalButton(),
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
        final dir = auth.usuarioActual?.direccion ?? '';
        return Column(
          children: [
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
            _DireccionOption(
              icono: Icons.edit_location_alt_outlined,
              titulo: 'Otra dirección',
              subtitulo: 'Especifica una diferente',
              seleccionada:
                  _direccionSeleccionada == OpcionDireccion.alternativa,
              onTap: () => setState(
                () => _direccionSeleccionada = OpcionDireccion.alternativa,
              ),
            ),
            const SizedBox(height: 12),
            _FormPanel(
              child: CamposDireccion(
                controladorDireccion: _controladorDireccion,
                controladorNotas: _controladorNotas,
                mostrarDireccionAlternativa:
                    _direccionSeleccionada == OpcionDireccion.alternativa,
              ),
            ),
          ],
        );
      },
    );
  }

  void _irAPago() {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (_entregaSeleccionada == OpcionEntrega.domicilio) {
      final dir = _direccionSeleccionada == OpcionDireccion.registrada
          ? (auth.usuarioActual?.direccion ?? '')
          : _controladorDireccion.text.trim();
      if (dir.isEmpty) {
        _mostrarError('Introduce una dirección de entrega');
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

      await launchUrl(Uri.parse(checkoutUrl), webOnlyWindowName: '_blank');

      if (!mounted) return;

      final confirmado = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => _StripeCheckoutDialog(sessionId: sessionId),
      );

      if (confirmado != true || !mounted) return;

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
    if (!_googlePayAutorizado) {
      _mostrarError('Primero autoriza Google Pay');
      return;
    }

    setState(() => _estaCargando = true);

    try {
      final cart = Provider.of<CartProvider>(context, listen: false);
      final total = _calcularTotal(cart);

      final compra = await ApiService.iniciarGooglePay(total: total);

      final productId = (compra['productId'] ?? 'pedido_bravo').toString();
      final purchaseToken = (compra['purchaseToken'] ?? compra['token'] ?? '')
          .toString();

      if (purchaseToken.isEmpty) {
        throw Exception('No se recibió purchaseToken de Google Pay');
      }

      final verificacion = await ApiService.verificarCompraGooglePlay(
        packageName: 'com.tuempresa.grupo_bravo',
        productId: productId,
        purchaseToken: purchaseToken,
      );

      final verificado =
          verificacion['success'] == true ||
          verificacion['verified'] == true ||
          verificacion['valid'] == true ||
          verificacion['status'] == 'OK' ||
          verificacion['status'] == 'SUCCESS';

      if (!verificado) {
        throw Exception('La compra no fue validada por Google');
      }

      await _crearPedidoFinal(
        referenciaPago: (verificacion['orderId'] ?? purchaseToken).toString(),
        estadoPago: 'pagado',
      );
    } catch (e) {
      if (mounted) {
        setState(() => _estaCargando = false);
        _mostrarError('Error en Google Pay: $e');
      }
    }
  }

  Future<void> _procesarPaypalYCrearPedido() async {
    if (!_paypalAutorizado) {
      _mostrarError('Primero autoriza PayPal');
      return;
    }

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
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Row(
              children: [
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
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Row(
              children: [
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

  Future<void> _autorizarGooglePayFrontend() async {
    if (_estaCargando) return;
    setState(() => _estaCargando = true);
    try {
      await Future.delayed(const Duration(seconds: 1));
      if (mounted) {
        setState(() {
          _googlePayAutorizado = true;
          _paypalAutorizado = false;
          _applePayAutorizado = false;
          _estaCargando = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _estaCargando = false);
        _mostrarError('No se pudo autorizar Google Pay');
      }
    }
  }

  Future<void> _autorizarApplePayFrontend() async {
    if (_estaCargando) return;
    setState(() => _estaCargando = true);
    try {
      final soportado = await Stripe.instance.isPlatformPaySupported();
      if (!soportado) {
        throw Exception('Apple Pay no está disponible en este dispositivo');
      }
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
        _mostrarError('No se pudo autorizar Apple Pay: $e');
      }
    }
  }

  Future<void> _autorizarPaypalFrontend() async {
    if (_estaCargando) return;
    setState(() => _estaCargando = true);
    try {
      await Future.delayed(const Duration(seconds: 1));
      if (mounted) {
        setState(() {
          _paypalAutorizado = true;
          _googlePayAutorizado = false;
          _applePayAutorizado = false;
          _estaCargando = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _estaCargando = false);
        _mostrarError('No se pudo autorizar PayPal');
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

// ... Resto de los Widgets internos (_StepIndicator, _BottomBar, _EntregaCard, etc. sin cambios) ...

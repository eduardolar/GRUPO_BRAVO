// ============================================================================
// frontend/lib/screens/cliente/opciones_entrega_screen.dart
// ----------------------------------------------------------------------------
// CHECKOUT del cliente: dónde entregar + cómo pagar + confirmar.
//
// Esta es la pantalla más compleja del flujo de cliente. Maneja:
//   1) Tipo de entrega (en mesa / recoger / domicilio) y, si es domicilio,
//      elección de dirección (guardada en perfil o alternativa puntual).
//   2) Método de pago (efectivo / tarjeta / Apple Pay / Google Pay / PayPal).
//      - Tarjeta: en móvil usa flutter_stripe.CardField (PaymentSheet).
//                 En web abre Stripe Checkout en una nueva pestaña.
//   3) Idempotencia: genera un UUID por intento y lo manda como
//      Idempotency-Key para que un reintento no cree dos pedidos.
//   4) Tras pagar (o si es efectivo): crea el pedido en backend, vacía el
//      carrito, marca el pedido activo y navega a "pedido_confirmado".
//
// Cuando el cliente vuelve de Stripe en web, NO aterriza aquí, sino en
// `inicio_screen.dart` (que lee el query param y reactiva el flujo).
// ============================================================================
import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';

import '../../components/Cliente/campos_tarjeta.dart';
import '../../components/Cliente/empty_state.dart';
import '../../core/app_snackbar.dart';
import '../../core/colors_style.dart';
import '../../models/opciones_pedido.dart';
import '../../providers/auth_provider.dart';
import '../../providers/cart_provider.dart';
import '../../services/api_service.dart';
import '../../services/cupon_service.dart';
import 'direccion_screen.dart';
import 'opciones_entrega/components/components.dart';
import 'pedido_confirmado_screen.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:math';

export '../../models/opciones_pedido.dart';

// ── Enum de paso (internal alias para compatibilidad con BottomBar / StepIndicator) ──

typedef _Paso = EntregaPaso;

// ── Constante de coste de envío (re-exportada para compatibilidad) ───────────

const double _kCosteEnvio = kCosteEnvio;
const _kAnimFast = kAnimFast;
const _kAnimMed = kAnimMed;

// ── UUID helper ───────────────────────────────────────────────────────────────

const _uuid = Uuid();

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
  bool _usarPuntos = false; // Controla si el switch de puntos está activo

  bool _googlePayAutorizado = false;
  bool _googlePayProcesando = false;
  bool _paypalAutorizado = false;
  bool _applePayAutorizado = false;
  String? _paypalOrderId;
  String? _googlePayClientSecret;
  String? _googlePayPaymentIntentId;
  CardFieldInputDetails? _cardDetails;

  /// Clave de idempotencia para el intento de pago en curso.
  /// Se genera una sola vez cuando el usuario inicia un intento de pago
  /// y se reusa si reintenta por error de red. Se regenera cuando cambia
  /// el método de pago (_seleccionarMetodoPago) o al llegar a la pantalla
  /// de pago (_irAPago), garantizando que un intento distinto use clave distinta.
  String? _idempotencyKey;

  final _controladorDireccion = TextEditingController();
  final _controladorNotas = TextEditingController();
  final _controladorCupon = TextEditingController();

  String? _cuponAplicado;
  String? _cuponIdAplicado;
  String? _errorCupon;
  bool _validandoCupon = false;
  double _descuentoCuponAplicado = 0.0;

  @override
  void initState() {
    super.initState();
    final cart = context.read<CartProvider>();
    _entregaSeleccionada = cart.tienemesa
        ? OpcionEntrega.enMesa
        : OpcionEntrega.domicilio;
  }

  @override
  void dispose() {
    _controladorDireccion.dispose();
    _controladorNotas.dispose();
    _controladorCupon.dispose();
    super.dispose();
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  double _costeEnvio() =>
      _entregaSeleccionada == OpcionEntrega.domicilio ? _kCosteEnvio : 0.0;

  /// Descuento del cupón aplicado (lo que ve el cliente en el total).
  double _descuentoTotal() => _descuentoCuponAplicado;

  // 1. Calcula el total base (Items + Envío - Cupones) SIN PUNTOS
  double _calcularTotalBase(CartProvider cart) {
    final bruto = cart.totalPrice + _costeEnvio();
    final total = bruto - _descuentoTotal();
    return total < 0 ? 0.0 : total;
  }

  // 2. Calcula cuántos puntos se pueden usar como máximo (Arregla BUG #6)
  int _calcularPuntosAUsar(double totalBase) {
    if (!_usarPuntos) return 0;
    final usuario = context.read<AuthProvider>().usuarioActual;
    final puntosDisponibles = usuario?.puntos ?? 0;
    
    // Máximo de puntos que tiene sentido usar (totalBase * 10)
    final maxPuntosNecesarios = (totalBase * 10).toInt();
    
    return min(puntosDisponibles, maxPuntosNecesarios);
  }

  // 3. Calcula el total REAL que se va a cobrar (Arregla BUG #1 y #7)
  // Mantenemos el nombre _calcularTotal para no romper Stripe, PayPal, etc.
  double _calcularTotal(CartProvider cart) {
    final totalBase = _calcularTotalBase(cart);
    final puntosAUsar = _calcularPuntosAUsar(totalBase);
    final descuento = puntosAUsar / 10.0;
    
    final totalFinal = totalBase - descuento;
    return totalFinal < 0 ? 0.0 : totalFinal;
  }

  Future<void> _aplicarCupon() async {
    final codigo = _controladorCupon.text.trim().toUpperCase();

    if (codigo.isEmpty) {
      setState(() => _errorCupon = 'Introduce un cupón');
      return;
    }

    setState(() {
      _validandoCupon = true;
      _errorCupon = null;
    });

    try {
      final cart = context.read<CartProvider>();
      final resp = await CuponService.validar(
        codigo: codigo,
        subtotal: cart.totalPrice,
        costeEnvio: _costeEnvio(),
        restauranteId: cart.restauranteId,
      );

      if (!mounted) return;

      final valido = resp['valido'] == true;
      if (!valido) {
        setState(() {
          _validandoCupon = false;
          _cuponAplicado = null;
          _cuponIdAplicado = null;
          _descuentoCuponAplicado = 0.0;
          _errorCupon = (resp['mensaje'] ?? 'Cupón no válido').toString();
        });
        return;
      }

      final descuento = (resp['descuento'] as num?)?.toDouble() ?? 0.0;
      final id = resp['id']?.toString();

      setState(() {
        _validandoCupon = false;
        _cuponAplicado = codigo;
        _cuponIdAplicado = id;
        _descuentoCuponAplicado = descuento;
        _errorCupon = null;
        _controladorCupon.text = codigo;
        _controladorCupon.selection = TextSelection.fromPosition(
          TextPosition(offset: _controladorCupon.text.length),
        );
      });

      _showSnack('Cupón aplicado: $codigo');
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _validandoCupon = false;
        _cuponAplicado = null;
        _cuponIdAplicado = null;
        _descuentoCuponAplicado = 0.0;
        _errorCupon = 'No se pudo validar el cupón';
      });
    }
  }

  void _quitarCupon() {
    setState(() {
      _cuponAplicado = null;
      _cuponIdAplicado = null;
      _errorCupon = null;
      _descuentoCuponAplicado = 0.0;
      _controladorCupon.clear();
    });
  }

  /// Descuenta un uso del cupón aplicado en el backend tras crear el pedido.
  /// Silencia errores: si falla no debe abortar la confirmación del pedido,
  /// pero limpiamos el estado para no volver a intentarlo en este flujo.
  Future<void> _consumirCuponAplicado() async {
    final id = _cuponIdAplicado;
    if (id == null || id.isEmpty) return;
    try {
      await CuponService.registrarUso(id);
    } catch (e) {
      debugPrint('No se pudo registrar el uso del cupón: $e');
    } finally {
      _cuponIdAplicado = null;
    }
  }

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

  /// Selecciona un método de pago y regenera la clave de idempotencia porque
  /// se trata de un intento diferente (método distinto).
  void _seleccionarMetodoPago(MetodoPago metodo) {
    setState(() {
      _pagoSeleccionado = metodo;
      _resetAutorizacionesWallet();
      _idempotencyKey = _uuid.v4();
    });
  }

  /// Devuelve la clave del intento actual. Si todavía no hay clave (primera
  /// llamada sin haber cambiado de método), la genera en el momento.
  String _obtenerOGenerarIdempotencyKey() {
    _idempotencyKey ??= _uuid.v4();
    return _idempotencyKey!;
  }

  void _showSnack(String mensaje, {bool error = false}) {
    if (error) {
      showAppError(context, mensaje);
    } else {
      showAppSuccess(context, mensaje);
    }
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
        shape: const RoundedRectangleBorder(borderRadius: kRadiusEntrega),
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

  // ── Build ──────────────────────────────────────────────────────────────────

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
            const FondoConVelado(),
            SafeArea(
              child: Column(
                children: [
                  EntregaHeader(
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
                  StepIndicator(paso: _paso),
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: _kAnimMed,
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
                      child: KeyedSubtree(
                        key: ValueKey(_paso),
                        child: _buildPasoActual(),
                      ),
                    ),
                  ),
                  BottomBarEntrega(
                    paso: _paso,
                    cargando: _estaCargando,
                    costeEnvio: _costeEnvio(),
                    descuento: _descuentoTotal(),
                    onSiguiente: switch (_paso) {
                      _Paso.confirmar => () => setState(
                        () => _paso = _Paso.entrega,
                      ),
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
            if (_estaCargando) const OverlayCargando(),
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

  // ── Paso: Confirmar ────────────────────────────────────────────────────────

  Widget _buildPasoConfirmar() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final pad = hPad(constraints);
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
              padding: EdgeInsets.fromLTRB(pad, 16, pad, 24),
              // El cupón se introduce en el paso de pago, no aquí (evita
              // duplicar el campo en el flujo).
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
                      borderRadius: kRadiusEntrega,
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
                          content: Text('${removed.producto.nombre} eliminado'),
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
                  child: ArticuloCard(item: item, cart: cart),
                );
              },
            );
          },
        );
      },
    );
  }

  // ── Paso: Entrega ──────────────────────────────────────────────────────────

  Widget _seccionCupon(CartProvider cart) {
    return FormPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Cupón de descuento',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controladorCupon,
                  textCapitalization: TextCapitalization.characters,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Introduce tu cupón',
                    hintStyle: TextStyle(
                      color: Colors.white.withValues(alpha: 0.45),
                    ),
                    errorText: _errorCupon,
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.05),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(
                        color: Colors.white.withValues(alpha: 0.10),
                      ),
                    ),
                    focusedBorder: const OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(14)),
                      borderSide: BorderSide(color: Colors.white),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              ElevatedButton(
                onPressed: _validandoCupon ? null : _aplicarCupon,
                child: _validandoCupon
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Aplicar'),
              ),
            ],
          ),
          if (_cuponAplicado != null) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Cupón aplicado: $_cuponAplicado',
                    style: const TextStyle(
                      color: Colors.greenAccent,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: _quitarCupon,
                  child: const Text('Quitar'),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Descuento: -${_formatoEuro(_descuentoCuponAplicado)}',
              style: const TextStyle(color: Colors.greenAccent),
            ),
            const SizedBox(height: 4),
            Text(
              'Total final: ${_formatoEuro(_calcularTotal(cart))}',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPasoEntrega() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final pad = hPad(constraints);
        return Consumer<CartProvider>(
          builder: (context, cart, _) {
            return SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: EdgeInsets.symmetric(horizontal: pad, vertical: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _subtituloPaso('¿Cómo quieres recibir tu pedido?'),
                  const SizedBox(height: 18),
                  if (cart.tienemesa) ...[
                    EntregaCard(
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
                  EntregaCard(
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
                  EntregaCard(
                    icono: Icons.store_outlined,
                    titulo: 'Recoger en local',
                    subtitulo: 'Listo cuando llegues · ~20-30 min',
                    coste: 'Gratis',
                    seleccionada: _entregaSeleccionada == OpcionEntrega.recoger,
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

  Widget _seccionDireccion() {
    return Consumer<AuthProvider>(
      builder: (context, auth, _) {
        final dir = auth.usuarioActual?.direccion ?? '';
        return Column(
          children: [
            DireccionOption(
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
            DireccionOption(
              icono: Icons.map_outlined,
              titulo: 'Cambiar o usar mapa / GPS',
              subtitulo: 'Selecciona tu ubicación exacta en el mapa',
              seleccionada:
                  _direccionSeleccionada == OpcionDireccion.alternativa,
              onTap: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const DireccionScreen()),
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

  // ── Paso: Pago ─────────────────────────────────────────────────────────────

  // ── Paso: Pago ─────────────────────────────────────────────────────────────

  Widget _buildPasoPago() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final pad = hPad(constraints);
        // Obtenemos al usuario para leer sus puntos
        final usuario = context.watch<AuthProvider>().usuarioActual;
        final puntos = usuario?.puntos ?? 0;
        final cart = context.watch<CartProvider>();

        return SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.symmetric(horizontal: pad, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _subtituloPaso('Elige cómo quieres pagar'),
              const SizedBox(height: 18),

              // ── SECCIÓN CLUB BRAVO (Fase 4) ──
              if (puntos > 0)
                Padding(
                  padding: const EdgeInsets.only(bottom: 20),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.amber.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.amber.withValues(alpha: 0.5)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.stars, color: Colors.amber),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Usar mis Bravo Coins',
                                style: GoogleFonts.manrope(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                'Tienes $puntos puntos (${(puntos / 10).toStringAsFixed(2)}€ de dto.)',
                                style: GoogleFonts.manrope(
                                  color: Colors.white70,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Switch(
                          value: _usarPuntos,
                          activeThumbColor: Colors.amber,
                          onChanged: (val) {
                            setState(() {
                              _usarPuntos = val;
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              // ─────────────────────────────────

              // Cupón también en el paso de pago: el cliente puede aplicarlo
              // aquí sin tener que volver atrás a la pantalla de revisión.
              _seccionCupon(cart),
              const SizedBox(height: 20),

              PagoCard(
                icono: Icons.payments_outlined,
                titulo: 'Efectivo',
                subtitulo: 'Pagas al recibir el pedido',
                seleccionada: _pagoSeleccionado == MetodoPago.efectivo,
                onTap: () => _seleccionarMetodoPago(MetodoPago.efectivo),
              ),
              const SizedBox(height: 10),
              PagoCard(
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
                        child: FormPanel(
                          child: CamposTarjeta(
                            onCardChanged: (details) =>
                                setState(() => _cardDetails = details),
                          ),
                        ),
                      )
                    : const SizedBox(width: double.infinity),
              ),
              const SizedBox(height: 10),
              PagoCard(
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
                        child: GooglePayButton(
                          estaCargando: _estaCargando,
                          googlePayProcesando: _googlePayProcesando,
                          googlePayAutorizado: _googlePayAutorizado,
                          onAutorizar: _autorizarGooglePayFrontend,
                        ),
                      )
                    : const SizedBox(width: double.infinity),
              ),
              const SizedBox(height: 10),
              PagoCard(
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
                        child: PaypalButton(
                          estaCargando: _estaCargando,
                          paypalAutorizado: _paypalAutorizado,
                          onAutorizar: _autorizarPaypalFrontend,
                        ),
                      )
                    : const SizedBox(width: double.infinity),
              ),
              const SizedBox(height: 10),
              PagoCard(
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
                        child: ApplePayButton(
                          estaCargando: _estaCargando,
                          applePayAutorizado: _applePayAutorizado,
                          onAutorizar: _autorizarApplePayFrontend,
                        ),
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
  // ── Navegación entre pasos ─────────────────────────────────────────────────

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
    // Nueva pantalla de pago = nuevo intento = nueva clave de idempotencia.
    setState(() {
      _paso = _Paso.pago;
      _idempotencyKey = _uuid.v4();
    });
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

  // ── Procesadores de pago ───────────────────────────────────────────────────

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

      itemsResumen = cart.items.values
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

      // 1. Crear sesión Stripe
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
        idempotencyKey: _obtenerOGenerarIdempotencyKey(),
      );

      pedidoId =
          resultado['id']?.toString() ?? resultado['pedido_id']?.toString();

      if (!mounted) return;
      setState(() => _estaCargando = false);

      // 3. Abrir Stripe Checkout.
      //
      //    En **web**: redirect en la misma pestaña (`_self`). Es el
      //    comportamiento natural de Stripe Checkout: tras pagar redirige
      //    a `success_url`, que es la home con `?stripe_session=...`. La
      //    propia home (inicio_screen._verificarStripeRedirect) detecta
      //    el retorno y abre `PedidoConfirmadoScreen`. Por tanto el código
      //    que viene después NO se ejecuta en web — vaciamos el carrito
      //    aquí porque la página se va.
      //
      //    En **móvil/desktop**: navegador externo + diálogo de
      //    verificación al volver. Aquí el carrito se vacía solo si el
      //    pago se confirma.
      if (kIsWeb) {
        context.read<CartProvider>().clearCart();
        await launchUrl(Uri.parse(checkoutUrl), webOnlyWindowName: '_self');
        return;
      }

      await launchUrl(
        Uri.parse(checkoutUrl),
        mode: LaunchMode.externalApplication,
      );

      if (!mounted) return;

      // 4. Diálogo de verificación (solo móvil/desktop).
      final confirmado = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (_) => StripeCheckoutDialog(sessionId: sessionId!),
      );

      if (confirmado != true || !mounted) return;

      try {
        await ApiService.actualizarEstadoPago(referenciaPago: sessionId);
      } catch (e) {
        debugPrint('actualizarEstadoPago fallo: $e');
      }
      if (!mounted) return;

      await _consumirCuponAplicado();
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
      if (!mounted) return;
      setState(() => _estaCargando = false);
      _showSnack('Error en PayPal: $e', error: true);
    }
  }

  // ── Creación final del pedido (todos los métodos convergen aquí) ───────────

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

    final idempKey = _obtenerOGenerarIdempotencyKey();

// ── NUEVO: Calcular los puntos que vamos a usar de forma segura ──
    final totalBase = _calcularTotalBase(cart);
    final puntosAUsar = _calcularPuntosAUsar(totalBase);

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
        restauranteId: cart.restauranteId,
        idempotencyKey: idempKey,
        puntosUsados: puntosAUsar, // <--- AÑADIMOS LOS PUNTOS AQUÍ
        // El backend revalida el cupón y lo descuenta del total real.
        cuponCodigo: _cuponAplicado,
      );

      final pedidoId =
          resultado['id']?.toString() ?? resultado['pedido_id']?.toString();

      await _consumirCuponAplicado();

      cart.clearCart();

      // ── NUEVO: Refrescar el perfil para que los puntos bajen en la app ──
      // Usamos el método que tengas en tu AuthProvider para recargar al usuario.
      // Suele llamarse checkAuthStatus() o cargarPerfil()
// ── NUEVO: Restamos los puntos en la app al instante ──
      auth.descontarPuntosLocales(puntosAUsar);

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
      // No regeneramos la clave: el usuario puede reintentar con la misma.
      _showSnack('Error al crear pedido: $e', error: true);
    }
  }

  // ── Autorizaciones de wallet ───────────────────────────────────────────────

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

  // ── Layout helpers ─────────────────────────────────────────────────────────

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

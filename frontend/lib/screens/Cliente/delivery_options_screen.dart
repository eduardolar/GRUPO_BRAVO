import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/colors_style.dart';
import '../../models/opciones_pedido.dart';
import '../../providers/cart_provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../../components/Cliente/tarjeta_opcion_entrega.dart';
import '../../components/Cliente/tarjeta_opcion_direccion.dart';
import '../../components/Cliente/tarjeta_opcion_pago.dart';
import '../../components/Cliente/campos_direccion.dart';
import '../../components/Cliente/campos_tarjeta.dart';
import '../../components/Cliente/resumen_pedido.dart';
import 'pedido_confirmado_screen.dart';

// Re-exporta para mantener compatibilidad con imports existentes
export '../../models/opciones_pedido.dart';

class PantallaOpcionesEntrega extends StatefulWidget {
  const PantallaOpcionesEntrega({super.key});

  @override
  State<PantallaOpcionesEntrega> createState() =>
      _PantallaOpcionesEntregaState();
}

class _PantallaOpcionesEntregaState extends State<PantallaOpcionesEntrega> {
  late OpcionEntrega _entregaSeleccionada;
  MetodoPago _pagoSeleccionado = MetodoPago.efectivo;
  OpcionDireccion _direccionSeleccionada = OpcionDireccion.registrada;

  // Variable para controlar la animación de carga simulada
  bool _estaCargando = false;

  final _controladorDireccion = TextEditingController();
  final _controladorNotas = TextEditingController();
  final _controladorNumeroTarjeta = TextEditingController();
  final _controladorFechaExpiracion = TextEditingController();
  final _controladorCvv = TextEditingController();
  final _controladorNombreTitular = TextEditingController();

  @override
  void initState() {
    super.initState();
    final cart = Provider.of<CartProvider>(context, listen: false);
    _entregaSeleccionada =
        cart.tienemesa ? OpcionEntrega.enMesa : OpcionEntrega.domicilio;
  }

  @override
  void dispose() {
    _controladorDireccion.dispose();
    _controladorNotas.dispose();
    _controladorNumeroTarjeta.dispose();
    _controladorFechaExpiracion.dispose();
    _controladorCvv.dispose();
    _controladorNombreTitular.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.iconPrimary),
        title: const Text(
          'OPCIONES DE ENTREGA',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
      ),
      body: Stack( // Usamos Stack para poder oscurecer la pantalla si está cargando
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '¿Cómo quieres recibir tu pedido?',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 20),

                // --- Sección entrega ---
                Consumer<CartProvider>(
                  builder: (context, cart, _) {
                    if (cart.tienemesa) {
                      return TarjetaOpcionEntrega(
                        titulo: 'Comer en mesa ${cart.numeroMesa}',
                        subtitulo: 'Pedido asignado a tu mesa',
                        icono: Icons.restaurant,
                        seleccionada:
                            _entregaSeleccionada == OpcionEntrega.enMesa,
                        coste: 'Gratis',
                        alPulsar: () => setState(
                          () => _entregaSeleccionada = OpcionEntrega.enMesa,
                        ),
                      );
                    }

                    return Column(
                      children: [
                        TarjetaOpcionEntrega(
                          titulo: 'Entrega a domicilio',
                          subtitulo:
                              'Recibe tu pedido en la puerta de tu casa',
                          icono: Icons.delivery_dining,
                          seleccionada:
                              _entregaSeleccionada == OpcionEntrega.domicilio,
                          coste: '3,99 €',
                          alPulsar: () => setState(
                            () =>
                                _entregaSeleccionada = OpcionEntrega.domicilio,
                          ),
                        ),
                        if (_entregaSeleccionada ==
                            OpcionEntrega.domicilio) ...[
                          const SizedBox(height: 20),
                          const Text(
                            'Dirección de entrega',
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),
                          _seccionDireccion(),
                        ],
                        const SizedBox(height: 16),
                        TarjetaOpcionEntrega(
                          titulo: 'Recoger en restaurante',
                          subtitulo:
                              'Ven a recoger tu pedido cuando esté listo',
                          icono: Icons.store,
                          seleccionada:
                              _entregaSeleccionada == OpcionEntrega.recoger,
                          coste: 'Gratis',
                          alPulsar: () => setState(
                            () =>
                                _entregaSeleccionada = OpcionEntrega.recoger,
                          ),
                        ),
                      ],
                    );
                  },
                ),

                const SizedBox(height: 40),
                const Divider(color: AppColors.line),
                const SizedBox(height: 20),

                // --- Sección pago ---
                const Text(
                  'Método de pago',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 20),

                TarjetaOpcionPago(
                  titulo: 'Efectivo',
                  subtitulo: 'Paga al recibir tu pedido',
                  icono: Icons.payments,
                  seleccionada: _pagoSeleccionado == MetodoPago.efectivo,
                  alPulsar: () =>
                      setState(() => _pagoSeleccionado = MetodoPago.efectivo),
                ),
                const SizedBox(height: 16),

                TarjetaOpcionPago(
                  titulo: 'Tarjeta de crédito/débito',
                  subtitulo: 'Pago seguro online',
                  icono: Icons.credit_card,
                  seleccionada: _pagoSeleccionado == MetodoPago.tarjeta,
                  alPulsar: () =>
                      setState(() => _pagoSeleccionado = MetodoPago.tarjeta),
                ),

                // Desplegable de Tarjeta
                if (_pagoSeleccionado == MetodoPago.tarjeta) ...[
                  const SizedBox(height: 20),
                  CamposTarjeta(
                    controladorNumero: _controladorNumeroTarjeta,
                    controladorFechaExpiracion: _controladorFechaExpiracion,
                    controladorCvv: _controladorCvv,
                    controladorNombreTitular: _controladorNombreTitular,
                  ),
                ],

                const SizedBox(height: 16),

                // Botón de Google Pay
                TarjetaOpcionPago(
                  titulo: 'Google Pay',
                  subtitulo: 'Paga rápido con tu cuenta de Google',
                  icono: Icons.android,
                  seleccionada: _pagoSeleccionado == MetodoPago.googlePay,
                  alPulsar: () =>
                      setState(() => _pagoSeleccionado = MetodoPago.googlePay),
                ),
                const SizedBox(height: 16),

                // Botón de PayPal
                TarjetaOpcionPago(
                  titulo: 'PayPal',
                  subtitulo: 'Paga con tu cuenta de PayPal',
                  icono: Icons.account_balance_wallet,
                  seleccionada: _pagoSeleccionado == MetodoPago.paypal,
                  alPulsar: () =>
                      setState(() => _pagoSeleccionado = MetodoPago.paypal),
                ),

                const SizedBox(height: 40),

                // --- Resumen ---
                ResumenPedido(opcionEntrega: _entregaSeleccionada),

                const SizedBox(height: 30),

                // --- Botón confirmar ---
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    // Bloqueamos el botón si está cargando
                    onPressed: _estaCargando ? null : _confirmarPedido,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.button,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _estaCargando
                        ? const SizedBox(
                            height: 24,
                            width: 24,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : const Text(
                            'CONFIRMAR PEDIDO',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
          
          // Pantalla de carga semitransparente bloqueando la pantalla
          if (_estaCargando)
            Container(
              color: Colors.black.withOpacity(0.3),
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            ),
        ],
      ),
    );
  }

  // --- Sección Dirección ---
  Widget _seccionDireccion() {
    return Consumer<AuthProvider>(
      builder: (context, auth, child) {
        final direccionUsuario = auth.usuarioActual?.direccion ?? '';
        return Column(
          children: [
            TarjetaOpcionDireccion(
              titulo: 'Dirección registrada',
              subtitulo: direccionUsuario.isNotEmpty
                  ? direccionUsuario
                  : 'No hay dirección registrada',
              icono: Icons.home,
              seleccionada:
                  _direccionSeleccionada == OpcionDireccion.registrada,
              alPulsar: () => setState(
                () => _direccionSeleccionada = OpcionDireccion.registrada,
              ),
            ),
            const SizedBox(height: 12),
            TarjetaOpcionDireccion(
              titulo: 'Dirección alternativa',
              subtitulo: 'Especificar otra dirección de entrega',
              icono: Icons.edit_location,
              seleccionada:
                  _direccionSeleccionada == OpcionDireccion.alternativa,
              alPulsar: () => setState(
                () => _direccionSeleccionada = OpcionDireccion.alternativa,
              ),
            ),
            const SizedBox(height: 12),
            CamposDireccion(
              controladorDireccion: _controladorDireccion,
              controladorNotas: _controladorNotas,
              mostrarDireccionAlternativa:
                  _direccionSeleccionada == OpcionDireccion.alternativa,
            ),
          ],
        );
      },
    );
  }

  void _confirmarPedido() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);

    if (_entregaSeleccionada == OpcionEntrega.domicilio) {
      final direccion = _direccionSeleccionada == OpcionDireccion.registrada
          ? (auth.usuarioActual?.direccion ?? '')
          : _controladorDireccion.text.trim();

      if (direccion.isEmpty) {
        _mostrarError(
          'Por favor, selecciona o introduce una dirección de entrega',
        );
        return;
      }
    }

    if (_pagoSeleccionado == MetodoPago.tarjeta) {
      if (_controladorNumeroTarjeta.text.trim().isEmpty ||
          _controladorFechaExpiracion.text.trim().isEmpty ||
          _controladorCvv.text.trim().isEmpty ||
          _controladorNombreTitular.text.trim().isEmpty) {
        _mostrarError('Por favor, completa todos los datos de la tarjeta');
        return;
      }

      final numeroTarjeta = _controladorNumeroTarjeta.text.replaceAll(' ', '');
      if (numeroTarjeta.length < 13 || numeroTarjeta.length > 19) {
        _mostrarError('Número de tarjeta inválido');
        return;
      }

      final fechaRegex = RegExp(r'^\d{2}/\d{2}$');
      if (!fechaRegex.hasMatch(_controladorFechaExpiracion.text)) {
        _mostrarError('Formato de fecha inválido (MM/AA)');
        return;
      }
    }

    // Activamos la pantalla de carga de simulación
    setState(() {
      _estaCargando = true;
    });

    // Hacemos una pausa artificial de 2 segundos para dar la sensación 
    // de que estamos conectando con el banco o pasarela de pago
    await Future.delayed(const Duration(seconds: 2));

    // Mapeo de los nuevos tipos de pago para enviarlos al backend
    String tipoPagoStr;
    switch (_pagoSeleccionado) {
      case MetodoPago.efectivo:
        tipoPagoStr = 'Efectivo';
        break;
      case MetodoPago.tarjeta:
        tipoPagoStr = 'Tarjeta';
        break;
      case MetodoPago.googlePay:
        tipoPagoStr = 'Google Pay';
        break;
      case MetodoPago.paypal:
        tipoPagoStr = 'PayPal';
        break;
    }

    final tipoEntrega = switch (_entregaSeleccionada) {
      OpcionEntrega.domicilio => 'Entrega a domicilio',
      OpcionEntrega.recoger => 'Recoger en restaurante',
      OpcionEntrega.enMesa => 'Comer en el local',
    };

    final cart = Provider.of<CartProvider>(context, listen: false);
    final costeEnvio = _entregaSeleccionada == OpcionEntrega.domicilio
        ? 3.99
        : 0.0;
    final total = cart.totalPrice + costeEnvio;

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

      await ApiService.crearPedido(
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
      );

      cart.clearCart();

      if (mounted) {
        setState(() {
          _estaCargando = false;
        });
        
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => PedidoConfirmadoScreen(
              tipoEntrega: tipoEntrega,
              tipoPago: tipoPagoStr,
              total: total,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _estaCargando = false;
        });
        _mostrarError('Error al crear pedido: ${e.toString()}');
      }
    }
  }

  void _mostrarError(String mensaje) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(mensaje), backgroundColor: Colors.red),
    );
  }
}
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
  OpcionEntrega _entregaSeleccionada = OpcionEntrega.domicilio;
  MetodoPago _pagoSeleccionado = MetodoPago.efectivo;
  OpcionDireccion _direccionSeleccionada = OpcionDireccion.registrada;

  final _controladorDireccion = TextEditingController();
  final _controladorNotas = TextEditingController();
  final _controladorNumeroTarjeta = TextEditingController();
  final _controladorFechaExpiracion = TextEditingController();
  final _controladorCvv = TextEditingController();
  final _controladorNombreTitular = TextEditingController();

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
      body: SingleChildScrollView(
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
            TarjetaOpcionEntrega(
              titulo: 'Entrega a domicilio',
              subtitulo: 'Recibe tu pedido en la puerta de tu casa',
              icono: Icons.delivery_dining,
              seleccionada: _entregaSeleccionada == OpcionEntrega.domicilio,
              coste: '3,99 €',
              alPulsar: () => setState(
                () => _entregaSeleccionada = OpcionEntrega.domicilio,
              ),
            ),

            if (_entregaSeleccionada == OpcionEntrega.domicilio) ...[
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
              subtitulo: 'Ven a recoger tu pedido cuando esté listo',
              icono: Icons.store,
              seleccionada: _entregaSeleccionada == OpcionEntrega.recoger,
              coste: 'Gratis',
              alPulsar: () =>
                  setState(() => _entregaSeleccionada = OpcionEntrega.recoger),
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

            if (_pagoSeleccionado == MetodoPago.tarjeta) ...[
              const SizedBox(height: 20),
              CamposTarjeta(
                controladorNumero: _controladorNumeroTarjeta,
                controladorFechaExpiracion: _controladorFechaExpiracion,
                controladorCvv: _controladorCvv,
                controladorNombreTitular: _controladorNombreTitular,
              ),
            ],

            const SizedBox(height: 40),

            // --- Resumen ---
            ResumenPedido(opcionEntrega: _entregaSeleccionada),

            const SizedBox(height: 30),

            // --- Botón confirmar ---
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _confirmarPedido,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.button,
                  foregroundColor: AppColors.background,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
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
    );
  }

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

    final tipoEntrega = _entregaSeleccionada == OpcionEntrega.domicilio
        ? 'Entrega a domicilio'
        : 'Recoger en restaurante';
    final tipoPago = _pagoSeleccionado == MetodoPago.efectivo
        ? 'Efectivo'
        : 'Tarjeta';

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
            },
          )
          .toList();

      await ApiService.crearPedido(
        userId: auth.usuarioActual?.id ?? '',
        items: items,
        tipoEntrega: tipoEntrega,
        metodoPago: tipoPago,
        total: total,
        direccionEntrega: direccionEntrega,
        notas: _controladorNotas.text.trim(),
      );

      cart.clearCart();

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => PedidoConfirmadoScreen(
              tipoEntrega: tipoEntrega,
              tipoPago: tipoPago,
              total: total,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
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

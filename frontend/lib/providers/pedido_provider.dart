import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/api_service.dart';
import 'auth_provider.dart';
import 'cart_provider.dart';

class PedidoProvider extends ChangeNotifier {
  String _mesaId = ''; // Aquí guardamos el ID escaneado
  List<Map<String, dynamic>> _carrito = [];

  String get mesaId => _mesaId;

  // Método para guardar la mesa cuando el QRScanner termine
  void setMesa(String id) {
    _mesaId = id;
    notifyListeners(); // Notifica a la app que ya tenemos mesa
  }

  // Método para enviar el pedido final
  void limpiarPedido() {
    _mesaId = '';
    _carrito = [];
    notifyListeners();
  }

  // Dentro del método build o del botón de confirmar
  void _finalizarOrden(BuildContext context) async {
    final cartProv = Provider.of<CartProvider>(context, listen: false);
    final pedidoProv = Provider.of<PedidoProvider>(context, listen: false);
    final authProv = Provider.of<AuthProvider>(context, listen: false);

    if (pedidoProv.mesaId.isEmpty) {
      // Si intentan pagar sin haber escaneado el QR
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Por favor, escanea el QR de tu mesa primero"),
        ),
      );
      Navigator.pushNamed(context, '/scanner');
      return;
    }

    // Llamamos al servicio para enviar a Python
    final items = cartProv.items.values
        .map(
          (item) => {
            'producto_id': item.producto.id,
            'nombre': item.producto.nombre,
            'cantidad': item.cantidad,
            'precio': item.producto.precio,
          },
        )
        .toList();

    final resultado = await ApiService.crearPedido(
      userId: authProv.usuarioActual?.id ?? '',
      items: items,
      tipoEntrega: 'MESA',
      metodoPago: 'EFECTIVO',
      total: cartProv.totalPrice,
      mesaId: pedidoProv.mesaId,
      numeroMesa: int.tryParse(pedidoProv.mesaId),
      estadoPago: 'pendiente',
    );

    final exito = resultado['id'] != null || resultado['pedido_id'] != null;

    if (exito) {
      cartProv.clearCart();
      pedidoProv.limpiarPedido(); // Limpiamos mesa tras pagar
      Navigator.pushNamed(context, '/exito_screen');
    }
  }
}

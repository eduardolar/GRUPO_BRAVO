import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/models/usuario_model.dart';
import 'package:frontend/models/pedido_model.dart';

void main() {
  group('Smoke tests — modelos básicos instanciables', () {
    test('Usuario se puede instanciar con valores mínimos', () {
      final u = Usuario(
        id: '1',
        nombre: 'Test',
        email: 'test@test.com',
        contrasena: '',
        telefono: '',
        direccion: '',
      );
      expect(u.rol, RolUsuario.cliente);
      expect(u.totpEnabled, false);
    });

    test('ProductoPedido calcula subtotal', () {
      final p = ProductoPedido(nombre: 'Pizza', cantidad: 3, precio: 10.0);
      expect(p.subtotal, 30.0);
    });

    test('Usuario.fromJson roundtrip', () {
      final json = {
        'id': 'u1',
        'nombre': 'Ana',
        'correo': 'ana@test.com',
        'telefono': '600',
        'direccion': 'Calle 1',
        'rol': 'administrador',
        'totp_enabled': true,
      };
      final u = Usuario.fromJson(json);
      expect(u.rol, RolUsuario.administrador);
      expect(u.totpEnabled, true);
      expect(u.toJson()['rol'], 'administrador');
    });

    test('Pedido.fromMap con productos anidados', () {
      final map = {
        'id': 'p1',
        'fecha': '2024-01-01',
        'total': 20.0,
        'estado': 'pendiente',
        'items': 1,
        'tipoEntrega': 'local',
        'metodoPago': 'tarjeta',
        'productos': [
          {'nombre': 'Burger', 'cantidad': 1, 'precio': 10.0},
        ],
      };
      final pedido = Pedido.fromMap(map);
      expect(pedido.productos.first.nombre, 'Burger');
      expect(pedido.productos.first.subtotal, 10.0);
    });
  });
}

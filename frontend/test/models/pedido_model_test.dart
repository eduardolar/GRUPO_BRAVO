import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/models/pedido_model.dart';

void main() {
  group('ProductoPedido.fromMap', () {
    test('parsea campos básicos', () {
      final map = {'nombre': 'Pizza', 'cantidad': 2, 'precio': 12.5, 'sin': []};
      final p = ProductoPedido.fromMap(map);

      expect(p.nombre, 'Pizza');
      expect(p.cantidad, 2);
      expect(p.precio, 12.5);
      expect(p.sin, isEmpty);
    });

    test('acepta producto_nombre como alternativa a nombre', () {
      final map = {'producto_nombre': 'Pasta', 'cantidad': 1, 'precio': 8.0};
      final p = ProductoPedido.fromMap(map);
      expect(p.nombre, 'Pasta');
    });

    test('cantidad por defecto es 1 si falta', () {
      final map = {'nombre': 'Agua', 'precio': 2.0};
      final p = ProductoPedido.fromMap(map);
      expect(p.cantidad, 1);
    });

    test('precio por defecto es 0 si falta', () {
      final map = {'nombre': 'Pan', 'cantidad': 1};
      final p = ProductoPedido.fromMap(map);
      expect(p.precio, 0.0);
    });

    test('parsea lista de exclusiones', () {
      final map = {
        'nombre': 'Hamburguesa',
        'cantidad': 1,
        'precio': 9.0,
        'sin': ['cebolla', 'pepino'],
      };
      final p = ProductoPedido.fromMap(map);
      expect(p.sin, containsAll(['cebolla', 'pepino']));
    });

    test('subtotal es cantidad × precio', () {
      final map = {'nombre': 'Pizza', 'cantidad': 3, 'precio': 10.0};
      final p = ProductoPedido.fromMap(map);
      expect(p.subtotal, closeTo(30.0, 0.001));
    });
  });

  group('ProductoPedido.toMap', () {
    test('serializa todos los campos', () {
      final p = ProductoPedido(nombre: 'Pizza', cantidad: 2, precio: 10.0, sin: ['sal']);
      final map = p.toMap();

      expect(map['nombre'], 'Pizza');
      expect(map['cantidad'], 2);
      expect(map['precio'], 10.0);
      expect(map['sin'], ['sal']);
    });
  });

  group('Pedido.fromMap', () {
    final baseMap = {
      'id': 'p001',
      'fecha': '2024-06-15T14:30:00',
      'total': 35.5,
      'estado': 'preparando',
      'items': 2,
      'tipoEntrega': 'local',
      'metodoPago': 'tarjeta',
      'productos': [
        {'nombre': 'Pizza', 'cantidad': 2, 'precio': 12.5},
        {'nombre': 'Refresco', 'cantidad': 1, 'precio': 2.5},
      ],
    };

    test('parsea campos principales', () {
      final p = Pedido.fromMap(baseMap);

      expect(p.id, 'p001');
      expect(p.total, 35.5);
      expect(p.estado, 'preparando');
      expect(p.tipoEntrega, 'local');
      expect(p.metodoPago, 'tarjeta');
    });

    test('parsea lista de productos', () {
      final p = Pedido.fromMap(baseMap);
      expect(p.productos.length, 2);
      expect(p.productos.first.nombre, 'Pizza');
    });

    test('productos vacíos si falta el campo', () {
      final mapSinProductos = {...baseMap}..remove('productos');
      final p = Pedido.fromMap(mapSinProductos);
      expect(p.productos, isEmpty);
    });

    test('campos opcionales son null si no vienen', () {
      final p = Pedido.fromMap(baseMap);
      expect(p.direccion, isNull);
      expect(p.mesaId, isNull);
      expect(p.numeroMesa, isNull);
      expect(p.notas, isNull);
    });

    test('parsea número de mesa', () {
      final p = Pedido.fromMap({...baseMap, 'numeroMesa': 5});
      expect(p.numeroMesa, 5);
    });

    test('parsea dirección de entrega', () {
      final p = Pedido.fromMap({...baseMap, 'direccion': 'Calle Mayor 10'});
      expect(p.direccion, 'Calle Mayor 10');
    });

    test('parsea notas', () {
      final p = Pedido.fromMap({...baseMap, 'notas': 'Sin gluten por favor'});
      expect(p.notas, 'Sin gluten por favor');
    });
  });

  group('Pedido.toMap', () {
    test('incluye todos los campos básicos', () {
      final pedido = Pedido(
        id: 'p1',
        fecha: '2024-01-01',
        total: 20.0,
        estado: 'pendiente',
        items: 1,
        tipoEntrega: 'domicilio',
        metodoPago: 'efectivo',
        productos: [],
      );

      final map = pedido.toMap();

      expect(map['id'], 'p1');
      expect(map['total'], 20.0);
      expect(map['estado'], 'pendiente');
      expect(map['tipoEntrega'], 'domicilio');
      expect(map['metodoPago'], 'efectivo');
      expect(map['productos'], isEmpty);
    });
  });
}

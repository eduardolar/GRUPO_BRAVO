import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/models/producto_model.dart';

void main() {
  group('Producto.fromMap', () {
    test('parsea campos básicos', () {
      final p = Producto.fromMap({
        'id': 'p1',
        'nombre': 'Hamburguesa',
        'descripcion': 'Carne 100% vacuna',
        'precio': 9.5,
        'categoria': 'Hamburguesas',
        'imagenUrl': 'https://example.com/h.png',
      });
      expect(p.id, 'p1');
      expect(p.nombre, 'Hamburguesa');
      expect(p.precio, 9.5);
      expect(p.categoria, 'Hamburguesas');
      expect(p.imagenUrl, 'https://example.com/h.png');
      expect(p.estaDisponible, isTrue);
      expect(p.ingredientes, isEmpty);
    });

    test('precio entero se convierte a double', () {
      final p = Producto.fromMap({'precio': 10});
      expect(p.precio, 10.0);
      expect(p.precio, isA<double>());
    });

    test('ingredientes como lista de strings se convierten a Ingrediente', () {
      final p = Producto.fromMap({
        'ingredientes': ['Tomate', 'Lechuga'],
      });
      expect(p.ingredientes, hasLength(2));
      expect(p.ingredientes.first.nombre, 'Tomate');
    });

    test('estaDisponible respeta valor explícito', () {
      final p = Producto.fromMap({'estaDisponible': false});
      expect(p.estaDisponible, isFalse);
    });
  });

  group('Producto.toMap', () {
    test('roundtrip preserva campos básicos', () {
      final original = Producto.fromMap({
        'id': 'p1',
        'nombre': 'Pizza',
        'descripcion': '',
        'precio': 12.0,
        'categoria': 'Pizzas',
      });
      final map = original.toMap();
      expect(map['id'], 'p1');
      expect(map['nombre'], 'Pizza');
      expect(map['precio'], 12.0);
      expect(map['categoria'], 'Pizzas');
      expect(map['ingredientes'], isA<List<dynamic>>());
    });
  });
}

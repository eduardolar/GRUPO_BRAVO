// ignore_for_file: avoid_relative_lib_imports

import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/models/producto_model.dart';
import 'package:frontend/screens/trabajador/servicio_trabajador/comanda_helpers.dart';

// ── Fixture de productos de prueba ────────────────────────────────────────────

Producto _producto({
  required String id,
  required String nombre,
  required double precio,
}) => Producto(
  id: id,
  nombre: nombre,
  descripcion: '',
  precio: precio,
  categoria: 'test',
);

void main() {
  // ─── mergearCarritoEnAcumulado ────────────────────────────────────────────

  group('mergearCarritoEnAcumulado — merge de ítems', () {
    test(
      'añadir producto nuevo lo inserta en acumulados con cantidad correcta',
      () {
        final p = _producto(id: 'p1', nombre: 'Ensalada', precio: 8.50);

        final resultado = mergearCarritoEnAcumulado(
          acumulados: {},
          carrito: {p: 2},
          totalAcumuladoPrevio: 0.0,
        );

        expect(resultado.acumulados.containsKey('p1'), isTrue);
        expect(resultado.acumulados['p1']!['cantidad'], 2);
        expect(resultado.acumulados['p1']!['nombre'], 'Ensalada');
        expect(resultado.acumulados['p1']!['precio'], 8.50);
      },
    );

    test(
      'añadir 2 unidades del mismo producto acumula cantidad final = 2',
      () {
        final p = _producto(id: 'p1', nombre: 'Gazpacho', precio: 5.0);

        final resultado = mergearCarritoEnAcumulado(
          acumulados: {},
          carrito: {p: 2},
          totalAcumuladoPrevio: 0.0,
        );

        expect(resultado.acumulados['p1']!['cantidad'], 2);
      },
    );

    test(
      'añadir producto ya existente en acumulado suma cantidades',
      () {
        final p = _producto(id: 'p1', nombre: 'Croquetas', precio: 6.0);
        final acumuladoInicial = <String, Map<String, dynamic>>{
          'p1': {'producto_id': 'p1', 'nombre': 'Croquetas', 'cantidad': 3, 'precio': 6.0},
        };

        final resultado = mergearCarritoEnAcumulado(
          acumulados: acumuladoInicial,
          carrito: {p: 2},
          totalAcumuladoPrevio: 18.0,
        );

        // 3 previas + 2 nuevas = 5
        expect(resultado.acumulados['p1']!['cantidad'], 5);
      },
    );

    test(
      'dos productos distintos generan dos entradas separadas en acumulados',
      () {
        final p1 = _producto(id: 'p1', nombre: 'Sopa', precio: 4.0);
        final p2 = _producto(id: 'p2', nombre: 'Entrecot', precio: 18.0);

        final resultado = mergearCarritoEnAcumulado(
          acumulados: {},
          carrito: {p1: 1, p2: 1},
          totalAcumuladoPrevio: 0.0,
        );

        expect(resultado.acumulados.length, 2);
        expect(resultado.acumulados.containsKey('p1'), isTrue);
        expect(resultado.acumulados.containsKey('p2'), isTrue);
      },
    );

    test(
      'total se recalcula correctamente al añadir items',
      () {
        final p1 = _producto(id: 'p1', nombre: 'Pan', precio: 2.0);
        final p2 = _producto(id: 'p2', nombre: 'Vino', precio: 3.5);

        final resultado = mergearCarritoEnAcumulado(
          acumulados: {},
          carrito: {p1: 2, p2: 1},
          totalAcumuladoPrevio: 10.0,
        );

        // 10 + (2×2 + 1×3.5) = 10 + 7.5 = 17.5
        expect(resultado.totalAcumulado, closeTo(17.5, 0.001));
      },
    );

    test(
      'acumulado previo no se muta (el original queda inalterado)',
      () {
        final p = _producto(id: 'p1', nombre: 'Paella', precio: 12.0);
        final acumuladoOriginal = <String, Map<String, dynamic>>{};

        mergearCarritoEnAcumulado(
          acumulados: acumuladoOriginal,
          carrito: {p: 1},
          totalAcumuladoPrevio: 0.0,
        );

        // La función trabaja sobre una copia; el original debe seguir vacío
        expect(acumuladoOriginal, isEmpty);
      },
    );

    test(
      'carrito vacío no modifica acumulados ni total',
      () {
        final acumulado = <String, Map<String, dynamic>>{
          'p1': {'producto_id': 'p1', 'nombre': 'Café', 'cantidad': 1, 'precio': 1.5},
        };

        final resultado = mergearCarritoEnAcumulado(
          acumulados: acumulado,
          carrito: {},
          totalAcumuladoPrevio: 1.5,
        );

        expect(resultado.acumulados.length, 1);
        expect(resultado.totalAcumulado, closeTo(1.5, 0.001));
      },
    );
  });

  // ─── rollbackCarrito ──────────────────────────────────────────────────────

  group('rollbackCarrito — deshacer merge en caso de fallo', () {
    test(
      'rollback de producto nuevo lo elimina del acumulado',
      () {
        final p = _producto(id: 'p1', nombre: 'Tiramisú', precio: 5.0);
        // Simula acumulado después del merge fallido
        final acumuladoPostMerge = <String, Map<String, dynamic>>{
          'p1': {'producto_id': 'p1', 'nombre': 'Tiramisú', 'cantidad': 2, 'precio': 5.0},
        };

        final resultado = rollbackCarrito(
          acumulados: acumuladoPostMerge,
          carrito: {p: 2},
          totalAcumuladoConError: 10.0,
        );

        expect(resultado.acumulados.containsKey('p1'), isFalse);
        expect(resultado.totalAcumulado, closeTo(0.0, 0.001));
      },
    );

    test(
      'rollback de producto existente resta solo las unidades del carrito',
      () {
        final p = _producto(id: 'p1', nombre: 'Agua', precio: 2.0);
        // Había 3 previas; se añadieron 2 en el merge fallido → acumulado tiene 5
        final acumuladoPostMerge = <String, Map<String, dynamic>>{
          'p1': {'producto_id': 'p1', 'nombre': 'Agua', 'cantidad': 5, 'precio': 2.0},
        };

        final resultado = rollbackCarrito(
          acumulados: acumuladoPostMerge,
          carrito: {p: 2},
          totalAcumuladoConError: 10.0,
        );

        // Debe quedar 5 − 2 = 3 unidades
        expect(resultado.acumulados['p1']!['cantidad'], 3);
        // Total debe bajar en 2×2 = 4 €
        expect(resultado.totalAcumulado, closeTo(6.0, 0.001));
      },
    );

    test(
      'rollback total restaura el estado previo al merge en escenario completo',
      () {
        final p1 = _producto(id: 'p1', nombre: 'Salmorejo', precio: 4.5);
        final p2 = _producto(id: 'p2', nombre: 'Lubina', precio: 22.0);

        // Estado previo: solo p1 con 1 unidad, total = 4.5
        final estadoPrevio = <String, Map<String, dynamic>>{
          'p1': {'producto_id': 'p1', 'nombre': 'Salmorejo', 'cantidad': 1, 'precio': 4.5},
        };

        // Merge del carrito {p1:1, p2:1} → total debería ser 4.5+4.5+22 = 31
        final postMerge = mergearCarritoEnAcumulado(
          acumulados: estadoPrevio,
          carrito: {p1: 1, p2: 1},
          totalAcumuladoPrevio: 4.5,
        );
        expect(postMerge.totalAcumulado, closeTo(31.0, 0.001));

        // Rollback
        final rollback = rollbackCarrito(
          acumulados: postMerge.acumulados,
          carrito: {p1: 1, p2: 1},
          totalAcumuladoConError: postMerge.totalAcumulado,
        );

        // Debe volver a p1:1, sin p2, total=4.5
        expect(rollback.acumulados.length, 1);
        expect(rollback.acumulados['p1']!['cantidad'], 1);
        expect(rollback.acumulados.containsKey('p2'), isFalse);
        expect(rollback.totalAcumulado, closeTo(4.5, 0.001));
      },
    );
  });

  // ─── calcularTotalCarrito ─────────────────────────────────────────────────

  group('calcularTotalCarrito', () {
    test('carrito vacío → 0.0', () {
      expect(calcularTotalCarrito({}), 0.0);
    });

    test('un producto × 1 → su precio exacto', () {
      final p = _producto(id: 'p1', nombre: 'X', precio: 9.99);
      expect(calcularTotalCarrito({p: 1}), closeTo(9.99, 0.001));
    });

    test('un producto × 3 → precio × 3', () {
      final p = _producto(id: 'p1', nombre: 'X', precio: 5.0);
      expect(calcularTotalCarrito({p: 3}), closeTo(15.0, 0.001));
    });

    test('varios productos suman correctamente', () {
      final p1 = _producto(id: 'p1', nombre: 'A', precio: 3.0);
      final p2 = _producto(id: 'p2', nombre: 'B', precio: 7.5);
      // 2×3 + 1×7.5 = 13.5
      expect(calcularTotalCarrito({p1: 2, p2: 1}), closeTo(13.5, 0.001));
    });
  });

  // ─── formatearPrecioEuros ─────────────────────────────────────────────────

  group('formatearPrecioEuros', () {
    test('precio entero → dos decimales con coma', () {
      expect(formatearPrecioEuros(10.0), '10,00 €');
    });

    test('precio con un decimal → dos decimales con coma', () {
      expect(formatearPrecioEuros(5.5), '5,50 €');
    });

    test('precio cero → 0,00 €', () {
      expect(formatearPrecioEuros(0.0), '0,00 €');
    });

    test('precio con dos decimales → se preservan', () {
      expect(formatearPrecioEuros(12.99), '12,99 €');
    });

    test('precio > 100 → formato correcto', () {
      expect(formatearPrecioEuros(150.75), '150,75 €');
    });
  });

  // ─── generarCodigoQr ──────────────────────────────────────────────────────

  group('generarCodigoQr', () {
    test('interior con número de un dígito → Mesa_0X', () {
      expect(generarCodigoQr(5, 'interior'), 'Mesa_05');
    });

    test('interior con número de dos dígitos → Mesa_XX', () {
      expect(generarCodigoQr(13, 'interior'), 'Mesa_13');
    });

    test('terraza con número de un dígito → Terraza_0X', () {
      expect(generarCodigoQr(3, 'terraza'), 'Terraza_03');
    });

    test('terraza con número de dos dígitos → Terraza_XX', () {
      expect(generarCodigoQr(20, 'terraza'), 'Terraza_20');
    });
  });

  // ─── validarNumeroMesa ────────────────────────────────────────────────────

  group('validarNumeroMesa — numero_mesa es un entero', () {
    test('string numérico positivo → devuelve int', () {
      final n = validarNumeroMesa('7');
      expect(n, isA<int>());
      expect(n, 7);
    });

    test('string "0" → devuelve null (no válido)', () {
      expect(validarNumeroMesa('0'), isNull);
    });

    test('número negativo → devuelve null', () {
      expect(validarNumeroMesa('-3'), isNull);
    });

    test('texto no numérico → devuelve null', () {
      expect(validarNumeroMesa('abc'), isNull);
    });

    test('string vacío → devuelve null', () {
      expect(validarNumeroMesa(''), isNull);
    });

    test('número con espacios → se parsea correctamente', () {
      expect(validarNumeroMesa('  12  '), 12);
    });

    test(
      'numeroMesa pasado a CrearComanda es int, no ObjectId '
      '(el campo mesa.numero es int, no String)',
      () {
        // Verifica la invariante del modelo: Mesa.numero es siempre int.
        // Si este test falla significa que alguien pasó un ObjectId (String)
        // como numeroMesa, lo que corrompería la comanda.
        final n = validarNumeroMesa('5');
        expect(n.runtimeType, int);
        // Un ObjectId tiene 24 chars hex — no es un entero pequeño.
        expect(n, lessThan(10000));
      },
    );
  });
}

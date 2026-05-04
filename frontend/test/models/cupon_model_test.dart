import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/models/cupon_model.dart';

void main() {
  group('Cupon.fromJson', () {
    test('parsea campos básicos', () {
      final json = {
        'id': 'c1',
        'codigo': 'VERANO',
        'tipo': 'porcentaje',
        'valor': 15,
        'descripcion': 'Descuento de verano',
        'activo': true,
        'usos_maximos': 100,
        'usos_actuales': 4,
        'fecha_inicio': '2026-06-01',
        'fecha_fin': '2026-08-31',
      };

      final c = Cupon.fromJson(json);

      expect(c.id, 'c1');
      expect(c.codigo, 'VERANO');
      expect(c.tipo, 'porcentaje');
      expect(c.valor, 15.0);
      expect(c.usosMaximos, 100);
      expect(c.usosActuales, 4);
      expect(c.activo, isTrue);
      expect(c.ilimitado, isFalse);
    });

    test('campos por defecto cuando faltan', () {
      final c = Cupon.fromJson({});
      expect(c.id, '');
      expect(c.tipo, 'porcentaje');
      expect(c.valor, 0.0);
      expect(c.activo, isTrue); // != false → true
      expect(c.ilimitado, isTrue);
    });

    test('activo es false sólo cuando se envía explícitamente false', () {
      expect(Cupon.fromJson({'activo': false}).activo, isFalse);
      expect(Cupon.fromJson({'activo': true}).activo, isTrue);
      expect(Cupon.fromJson({}).activo, isTrue);
    });

    test('valor entero se convierte a double', () {
      final c = Cupon.fromJson({'valor': 10});
      expect(c.valor, isA<double>());
      expect(c.valor, 10.0);
    });
  });

  group('Cupon.etiquetaValor', () {
    test('porcentaje muestra %', () {
      final c = Cupon.fromJson({'tipo': 'porcentaje', 'valor': 20});
      expect(c.etiquetaValor, '20%');
    });

    test('fijo muestra euros con 2 decimales', () {
      final c = Cupon.fromJson({'tipo': 'fijo', 'valor': 5.5});
      expect(c.etiquetaValor, '€5.50');
    });
  });
}

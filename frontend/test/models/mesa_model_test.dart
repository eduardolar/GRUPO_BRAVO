import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/models/mesa_model.dart';

void main() {
  group('Mesa.fromMap', () {
    test('parsea campos básicos', () {
      final m = Mesa.fromMap({
        'id': 'm1',
        'numero': 5,
        'capacidad': 4,
        'ubicacion': 'terraza',
        'disponible': true,
        'codigo_qr': 'QR-5',
      });
      expect(m.id, 'm1');
      expect(m.numero, 5);
      expect(m.capacidad, 4);
      expect(m.ubicacion, 'terraza');
      expect(m.disponible, isTrue);
      expect(m.codigoQr, 'QR-5');
    });

    test('codigoQr cae en valor por defecto cuando falta', () {
      final m = Mesa.fromMap({'numero': 7});
      expect(m.codigoQr, 'mesa_7');
    });

    test('camelCase y snake_case ambos aceptados para codigoQr', () {
      final c1 = Mesa.fromMap({'numero': 1, 'codigoQr': 'A'});
      final c2 = Mesa.fromMap({'numero': 1, 'codigo_qr': 'B'});
      expect(c1.codigoQr, 'A');
      expect(c2.codigoQr, 'B');
    });
  });

  group('Mesa.copyWith', () {
    test('cambia disponible sin tocar el resto', () {
      final m = Mesa(id: 'm', numero: 1, capacidad: 2, ubicacion: 'interior');
      final actualizado = m.copyWith(disponible: false);
      expect(actualizado.disponible, isFalse);
      expect(actualizado.id, 'm');
      expect(actualizado.numero, 1);
    });
  });

  group('Mesa.toMap', () {
    test('serializa todos los campos', () {
      final m = Mesa(
        id: 'm',
        numero: 1,
        capacidad: 2,
        ubicacion: 'interior',
        codigoQr: 'QR-1',
      );
      final map = m.toMap();
      expect(map['id'], 'm');
      expect(map['numero'], 1);
      expect(map['codigoQr'], 'QR-1');
    });
  });
}

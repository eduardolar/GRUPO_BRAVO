import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/models/restaurante_model.dart';

void main() {
  group('Restaurante.fromJson', () {
    test('parsea campos básicos', () {
      final r = Restaurante.fromJson({
        'id': 'r1',
        'nombre': 'Bravo Centro',
        'direccion': 'Calle 1',
        'codigo': 'BC',
        'horario_apertura': '09:00',
        'horario_cierre': '23:00',
      });
      expect(r.id, 'r1');
      expect(r.nombre, 'Bravo Centro');
      expect(r.codigo, 'BC');
      expect(r.horarioApertura, '09:00');
      expect(r.horarioCierre, '23:00');
      expect(r.activo, isTrue);
    });

    test('camelCase también se acepta', () {
      final r = Restaurante.fromJson({
        'id': 'r2',
        'nombre': '',
        'direccion': '',
        'codigo': '',
        'horarioApertura': '08:00',
        'horarioCierre': '22:00',
      });
      expect(r.horarioApertura, '08:00');
      expect(r.horarioCierre, '22:00');
    });

    test('activo == false se respeta', () {
      final r = Restaurante.fromJson({
        'id': 'r3',
        'nombre': '',
        'direccion': '',
        'codigo': '',
        'activo': false,
      });
      expect(r.activo, isFalse);
    });
  });

  group('Restaurante.estaAbierto()', () {
    Restaurante con(String? open, String? close) => Restaurante(
      id: 'r',
      nombre: '',
      direccion: '',
      codigo: '',
      horarioApertura: open,
      horarioCierre: close,
    );

    test('sin horario configurado siempre está abierto', () {
      expect(con(null, null).estaAbierto(), isTrue);
    });

    // Nota: estaAbierto() depende de DateTime.now(), no podemos
    // controlarlo sin inyección. Sólo validamos que retorne bool.
    test('con horario válido devuelve un bool sin lanzar', () {
      expect(con('00:00', '23:59').estaAbierto(), isA<bool>());
      expect(
        con('22:00', '02:00').estaAbierto(),
        isA<bool>(),
      ); // cruza medianoche
    });
  });
}

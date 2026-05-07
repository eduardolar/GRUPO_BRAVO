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

  group('Restaurante.suspendidoAt y estaSuspendida', () {
    test('suspendido_at null → estaSuspendida false', () {
      final r = Restaurante.fromJson({
        'id': 'r4',
        'nombre': '',
        'direccion': '',
        'codigo': '',
      });
      expect(r.suspendidoAt, isNull);
      expect(r.estaSuspendida, isFalse);
    });

    test('suspendido_at con fecha → estaSuspendida true', () {
      final r = Restaurante.fromJson({
        'id': 'r5',
        'nombre': '',
        'direccion': '',
        'codigo': '',
        'suspendido_at': '2026-05-07T10:00:00Z',
      });
      expect(r.suspendidoAt, '2026-05-07T10:00:00Z');
      expect(r.estaSuspendida, isTrue);
    });
  });

  group('Restaurante — campos F8', () {
    test('fromJson parsea logo_url y logo_public_id', () {
      final r = Restaurante.fromJson({
        'id': 'r10',
        'nombre': '',
        'direccion': '',
        'codigo': '',
        'logo_url': 'https://cdn.example.com/logo.jpg',
        'logo_public_id': 'bravo/logo_abc',
      });
      expect(r.logoUrl, 'https://cdn.example.com/logo.jpg');
      expect(r.logoPublicId, 'bravo/logo_abc');
    });

    test('fromJson parsea metodos_pago como lista', () {
      final r = Restaurante.fromJson({
        'id': 'r11',
        'nombre': '',
        'direccion': '',
        'codigo': '',
        'metodos_pago': ['efectivo', 'tarjeta', 'stripe'],
      });
      expect(r.metodosPago, containsAll(['efectivo', 'tarjeta', 'stripe']));
    });

    test('fromJson metodos_pago ausente → lista vacía', () {
      final r = Restaurante.fromJson(
        {'id': 'r12', 'nombre': '', 'direccion': '', 'codigo': ''},
      );
      expect(r.metodosPago, isEmpty);
    });

    test('fromJson parsea horarios_dia con HorarioDia', () {
      final r = Restaurante.fromJson({
        'id': 'r13',
        'nombre': '',
        'direccion': '',
        'codigo': '',
        'horarios_dia': {
          'lunes': {'apertura': '10:00', 'cierre': '22:00', 'abierto': true},
          'domingo': {'apertura': '11:00', 'cierre': '20:00', 'abierto': false},
        },
      });
      expect(r.horariosDia, isNotNull);
      expect(r.horariosDia!['lunes']!.apertura, '10:00');
      expect(r.horariosDia!['lunes']!.abierto, isTrue);
      expect(r.horariosDia!['domingo']!.abierto, isFalse);
    });

    test('fromJson horarios_dia ausente → null', () {
      final r = Restaurante.fromJson(
        {'id': 'r14', 'nombre': '', 'direccion': '', 'codigo': ''},
      );
      expect(r.horariosDia, isNull);
    });

    test('fromJson parsea datos fiscales', () {
      final r = Restaurante.fromJson({
        'id': 'r15',
        'nombre': '',
        'direccion': '',
        'codigo': '',
        'cif': 'B12345678',
        'razon_social': 'Grupo Bravo SL',
        'codigo_postal': '28001',
        'ciudad': 'Madrid',
        'provincia': 'Madrid',
        'pais': 'España',
      });
      expect(r.cif, 'B12345678');
      expect(r.razonSocial, 'Grupo Bravo SL');
      expect(r.codigoPostal, '28001');
      expect(r.ciudad, 'Madrid');
      expect(r.pais, 'España');
    });
  });

  group('HorarioDia', () {
    test('fromJson parsea todos los campos', () {
      final h = HorarioDia.fromJson(
        {'apertura': '08:00', 'cierre': '23:00', 'abierto': true},
      );
      expect(h.apertura, '08:00');
      expect(h.cierre, '23:00');
      expect(h.abierto, isTrue);
    });

    test('fromJson usa valores por defecto cuando faltan campos', () {
      final h = HorarioDia.fromJson({});
      expect(h.apertura, '09:00');
      expect(h.cierre, '23:00');
      expect(h.abierto, isFalse);
    });

    test('toJson serializa correctamente', () {
      const h = HorarioDia(apertura: '10:00', cierre: '22:00', abierto: true);
      final j = h.toJson();
      expect(j['apertura'], '10:00');
      expect(j['cierre'], '22:00');
      expect(j['abierto'], isTrue);
    });

    test('copyWith cambia solo el campo indicado', () {
      const original = HorarioDia(
        apertura: '09:00',
        cierre: '23:00',
        abierto: false,
      );
      final modificado = original.copyWith(abierto: true);
      expect(modificado.abierto, isTrue);
      expect(modificado.apertura, '09:00'); // sin cambiar
      expect(modificado.cierre, '23:00');   // sin cambiar
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

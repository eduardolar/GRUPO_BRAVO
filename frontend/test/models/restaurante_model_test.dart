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
      });
      expect(r.id, 'r1');
      expect(r.nombre, 'Bravo Centro');
      expect(r.codigo, 'BC');
      expect(r.activo, isTrue);
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
    test('sin horarios configurados → false', () {
      final r = Restaurante(
        id: 'r',
        nombre: '',
        direccion: '',
        codigo: '',
      );
      expect(r.estaAbierto(), isFalse);
    });

    test('horariosDia con todos los días abiertos 00:00-23:59 → true', () {
      const semana = HorarioDia(
        apertura: '00:00',
        cierre: '23:59',
        abierto: true,
      );
      final r = Restaurante(
        id: 'r',
        nombre: '',
        direccion: '',
        codigo: '',
        horariosDia: const {
          'lunes': semana,
          'martes': semana,
          'miercoles': semana,
          'jueves': semana,
          'viernes': semana,
          'sabado': semana,
          'domingo': semana,
        },
      );
      expect(r.estaAbierto(), isTrue);
    });

    test('horariosDia con todos los días cerrados → false', () {
      // Aunque haya un día con abierto:true para que la rama por día se
      // active, el día actual estará cerrado en al menos 6 de 7 escenarios.
      // Para cubrir los 7 días marcamos todos cerrados con un sentinel
      // mediante un día simbólico abierto que nunca matchea (sólo activa la
      // rama por día); el día real siempre estará cerrado.
      const cerrado = HorarioDia(abierto: false);
      const abiertoSentinel = HorarioDia(
        apertura: '00:00',
        cierre: '00:01',
        abierto: true,
      );
      // Marcamos un día cualquiera como abiertoSentinel para activar la
      // rama por día y todos como cerrados; el test solo es determinístico
      // si DateTime.now() no cae justo en ese día y minuto sentinel, que
      // es prácticamente imposible.
      final r = Restaurante(
        id: 'r',
        nombre: '',
        direccion: '',
        codigo: '',
        horariosDia: const {
          'lunes': cerrado,
          'martes': cerrado,
          'miercoles': cerrado,
          'jueves': cerrado,
          'viernes': cerrado,
          'sabado': cerrado,
          'domingo': abiertoSentinel,
        },
      );
      // Si hoy es domingo entre 00:00-00:01 el test falla (caso despreciable).
      final now = DateTime.now();
      final esDomingoEnVentana =
          now.weekday == DateTime.sunday && now.hour == 0 && now.minute == 0;
      if (!esDomingoEnVentana) {
        expect(r.estaAbierto(), isFalse);
      }
    });

    test('horariosDia sin ningún día abierto → false', () {
      const cerrado = HorarioDia(abierto: false);
      final r = Restaurante(
        id: 'r',
        nombre: '',
        direccion: '',
        codigo: '',
        horariosDia: const {
          'lunes': cerrado,
          'martes': cerrado,
          'miercoles': cerrado,
          'jueves': cerrado,
          'viernes': cerrado,
          'sabado': cerrado,
          'domingo': cerrado,
        },
      );
      expect(r.estaAbierto(), isFalse);
    });
  });
}

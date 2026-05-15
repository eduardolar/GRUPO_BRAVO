import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/models/usuario_model.dart';

void main() {
  group('Usuario — campos activo y suspendidoAt', () {
    test('fromJson activo=true por defecto cuando no viene el campo', () {
      final json = {
        'id': 'u1',
        'nombre': 'Luis',
        'correo': 'luis@test.com',
        'rol': 'camarero',
      };
      final u = Usuario.fromJson(json);
      expect(u.activo, isTrue);
      expect(u.suspendidoAt, isNull);
    });

    test('fromJson activo=false cuando el backend lo envía', () {
      final json = {
        'id': 'u2',
        'nombre': 'Marta',
        'correo': 'marta@test.com',
        'rol': 'cocinero',
        'activo': false,
        'suspendido_at': '2026-04-01T10:00:00',
      };
      final u = Usuario.fromJson(json);
      expect(u.activo, isFalse);
      expect(u.suspendidoAt, '2026-04-01T10:00:00');
    });

    test('copyWith activo actualiza solo el campo activo', () {
      final original = Usuario(
        id: 'u3',
        nombre: 'Pedro',
        email: 'pedro@test.com',
        contrasena: '',
        telefono: '',
        direccion: '',
        activo: true,
      );
      final suspendido = original.copyWith(activo: false);
      expect(suspendido.activo, isFalse);
      // El resto no cambia
      expect(suspendido.nombre, 'Pedro');
      expect(suspendido.id, 'u3');
    });

    test('toJson incluye activo y suspendido_at cuando no es null', () {
      final u = Usuario(
        id: 'u4',
        nombre: 'Eva',
        email: 'eva@test.com',
        contrasena: '',
        telefono: '',
        direccion: '',
        activo: false,
        suspendidoAt: '2026-05-01T08:00:00',
      );
      final json = u.toJson();
      expect(json['activo'], isFalse);
      expect(json['suspendido_at'], '2026-05-01T08:00:00');
    });

    test('toJson no incluye suspendido_at cuando es null', () {
      final u = Usuario(
        id: 'u5',
        nombre: 'Sofía',
        email: 'sofia@test.com',
        contrasena: '',
        telefono: '',
        direccion: '',
      );
      final json = u.toJson();
      expect(json.containsKey('suspendido_at'), isFalse);
    });
  });
}

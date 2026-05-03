import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/models/usuario_model.dart';

void main() {
  group('Usuario.fromJson', () {
    test('parsea campos básicos correctamente', () {
      final json = {
        'id': 'abc123',
        'nombre': 'Ana García',
        'correo': 'ana@test.com',
        'telefono': '600000000',
        'direccion': 'Calle Mayor 1',
        'rol': 'cliente',
        'totp_enabled': false,
      };

      final usuario = Usuario.fromJson(json);

      expect(usuario.id, 'abc123');
      expect(usuario.nombre, 'Ana García');
      expect(usuario.email, 'ana@test.com');
      expect(usuario.telefono, '600000000');
      expect(usuario.rol, RolUsuario.cliente);
      expect(usuario.totpEnabled, false);
    });

    test('acepta campo _id como alternativa a id', () {
      final json = {
        '_id': 'xyz789',
        'nombre': 'Carlos',
        'correo': 'carlos@test.com',
        'telefono': '',
        'direccion': '',
      };

      final usuario = Usuario.fromJson(json);
      expect(usuario.id, 'xyz789');
    });

    test('acepta campo email como alternativa a correo', () {
      final json = {
        'id': 'u1',
        'nombre': 'Luis',
        'email': 'luis@test.com',
        'telefono': '',
        'direccion': '',
      };

      final usuario = Usuario.fromJson(json);
      expect(usuario.email, 'luis@test.com');
    });

    test('parsea latitud y longitud numéricas', () {
      final json = {
        'id': 'u1',
        'nombre': 'María',
        'correo': 'maria@test.com',
        'telefono': '',
        'direccion': '',
        'latitud': 40.4168,
        'longitud': -3.7038,
      };

      final usuario = Usuario.fromJson(json);
      expect(usuario.latitud, closeTo(40.4168, 0.0001));
      expect(usuario.longitud, closeTo(-3.7038, 0.0001));
    });

    test('latitud y longitud son null si no vienen', () {
      final json = {
        'id': 'u1',
        'nombre': 'Pedro',
        'correo': 'pedro@test.com',
        'telefono': '',
        'direccion': '',
      };

      final usuario = Usuario.fromJson(json);
      expect(usuario.latitud, isNull);
      expect(usuario.longitud, isNull);
    });

    test('restaurante_id se parsea correctamente', () {
      final json = {
        'id': 'u1',
        'nombre': 'Test',
        'correo': 'test@test.com',
        'telefono': '',
        'direccion': '',
        'restaurante_id': 'rest001',
      };

      final usuario = Usuario.fromJson(json);
      expect(usuario.restauranteId, 'rest001');
    });
  });

  group('Usuario rol parsing', () {
    Usuario parseRol(String rol) => Usuario.fromJson({
          'id': 'u1',
          'nombre': 'Test',
          'correo': 'test@test.com',
          'telefono': '',
          'direccion': '',
          'rol': rol,
        });

    test('superadmin → superadministrador', () {
      expect(parseRol('superadmin').rol, RolUsuario.superadministrador);
    });

    test('superadministrador → superadministrador', () {
      expect(parseRol('superadministrador').rol, RolUsuario.superadministrador);
    });

    test('cocinero → cocinero', () {
      expect(parseRol('cocinero').rol, RolUsuario.cocinero);
    });

    test('camarero → trabajador', () {
      expect(parseRol('camarero').rol, RolUsuario.trabajador);
    });

    test('mesero → trabajador', () {
      expect(parseRol('mesero').rol, RolUsuario.trabajador);
    });

    test('admin → administrador', () {
      expect(parseRol('admin').rol, RolUsuario.administrador);
    });

    test('administrador → administrador', () {
      expect(parseRol('administrador').rol, RolUsuario.administrador);
    });

    test('desconocido → cliente por defecto', () {
      expect(parseRol('fantasma').rol, RolUsuario.cliente);
    });

    test('null → cliente por defecto', () {
      final json = {
        'id': 'u1',
        'nombre': 'Test',
        'correo': 'test@test.com',
        'telefono': '',
        'direccion': '',
      };
      expect(Usuario.fromJson(json).rol, RolUsuario.cliente);
    });
  });

  group('Usuario.toJson', () {
    test('serializa campos requeridos', () {
      final usuario = Usuario(
        id: 'u1',
        nombre: 'Ana',
        email: 'ana@test.com',
        contrasena: '',
        telefono: '600',
        direccion: 'Calle 1',
        rol: RolUsuario.administrador,
      );

      final json = usuario.toJson();

      expect(json['id'], 'u1');
      expect(json['nombre'], 'Ana');
      expect(json['email'], 'ana@test.com');
      expect(json['rol'], 'administrador');
      expect(json['totp_enabled'], false);
    });

    test('incluye restaurante_id cuando no es null', () {
      final usuario = Usuario(
        id: 'u1',
        nombre: 'Test',
        email: 'test@test.com',
        contrasena: '',
        telefono: '',
        direccion: '',
        restauranteId: 'rest1',
      );

      expect(usuario.toJson()['restaurante_id'], 'rest1');
    });
  });

  group('Usuario.copyWith', () {
    final original = Usuario(
      id: 'u1',
      nombre: 'Original',
      email: 'orig@test.com',
      contrasena: '',
      telefono: '',
      direccion: '',
    );

    test('mantiene valores no modificados', () {
      final copia = original.copyWith(nombre: 'Modificado');
      expect(copia.id, original.id);
      expect(copia.email, original.email);
      expect(copia.nombre, 'Modificado');
    });

    test('es inmutable (original no cambia)', () {
      original.copyWith(nombre: 'Otro');
      expect(original.nombre, 'Original');
    });
  });
}

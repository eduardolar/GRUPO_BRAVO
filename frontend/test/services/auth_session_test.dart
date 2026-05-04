import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/services/auth_session.dart';

void main() {
  group('AuthSession', () {
    setUp(() {
      AuthSession.limpiar(); // estado limpio en cada test
    });

    test('estado inicial: no autenticado', () {
      expect(AuthSession.token, isNull);
      expect(AuthSession.userId, isNull);
      expect(AuthSession.autenticado, isFalse);
    });

    test('guardar persiste los datos', () {
      AuthSession.guardar(
        token: 'jwt-abc',
        userId: 'u1',
        correo: 'a@b.c',
        rol: 'cliente',
      );
      expect(AuthSession.token, 'jwt-abc');
      expect(AuthSession.userId, 'u1');
      expect(AuthSession.correo, 'a@b.c');
      expect(AuthSession.rol, 'cliente');
      expect(AuthSession.autenticado, isTrue);
    });

    test('guardar con token vacío deja autenticado=false', () {
      AuthSession.guardar(token: '', userId: 'u1');
      expect(AuthSession.token, isNull);
      expect(AuthSession.autenticado, isFalse);
    });

    test('guardar con token null deja autenticado=false', () {
      AuthSession.guardar(token: null, userId: 'u1');
      expect(AuthSession.autenticado, isFalse);
    });

    test('limpiar resetea todos los campos', () {
      AuthSession.guardar(token: 't', userId: 'u', correo: 'c', rol: 'r');
      AuthSession.limpiar();
      expect(AuthSession.token, isNull);
      expect(AuthSession.userId, isNull);
      expect(AuthSession.correo, isNull);
      expect(AuthSession.rol, isNull);
      expect(AuthSession.autenticado, isFalse);
    });
  });

  group('AuthSession.headers', () {
    setUp(AuthSession.limpiar);

    test('sin sesión: sólo Content-Type', () {
      final h = AuthSession.headers();
      expect(h['Authorization'], isNull);
      expect(h['Content-Type'], 'application/json');
    });

    test('sin sesión + json:false: sin Content-Type', () {
      final h = AuthSession.headers(json: false);
      expect(h, isEmpty);
    });

    test('con sesión añade Authorization Bearer', () {
      AuthSession.guardar(token: 'jwt-token-xyz');
      final h = AuthSession.headers();
      expect(h['Authorization'], 'Bearer jwt-token-xyz');
      expect(h['Content-Type'], 'application/json');
    });

    test('extra se mezcla con base', () {
      AuthSession.guardar(token: 't');
      final h = AuthSession.headers(extra: {'X-Actor': 'a@b.c'});
      expect(h['Authorization'], 'Bearer t');
      expect(h['X-Actor'], 'a@b.c');
      expect(h['Content-Type'], 'application/json');
    });

    test('extra puede sobrescribir Content-Type', () {
      AuthSession.guardar(token: 't');
      final h = AuthSession.headers(extra: {'Content-Type': 'text/plain'});
      expect(h['Content-Type'], 'text/plain');
    });
  });
}

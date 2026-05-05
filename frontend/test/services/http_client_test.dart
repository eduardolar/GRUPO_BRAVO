import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/services/http_client.dart';
import 'package:http/http.dart' as http;

void main() {
  group('toApiException — mapeo de códigos HTTP', () {
    test('400 con detail string', () {
      final e = toApiException(400, {'detail': 'Faltan campos'});
      expect(e.statusCode, 400);
      expect(e.message, 'Faltan campos');
      expect(e.isClientError, isTrue);
    });

    test('400 sin detail usa fallback en español', () {
      final e = toApiException(400, {});
      expect(e.message, 'Solicitud incorrecta');
    });

    test('401 siempre da mensaje de sesión expirada (no leak de detail)', () {
      final e = toApiException(401, {'detail': 'JWT expired'});
      expect(e.message, contains('Sesión expirada'));
      expect(e.isUnauthorized, isTrue);
    });

    test('403 siempre da mensaje de permiso (no leak de detail)', () {
      final e = toApiException(403, {'detail': 'Insufficient role'});
      expect(e.message, contains('No tienes permiso'));
    });

    test('404 con detail propaga el detalle', () {
      final e = toApiException(404, {'detail': 'Pedido no encontrado'});
      expect(e.message, 'Pedido no encontrado');
      expect(e.isNotFound, isTrue);
    });

    test('409 da fallback si no hay detail', () {
      final e = toApiException(409, {});
      expect(e.message, contains('Ya existe'));
    });

    test('422 da fallback genérico de validación', () {
      expect(toApiException(422, {}).message, contains('no son válidos'));
    });

    test('429 mensaje fijo de demasiadas peticiones', () {
      expect(
        toApiException(429, {'detail': 'rate limited'}).message,
        contains('Demasiadas solicitudes'),
      );
    });

    test('500 con detail propaga el detalle', () {
      final e = toApiException(500, {'detail': 'DB caída'});
      expect(e.statusCode, 500);
      expect(e.isServerError, isTrue);
      expect(e.message, 'DB caída');
    });

    test('500 sin detail muestra código', () {
      final e = toApiException(500, {});
      expect(e.message, contains('500'));
    });

    test('extrae detail anidado en map', () {
      final e = toApiException(400, {
        'detail': {'detail': 'Error profundo'},
      });
      expect(e.message, 'Error profundo');
    });

    test('extrae detail desde lista', () {
      final e = toApiException(422, {
        'detail': ['campo1: requerido', 'campo2: inválido'],
      });
      expect(e.message, contains('campo1: requerido'));
      expect(e.message, contains('campo2: inválido'));
    });

    test('cae en message cuando no hay detail', () {
      final e = toApiException(400, {'message': 'algo'});
      expect(e.message, 'algo');
    });

    test('cae en error cuando no hay detail ni message', () {
      final e = toApiException(400, {'error': 'oops'});
      expect(e.message, 'oops');
    });

    test('código 418 desconocido cae en fallback', () {
      final e = toApiException(418, {});
      expect(e.message, contains('418'));
    });
  });

  group('decodeBody', () {
    test('JSON válido devuelve el map', () {
      final r = http.Response('{"foo": 1}', 200);
      expect(decodeBody(r), {'foo': 1});
    });

    test('cuerpo vacío devuelve map vacío', () {
      final r = http.Response('', 200);
      expect(decodeBody(r), isEmpty);
    });

    test('respuesta no JSON cae en {detail: <texto>}', () {
      final r = http.Response('<html>error</html>', 500);
      expect(decodeBody(r)['detail'], '<html>error</html>');
    });

    test('JSON que es lista lo envuelve en {data: ...}', () {
      final r = http.Response('[1, 2, 3]', 200);
      expect(decodeBody(r)['data'], [1, 2, 3]);
    });
  });

  group('ApiException', () {
    test('toString devuelve el mensaje', () {
      const e = ApiException(404, 'No encontrado');
      expect(e.toString(), 'No encontrado');
    });

    test('statusCode 0 representa fallo de red', () {
      const e = ApiException(0, 'Sin conexión');
      expect(e.isClientError, isFalse);
      expect(e.isServerError, isFalse);
    });
  });
}

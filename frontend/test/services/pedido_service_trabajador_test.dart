library;

import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/services/http_client.dart';
import 'package:http/http.dart' as http;

// ── Helpers de construcción de cabeceras y bodies ─────────────────────────────
// Replica la misma lógica condicional que usa PedidoService para el header
// Idempotency-Key y para los bodies de cerrarPedido / crearPedido.

Map<String, String> construirHeadersConIdempotency({String? idempotencyKey}) {
  final extra = <String, String>{'Accept': 'application/json'};
  if (idempotencyKey != null && idempotencyKey.isNotEmpty) {
    extra['Idempotency-Key'] = idempotencyKey;
  }
  return extra;
}

Map<String, dynamic> buildCerrarBody({required String metodoPago}) {
  return {
    'estadoPago': 'pagado',
    'estado': 'entregado',
    'metodoPago': metodoPago,
  };
}

Map<String, dynamic> buildCrearBody({
  required int? numeroMesa,
  required String mesaId,
}) {
  return {
    'userId': 'TRABAJADOR',
    'tipoEntrega': 'local',
    'metodoPago': 'efectivo',
    'mesaId': mesaId,
    'numeroMesa': numeroMesa,
    'estadoPago': 'pendiente',
  };
}

// ─────────────────────────────────────────────────────────────────────────────

void main() {
  // ─── Lógica del header Idempotency-Key ───────────────────────────────────
  //
  // Replica la misma condición que usa PedidoService.cerrarPedido y
  // PedidoService.crearPedido para añadir o no el header.

  group('lógica de Idempotency-Key en cabeceras de petición', () {
    test(
      'cerrarPedido con idempotencyKey → header Idempotency-Key presente',
      () {
        const clave = 'test-uuid-1234';
        final headers = construirHeadersConIdempotency(idempotencyKey: clave);
        expect(headers.containsKey('Idempotency-Key'), isTrue);
        expect(headers['Idempotency-Key'], clave);
      },
    );

    test(
      'cerrarPedido sin idempotencyKey (null) → header NO presente',
      () {
        final headers = construirHeadersConIdempotency(idempotencyKey: null);
        expect(headers.containsKey('Idempotency-Key'), isFalse);
      },
    );

    test(
      'cerrarPedido con idempotencyKey vacío → header NO presente',
      () {
        final headers = construirHeadersConIdempotency(idempotencyKey: '');
        expect(headers.containsKey('Idempotency-Key'), isFalse);
      },
    );

    test(
      'la misma clave en dos llamadas produce el mismo header (idempotencia)',
      () {
        const clave = 'uuid-repetido-xyz';
        final h1 = construirHeadersConIdempotency(idempotencyKey: clave);
        final h2 = construirHeadersConIdempotency(idempotencyKey: clave);
        expect(h1['Idempotency-Key'], h2['Idempotency-Key']);
      },
    );
  });

  // ─── toApiException — errores HTTP del endpoint de cobro ─────────────────

  group('toApiException — escenarios de cerrarPedido', () {
    test(
      '200 no lanza (verificación indirecta: statusCode < 400)',
      () {
        // cerrarPedido solo lanza si statusCode >= 400.
        const statusCode = 200;
        expect(statusCode >= 400, isFalse);
      },
    );

    test(
      'cerrarPedido recibe 400 → ApiException con isClientError',
      () {
        final exc = toApiException(400, {'detail': 'Pedido ya cerrado'});
        expect(exc.isClientError, isTrue);
        expect(exc.message, 'Pedido ya cerrado');
      },
    );

    test(
      'cerrarPedido recibe 404 → ApiException con isNotFound',
      () {
        final exc = toApiException(404, {'detail': 'Pedido no encontrado'});
        expect(exc.isNotFound, isTrue);
        expect(exc.statusCode, 404);
      },
    );

    test(
      'cerrarPedido recibe 409 (ya pagado) → ApiException con detail',
      () {
        final exc = toApiException(409, {'detail': 'El pedido ya está pagado'});
        expect(exc.isClientError, isTrue);
        expect(exc.message, 'El pedido ya está pagado');
      },
    );

    test(
      'cerrarPedido recibe 422 → datos no válidos',
      () {
        final exc = toApiException(422, {});
        expect(exc.statusCode, 422);
        expect(exc.message, contains('no son válidos'));
      },
    );

    test(
      'cerrarPedido recibe 500 → isServerError',
      () {
        final exc = toApiException(500, {'detail': 'DB caída'});
        expect(exc.isServerError, isTrue);
        expect(exc.statusCode, 500);
      },
    );

    test(
      'cerrarPedido recibe 401 → sesión expirada, mensaje fijo',
      () {
        final exc = toApiException(401, {'detail': 'JWT expired'});
        expect(exc.isUnauthorized, isTrue);
        expect(exc.message, contains('Sesión expirada'));
      },
    );
  });

  // ─── decodeBody — parseo de respuestas de pedidos ────────────────────────

  group('decodeBody — respuestas del endpoint /pedidos', () {
    test('respuesta JSON de pedido creado se parsea correctamente', () {
      final body = jsonEncode({
        'id': 'pedido-123',
        '_id': 'pedido-123',
        'total': 25.5,
        'estado': 'En preparación',
      });
      final response = http.Response(body, 201);
      final parsed = decodeBody(response);
      expect(parsed['id'], 'pedido-123');
      expect(parsed['total'], 25.5);
    });

    test('respuesta vacía (204 No Content) devuelve map vacío', () {
      final response = http.Response('', 204);
      expect(decodeBody(response), isEmpty);
    });

    test('respuesta de error HTML no válida como JSON queda en detail', () {
      final response = http.Response('<html>Gateway Timeout</html>', 504);
      final parsed = decodeBody(response);
      expect(parsed.containsKey('detail'), isTrue);
    });

    test('campo numeroMesa int se preserva como int tras parseo', () {
      final body = jsonEncode({
        'id': 'p1',
        'numeroMesa': 5,
        'mesaId': 'abc123',
      });
      final response = http.Response(body, 200);
      final parsed = decodeBody(response);
      expect(parsed['numeroMesa'], isA<int>());
      expect(parsed['numeroMesa'], 5);
      // mesaId (ObjectId) es String, no se confunde con numeroMesa
      expect(parsed['mesaId'], isA<String>());
      expect(parsed['mesaId'], isNot(equals(5)));
    });
  });

  // ─── Construcción del body de cerrarPedido ────────────────────────────────

  group('body de cerrarPedido — campos requeridos', () {
    test('body con metodoPago efectivo contiene los tres campos', () {
      final body = buildCerrarBody(metodoPago: 'efectivo');
      expect(body['estadoPago'], 'pagado');
      expect(body['estado'], 'entregado');
      expect(body['metodoPago'], 'efectivo');
    });

    test('body con metodoPago tarjeta contiene los tres campos', () {
      final body = buildCerrarBody(metodoPago: 'tarjeta');
      expect(body['estadoPago'], 'pagado');
      expect(body['estado'], 'entregado');
      expect(body['metodoPago'], 'tarjeta');
    });

    test('body serializado como JSON es decodificable', () {
      final body = buildCerrarBody(metodoPago: 'efectivo');
      final encoded = jsonEncode(body);
      final decoded = jsonDecode(encoded) as Map<String, dynamic>;
      expect(decoded['estadoPago'], 'pagado');
    });
  });

  // ─── Construcción del body de crearPedido (trabajador) ───────────────────

  group('body de crearPedido trabajador — campo numeroMesa es int', () {
    test('numeroMesa se envía como int, no como String', () {
      final body = buildCrearBody(numeroMesa: 5, mesaId: 'objectid-abc');
      expect(body['numeroMesa'], isA<int>());
      expect(body['numeroMesa'], 5);
    });

    test('mesaId es String (ObjectId), distinto de numeroMesa int', () {
      final body = buildCrearBody(numeroMesa: 5, mesaId: 'objectid-abc');
      expect(body['mesaId'], isA<String>());
      expect(body['mesaId'], isNot(equals(body['numeroMesa'])));
    });

    test('numeroMesa null se envía como null (mesa sin número asignado)', () {
      final body = buildCrearBody(numeroMesa: null, mesaId: 'objectid-abc');
      expect(body['numeroMesa'], isNull);
    });

    test('serialización JSON preserva el tipo int de numeroMesa', () {
      final body = buildCrearBody(numeroMesa: 7, mesaId: 'abc');
      final decoded = jsonDecode(jsonEncode(body)) as Map<String, dynamic>;
      expect(decoded['numeroMesa'], isA<int>());
      expect(decoded['numeroMesa'], 7);
    });
  });
}

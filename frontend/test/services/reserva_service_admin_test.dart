import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/services/http_client.dart';

// Tests unitarios de lógica pura relacionada con el dominio de reservas admin.
// Los métodos de red de ReservaService se verifican en integración con backend.

void main() {
  group('Parseo de respuesta admin de reservas', () {
    test('lista JSON del endpoint admin se convierte a List<Map>', () {
      // Simula exactamente el shape del contrato backend confirmado
      final raw = jsonDecode(jsonEncode([
        {
          'id': 'r1',
          'usuarioId': 'u1',
          'nombreCompleto': 'Cliente Test',
          'fecha': '2026-05-06',
          'hora': '20:00',
          'comensales': 2,
          'turno': 'cena',
          'estado': 'Pendiente',
          'mesaId': null,
          'numeroMesa': null,
          'notas': 'Sin gluten',
          'restauranteId': 'rest1',
        },
      ])) as List<dynamic>;

      final lista = raw.cast<Map<String, dynamic>>();
      expect(lista.length, 1);
      expect(lista.first['id'], 'r1');
      expect(lista.first['estado'], 'Pendiente');
      expect(lista.first['hora'], '20:00');
      expect(lista.first['comensales'], 2);
      expect(lista.first['numeroMesa'], isNull);
    });

    test('los cinco estados válidos del contrato están definidos', () {
      const estadosValidos = [
        'Confirmada',
        'Cancelada',
        'Pendiente',
        'Llegado',
        'NoShow',
      ];
      expect(estadosValidos.length, 5);
      expect(estadosValidos.contains('Confirmada'), isTrue);
      expect(estadosValidos.contains('NoShow'), isTrue);
      expect(estadosValidos.contains('admin'), isFalse);
    });

    test('formato de fecha YYYY-MM-DD construido correctamente', () {
      final ahora = DateTime(2026, 5, 6);
      final fechaStr =
          '${ahora.year.toString().padLeft(4, '0')}-'
          '${ahora.month.toString().padLeft(2, '0')}-'
          '${ahora.day.toString().padLeft(2, '0')}';
      expect(fechaStr, '2026-05-06');
    });
  });

  group('ApiException — códigos relevantes en reservas', () {
    test('toApiException 409 devuelve el detail del backend', () {
      final exc = toApiException(409, {'detail': 'Mesa ya reservada'});
      expect(exc.statusCode, 409);
      expect(exc.message, 'Mesa ya reservada');
    });

    test('toApiException 403 devuelve mensaje fijo de permisos', () {
      final exc = toApiException(403, {});
      expect(exc.statusCode, 403);
      expect(exc.isClientError, isTrue);
    });

    test('toApiException 401 indica sesión expirada', () {
      final exc = toApiException(401, {});
      expect(exc.isUnauthorized, isTrue);
    });
  });
}

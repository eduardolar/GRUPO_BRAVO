import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/colors_style.dart';
import 'package:frontend/screens/cocinero/cocina_helpers.dart';

// ignore_for_file: avoid_relative_lib_imports

void main() {
  // ── labelEstado ──────────────────────────────────────────────────────────
  group('labelEstado', () {
    test('pendiente → Pendiente', () {
      expect(labelEstado('pendiente'), 'Pendiente');
    });
    test('preparando → En cocina', () {
      expect(labelEstado('preparando'), 'En cocina');
    });
    test('listo → Listo', () {
      expect(labelEstado('listo'), 'Listo');
    });
    test('desconocido → pasa tal cual', () {
      expect(labelEstado('otro'), 'otro');
    });
  });

  // ── colorEstado ──────────────────────────────────────────────────────────
  group('colorEstado', () {
    test('preparando → AppColors.button', () {
      expect(colorEstado('preparando'), AppColors.button);
    });
    test('listo → kCocinaAzul (AppColors.info)', () {
      expect(colorEstado('listo'), kCocinaAzul);
      expect(colorEstado('listo'), AppColors.info);
    });
    test('pendiente → kCocinaMarron (AppColors.surfacePending)', () {
      expect(colorEstado('pendiente'), kCocinaMarron);
      expect(colorEstado('pendiente'), AppColors.surfacePending);
    });
    test('desconocido → kCocinaMarron por defecto', () {
      expect(colorEstado('cualquiera'), kCocinaMarron);
    });
  });

  // ── formatoTiempo ────────────────────────────────────────────────────────
  group('formatoTiempo', () {
    test('minutos negativos → —', () {
      expect(formatoTiempo(-1), '—');
    });
    test('0 minutos → 0m', () {
      expect(formatoTiempo(0), '0m');
    });
    test('7 minutos → 7m', () {
      expect(formatoTiempo(7), '7m');
    });
    test('59 minutos → 59m', () {
      expect(formatoTiempo(59), '59m');
    });
    test('60 minutos → 1h 0m', () {
      expect(formatoTiempo(60), '1h 0m');
    });
    test('75 minutos → 1h 15m', () {
      expect(formatoTiempo(75), '1h 15m');
    });
    test('120 minutos → 2h 0m', () {
      expect(formatoTiempo(120), '2h 0m');
    });
  });

  // ── colorTiempo ──────────────────────────────────────────────────────────
  group('colorTiempo', () {
    test('minutos < 0 → textSecondary', () {
      expect(colorTiempo(-1), AppColors.textSecondary);
    });
    test('0 minutos → verde (< 5)', () {
      expect(colorTiempo(0), kCocinaVerde);
    });
    test('4 minutos → verde', () {
      expect(colorTiempo(4), kCocinaVerde);
    });
    test('5 minutos → ámbar', () {
      expect(colorTiempo(5), kCocinaAmbar);
    });
    test('9 minutos → ámbar', () {
      expect(colorTiempo(9), kCocinaAmbar);
    });
    test('10 minutos → naranja urgente', () {
      expect(colorTiempo(10), kCocinaFuego);
    });
    test('14 minutos → naranja urgente', () {
      expect(colorTiempo(14), kCocinaFuego);
    });
    test('15 minutos → error (rojo)', () {
      expect(colorTiempo(15), AppColors.error);
    });
    test('100 minutos → error', () {
      expect(colorTiempo(100), AppColors.error);
    });
  });

  // ── entregaInfo ──────────────────────────────────────────────────────────
  group('entregaInfo', () {
    test('local con mesa → Mesa 5', () {
      final r = entregaInfo('local', 5);
      expect(r.etiqueta, 'Mesa 5');
      expect(r.icono, Icons.table_restaurant_outlined);
    });
    test('local sin mesa → Mesa -', () {
      final r = entregaInfo('local', null);
      expect(r.etiqueta, 'Mesa -');
    });
    test('domicilio', () {
      final r = entregaInfo('domicilio', null);
      expect(r.etiqueta, 'A domicilio');
      expect(r.icono, Icons.delivery_dining_outlined);
    });
    test('recoger', () {
      final r = entregaInfo('recoger', null);
      expect(r.etiqueta, 'Para recoger');
      expect(r.icono, Icons.shopping_bag_outlined);
    });
    test('tipo desconocido → pasa tal cual', () {
      final r = entregaInfo('express', null);
      expect(r.etiqueta, 'express');
      expect(r.icono, Icons.receipt_long_outlined);
    });
  });

  // ── minutosDesde ─────────────────────────────────────────────────────────
  group('minutosDesde', () {
    test('fecha inválida → -1', () {
      expect(minutosDesde('no-es-fecha'), -1);
    });
    test('fecha futura → puede dar 0 o negativo según offset del servidor', () {
      // Con offset=0 (default en test), una fecha en el futuro cercano puede
      // dar 0 minutos (truncado) o -1 si el parse falla. Solo verificamos
      // que no lanza excepción.
      final futuro = DateTime.now().toUtc().add(const Duration(seconds: 30));
      final resultado = minutosDesde(futuro.toIso8601String());
      expect(resultado, isA<int>());
    });
    test('fecha hace 3 minutos → ~3', () {
      final hace3 = DateTime.now().toUtc().subtract(const Duration(minutes: 3));
      final resultado = minutosDesde(hace3.toIso8601String());
      // Permitimos ±1 min por latencia de test
      expect(resultado, inInclusiveRange(2, 4));
    });
    test('fecha hace 1 hora → ~60', () {
      final hace1h = DateTime.now().toUtc().subtract(const Duration(hours: 1));
      final resultado = minutosDesde(hace1h.toIso8601String());
      expect(resultado, inInclusiveRange(59, 61));
    });
  });

  // ── infoUltimaActualizacion ──────────────────────────────────────────────
  group('infoUltimaActualizacion', () {
    test('0 segundos → "Actualizado ahora" en verde', () {
      final r = infoUltimaActualizacion(0);
      expect(r.texto, 'Actualizado ahora');
      expect(r.color, AppColors.success);
    });
    test('5 segundos → "Actualizado ahora"', () {
      final r = infoUltimaActualizacion(5);
      expect(r.texto, 'Actualizado ahora');
    });
    test('30 segundos → "Actualizado hace 30 s" en textSecondary', () {
      final r = infoUltimaActualizacion(30);
      expect(r.texto, 'Actualizado hace 30 s');
      expect(r.color, AppColors.textSecondary);
    });
    test('59 segundos → "Actualizado hace 59 s"', () {
      final r = infoUltimaActualizacion(59);
      expect(r.texto, 'Actualizado hace 59 s');
    });
    test('60 segundos (1 min) → "Sin conexión hace 1 min" en rojo', () {
      final r = infoUltimaActualizacion(60);
      expect(r.texto, 'Sin conexión hace 1 min');
      expect(r.color, AppColors.error);
    });
    test('120 segundos (2 min) → "Sin conexión hace 2 min"', () {
      final r = infoUltimaActualizacion(120);
      expect(r.texto, 'Sin conexión hace 2 min');
      expect(r.color, AppColors.error);
    });
  });

  // ── horaDesde ────────────────────────────────────────────────────────────
  group('horaDesde', () {
    test('ISO válido → HH:MM', () {
      // Usa hora fija UTC para que el test sea determinista
      expect(horaDesde('2025-05-08T14:05:00Z'), isNotEmpty);
      // El valor exacto depende del timezone local; solo verificamos formato
      final result = horaDesde('2025-05-08T09:30:00');
      expect(RegExp(r'^\d{2}:\d{2}$').hasMatch(result), isTrue);
    });
    test('fecha inválida → cadena vacía', () {
      expect(horaDesde('invalid'), '');
    });
  });
}

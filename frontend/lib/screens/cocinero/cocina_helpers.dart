import 'package:flutter/material.dart';
import 'package:frontend/core/colors_style.dart';
import 'package:frontend/services/server_time_service.dart';

// ── Constantes de color semánticas ──────────────────────────────────────────
// Los colores de estado de cocina usan los semánticos del DS cuando coinciden
// y añaden uno para el estado "en espera" de turno que no existe en AppColors.
//
// _kVerde  → AppColors.success  (0xFF16A34A ≈ success; usamos el DS)
// _kAmbar  → AppColors.warning  (0xFFD97706 coincide exactamente)
// _kNaranja→ AppColors.noDisp   (naranja urgente; más saturado que warning)
// _kAzul   → AppColors.info     (0xFF3B82F6 ≈ info 0xFF2563EB; usamos info)
// _kMarron → AppColors.surfaceCold (estado pendiente: tono marrón-grisáceo)
//
// Se exportan como constantes públicas para que los tests puedan verificarlas.

const Color kCocinaVerde = AppColors.success; // < 5 min
const Color kCocinaAmbar = AppColors.warning; // 5-9 min
const Color kCocinaFuego = AppColors.noDisp; // 10-14 min (naranja urgente)
const Color kCocinaAzul = AppColors.info; // estado listo
// Marrón para el estado "pendiente" — no existe en DS, lo añadimos como
// surfacePending para que el DS tenga nombre semántico.
const Color kCocinaMarron = AppColors.surfacePending;

// ── Helpers puros (sin contexto de Flutter) ──────────────────────────────────

/// Etiqueta legible del estado de un pedido.
String labelEstado(String e) {
  switch (e) {
    case 'pendiente':
      return 'Pendiente';
    case 'preparando':
      return 'En cocina';
    case 'listo':
      return 'Listo';
    default:
      return e;
  }
}

/// Color asociado al estado de un pedido.
Color colorEstado(String e) {
  switch (e) {
    case 'preparando':
      return AppColors.button;
    case 'listo':
      return kCocinaAzul;
    default:
      return kCocinaMarron;
  }
}

/// Icono asociado al estado de un pedido.
IconData iconoEstado(String e) {
  switch (e) {
    case 'preparando':
      return Icons.local_fire_department_outlined;
    case 'listo':
      return Icons.check_circle_outline;
    default:
      return Icons.pending_outlined;
  }
}

/// Información de entrega (etiqueta + icono) según el tipo.
({String etiqueta, IconData icono}) entregaInfo(
  String tipoEntrega,
  int? numeroMesa,
) {
  switch (tipoEntrega) {
    case 'local':
      return (
        etiqueta: 'Mesa ${numeroMesa ?? '-'}',
        icono: Icons.table_restaurant_outlined,
      );
    case 'domicilio':
      return (etiqueta: 'A domicilio', icono: Icons.delivery_dining_outlined);
    case 'recoger':
      return (etiqueta: 'Para recoger', icono: Icons.shopping_bag_outlined);
    default:
      return (etiqueta: tipoEntrega, icono: Icons.receipt_long_outlined);
  }
}

/// Minutos transcurridos desde [fechaIso] según la hora del servidor.
/// Devuelve `-1` si la fecha es inválida.
int minutosDesde(String fechaIso) {
  try {
    final dt = DateTime.parse(fechaIso);
    return ServerTimeService.instance.now.difference(dt).inMinutes;
  } catch (_) {
    return -1;
  }
}

/// Color del chip de cronómetro según los minutos transcurridos.
Color colorTiempo(int minutos) {
  if (minutos < 0) return AppColors.textSecondary;
  if (minutos < 5) return kCocinaVerde;
  if (minutos < 10) return kCocinaAmbar;
  if (minutos < 15) return kCocinaFuego;
  return AppColors.error;
}

/// Texto formateado del cronómetro (e.g. "7m", "1h 5m").
String formatoTiempo(int minutos) {
  if (minutos < 0) return '—';
  if (minutos < 60) return '${minutos}m';
  final h = minutos ~/ 60;
  final m = minutos % 60;
  return '${h}h ${m}m';
}

/// Formatea una fecha ISO a HH:MM.
String horaDesde(String fechaIso) {
  try {
    final dt = DateTime.parse(fechaIso);
    return '${dt.hour.toString().padLeft(2, '0')}:'
        '${dt.minute.toString().padLeft(2, '0')}';
  } catch (_) {
    return '';
  }
}

/// Texto del indicador "última actualización" para el AppBar.
/// [segundos] es el tiempo transcurrido desde el último poll exitoso.
/// Devuelve texto en español y el color semántico correspondiente.
({String texto, Color color}) infoUltimaActualizacion(int segundos) {
  if (segundos < 10) {
    return (texto: 'Actualizado ahora', color: AppColors.success);
  }
  if (segundos < 60) {
    return (
      texto: 'Actualizado hace $segundos s',
      color: AppColors.textSecondary,
    );
  }
  final minutos = segundos ~/ 60;
  if (minutos == 1) {
    return (texto: 'Sin conexión hace 1 min', color: AppColors.error);
  }
  return (
    texto: 'Sin conexión hace $minutos min',
    color: AppColors.error,
  );
}

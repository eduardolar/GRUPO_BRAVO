/// Constantes y helpers puros usados por la pantalla de reservar mesa.
///
/// Se separan en este fichero para mantener la pantalla principal centrada
/// en estado y orquestación, no en cadenas i18n ni utilidades de fecha.
library;

import 'package:flutter/material.dart';

const List<String> kDiasAbrev = [
  'LUN',
  'MAR',
  'MIÉ',
  'JUE',
  'VIE',
  'SÁB',
  'DOM',
];

const List<String> kMesesAbrev = [
  'ENE',
  'FEB',
  'MAR',
  'ABR',
  'MAY',
  'JUN',
  'JUL',
  'AGO',
  'SEP',
  'OCT',
  'NOV',
  'DIC',
];

const List<String> kMesesCompletos = [
  'enero',
  'febrero',
  'marzo',
  'abril',
  'mayo',
  'junio',
  'julio',
  'agosto',
  'septiembre',
  'octubre',
  'noviembre',
  'diciembre',
];

const List<String> kDiasCompletos = [
  'Lunes',
  'Martes',
  'Miércoles',
  'Jueves',
  'Viernes',
  'Sábado',
  'Domingo',
];

/// "HH:MM" → minutos desde medianoche.
int parseMins(String t) {
  final parts = t.split(':');
  return int.parse(parts[0]) * 60 + int.parse(parts[1]);
}

/// `TimeOfDay` → "HH:MM" con dos dígitos.
String formateoHora(TimeOfDay t) =>
    '${t.hour.toString().padLeft(2, '0')}:'
    '${t.minute.toString().padLeft(2, '0')}';

/// Formato largo: "Martes, 5 de mayo".
String fechaLarga(DateTime d) =>
    '${kDiasCompletos[d.weekday - 1]}, '
    '${d.day} de ${kMesesCompletos[d.month - 1]}';

bool mismaFecha(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

bool esHoy(DateTime d) => mismaFecha(d, DateTime.now());

/// "8 sept" / "12 oct" — fechas cortas usadas en la lista "Mis reservas".
String fechaCorta(DateTime d) => '${d.day} ${kMesesAbrev[d.month - 1]}';

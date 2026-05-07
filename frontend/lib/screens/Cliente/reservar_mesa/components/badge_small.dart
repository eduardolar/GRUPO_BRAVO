import 'package:flutter/material.dart';

/// Chip pequeño con icono + etiqueta de texto coloreada.
/// Usado en las tarjetas de reserva para turno y estado.
class BadgeSmall extends StatelessWidget {
  const BadgeSmall({
    super.key,
    required this.label,
    required this.icono,
    required this.color,
  });

  final String label;
  final IconData icono;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icono, size: 10, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

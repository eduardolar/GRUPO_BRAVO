import 'package:flutter/material.dart';
import '../../core/colors_style.dart';

/// Estado vacío reutilizable.
///
/// Parámetros de color opcionales para adaptarse a fondos claros u oscuros.
/// Por defecto usa la paleta de tema claro (historial de pedidos, etc.).
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;

  /// Acción principal (ej. "Ir al menú"). Si es null no se muestra botón.
  final String? actionLabel;
  final VoidCallback? onAction;

  // Colores — defaults para fondo claro
  final Color? iconColor;
  final Color? iconBackground;
  final Color? titleColor;
  final Color? subtitleColor;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
    this.iconColor,
    this.iconBackground,
    this.titleColor,
    this.subtitleColor,
  });

  // Variante oscura para pantallas con fondo de imagen/negro
  const EmptyState.dark({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
  })  : iconColor       = Colors.white38,
        iconBackground  = null,
        titleColor      = Colors.white60,
        subtitleColor   = Colors.white38;

  @override
  Widget build(BuildContext context) {
    final resolvedIconColor      = iconColor      ?? AppColors.textSecondary.withValues(alpha: 0.35);
    final resolvedTitleColor     = titleColor     ?? AppColors.textPrimary;
    final resolvedSubtitleColor  = subtitleColor  ?? AppColors.textSecondary;

    final iconWidget = iconBackground != null
        ? Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: iconBackground,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.line, width: 2),
            ),
            child: Icon(icon, color: resolvedIconColor, size: 36),
          )
        : Icon(icon, color: resolvedIconColor, size: 40);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            iconWidget,
            const SizedBox(height: 20),
            Text(
              title,
              style: TextStyle(
                color: resolvedTitleColor,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 8),
              Text(
                subtitle!,
                style: TextStyle(
                  color: resolvedSubtitleColor,
                  fontSize: 13,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
            ],
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 24),
              OutlinedButton(
                onPressed: onAction,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.button,
                  side: const BorderSide(color: AppColors.button),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                child: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

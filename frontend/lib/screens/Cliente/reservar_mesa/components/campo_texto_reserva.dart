import 'package:flutter/material.dart';

import '../../../../core/colors_style.dart';

/// Campo de texto estilizado usado en el formulario de nueva reserva.
class CampoTextoReserva extends StatelessWidget {
  const CampoTextoReserva({
    super.key,
    required this.controller,
    required this.hint,
    required this.icono,
    this.maxLines = 1,
    this.capitalizacion = TextCapitalization.none,
    this.validator,
  });

  final TextEditingController controller;
  final String hint;
  final IconData icono;
  final int maxLines;
  final TextCapitalization capitalizacion;
  final String? Function(String?)? validator;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      textCapitalization: capitalizacion,
      validator: validator,
      style: const TextStyle(color: AppColors.textPrimary, fontSize: 15),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(
          color: AppColors.textSecondary.withValues(alpha: 0.55),
          fontSize: 14,
        ),
        prefixIcon: maxLines == 1
            ? Icon(icono, color: AppColors.detailOnDark, size: 20)
            : null,
        contentPadding: EdgeInsets.symmetric(
          horizontal: maxLines > 1 ? 16 : 0,
          vertical: 14,
        ),
        filled: true,
        fillColor: AppColors.panel.withValues(alpha: 0.92),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.white24),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.detailOnDark, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.error, width: 2),
        ),
        errorStyle: const TextStyle(color: AppColors.error),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}

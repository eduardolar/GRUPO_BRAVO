import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/colors_style.dart';

/// Campo de texto con estilo glass coherente con el panel de edición de sucursal.
/// Compartido entre [SuperLocalEditarScreen] y [AdminLocalEditarScreen].
class CampoForm extends StatelessWidget {
  final TextEditingController ctrl;
  final String label;
  final IconData? icono;
  final String? hint;
  final bool mayusculas;
  final TextInputType? teclado;
  final List<TextInputFormatter>? formatos;
  final FormFieldValidator<String>? validador;

  const CampoForm({
    super.key,
    required this.ctrl,
    required this.label,
    this.icono,
    this.hint,
    this.mayusculas = false,
    this.teclado,
    this.formatos,
    this.validador,
  });

  @override
  Widget build(BuildContext context) {
    final allFormatos = [
      if (mayusculas) _UpperCaseFormatter(),
      ...?formatos,
    ];

    return TextFormField(
      controller: ctrl,
      keyboardType: teclado,
      inputFormatters: allFormatos.isEmpty ? null : allFormatos,
      style: const TextStyle(color: Colors.white, fontSize: 14),
      validator: validador,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: const TextStyle(color: Colors.white60, fontSize: 13),
        hintStyle: const TextStyle(color: Colors.white38, fontSize: 13),
        prefixIcon: icono != null
            ? Icon(icono, color: AppColors.button, size: 20)
            : null,
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.06),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Colors.white24),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Colors.white24),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.button, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.error),
        ),
      ),
    );
  }
}

/// Convierte automáticamente el texto a mayúsculas al escribir.
class _UpperCaseFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return newValue.copyWith(text: newValue.text.toUpperCase());
  }
}

import 'package:flutter/material.dart';
import '../../core/colors_style.dart';

class CamposDireccion extends StatelessWidget {
  final TextEditingController controladorDireccion;
  final TextEditingController controladorNotas;
  final bool mostrarDireccionAlternativa;

  const CamposDireccion({
    super.key,
    required this.controladorDireccion,
    required this.controladorNotas,
    this.mostrarDireccionAlternativa = false,
  });

  InputDecoration _decoracionCampo({
    required String etiqueta,
    required String pista,
  }) {
    return InputDecoration(
      labelText: etiqueta,
      labelStyle: const TextStyle(color: AppColors.textSecondary),
      hintText: pista,
      hintStyle: TextStyle(color: AppColors.textSecondary.withValues(alpha: 0.5)),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.line),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.line),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.button),
      ),
      filled: true,
      fillColor: AppColors.panel,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (mostrarDireccionAlternativa) ...[
          TextField(
            controller: controladorDireccion,
            style: const TextStyle(color: AppColors.textPrimary),
            decoration: _decoracionCampo(
              etiqueta: 'Dirección alternativa',
              pista: 'Calle, número, piso, código postal...',
            ),
            maxLines: 2,
          ),
          const SizedBox(height: 12),
        ],
        TextField(
          controller: controladorNotas,
          style: const TextStyle(color: AppColors.textPrimary),
          decoration: _decoracionCampo(
            etiqueta: 'Notas adicionales (opcional)',
            pista: 'Timbre, piso, instrucciones especiales...',
          ),
          maxLines: 2,
        ),
      ],
    );
  }
}

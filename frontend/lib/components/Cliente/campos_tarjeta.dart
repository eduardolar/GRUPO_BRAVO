import 'package:flutter/material.dart';
import '../../core/colors_style.dart';

class CamposTarjeta extends StatelessWidget {
  final TextEditingController controladorNumero;
  final TextEditingController controladorFechaExpiracion;
  final TextEditingController controladorCvv;
  final TextEditingController controladorNombreTitular;

  const CamposTarjeta({
    super.key,
    required this.controladorNumero,
    required this.controladorFechaExpiracion,
    required this.controladorCvv,
    required this.controladorNombreTitular,
  });

  InputDecoration _decoracionCampo({
    required String etiqueta,
    required String pista,
    Widget? iconoPrefijo,
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
      prefixIcon: iconoPrefijo,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Datos de la tarjeta',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: controladorNumero,
          style: const TextStyle(color: AppColors.textPrimary),
          decoration: _decoracionCampo(
            etiqueta: 'Número de tarjeta',
            pista: '1234 5678 9012 3456',
            iconoPrefijo: const Icon(
              Icons.credit_card,
              color: AppColors.iconPrimary,
            ),
          ),
          keyboardType: TextInputType.number,
          maxLength: 19,
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: controladorFechaExpiracion,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: _decoracionCampo(
                  etiqueta: 'Fecha expiración',
                  pista: 'MM/AA',
                ),
                keyboardType: TextInputType.datetime,
                maxLength: 5,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: controladorCvv,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: _decoracionCampo(etiqueta: 'CVV', pista: '123'),
                keyboardType: TextInputType.number,
                maxLength: 4,
                obscureText: true,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        TextField(
          controller: controladorNombreTitular,
          style: const TextStyle(color: AppColors.textPrimary),
          decoration: _decoracionCampo(
            etiqueta: 'Nombre del titular',
            pista: 'Como aparece en la tarjeta',
            iconoPrefijo: const Icon(
              Icons.person,
              color: AppColors.iconPrimary,
            ),
          ),
          textCapitalization: TextCapitalization.words,
        ),
      ],
    );
  }
}

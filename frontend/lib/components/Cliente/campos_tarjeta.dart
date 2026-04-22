import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import '../../core/colors_style.dart';

class CamposTarjeta extends StatelessWidget {
  final void Function(CardFieldInputDetails?) onCardChanged;

  const CamposTarjeta({
    super.key,
    required this.onCardChanged,
    required TextEditingController controladorNombreTitular,
    required TextEditingController controladorCvv,
    required TextEditingController controladorFechaExpiracion,
    required TextEditingController controladorNumero,
  });

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.panel,
          border: Border.all(color: AppColors.line),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            const Icon(Icons.lock_outline, color: AppColors.button, size: 28),
            const SizedBox(width: 14),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Pago seguro con Stripe',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Al confirmar serás redirigido a la página de pago de Stripe para completar la transacción.',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

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
        CardField(
          onCardChanged: onCardChanged,
          style: const TextStyle(color: AppColors.textPrimary, fontSize: 16),
          decoration: InputDecoration(
            filled: true,
            fillColor: AppColors.panel,
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
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Pago seguro gestionado por Stripe',
          style: TextStyle(
            color: AppColors.textSecondary.withValues(alpha: 0.7),
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}

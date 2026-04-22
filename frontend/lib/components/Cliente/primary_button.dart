import 'package:flutter/material.dart';
import '../../core/colors_style.dart';

/// Botón principal de ancho completo con estado de carga.
/// Usado en formularios de autenticación y acciones primarias.
class PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final double height;

  const PrimaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.isLoading = false,
    this.height = 55,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: height,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.button,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppColors.button.withValues(alpha: 0.5),
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
          elevation: 0,
        ),
        onPressed: isLoading ? null : onPressed,
        child: isLoading
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : Text(
                label,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                ),
              ),
      ),
    );
  }
}

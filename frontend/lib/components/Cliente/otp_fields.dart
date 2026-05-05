import 'package:flutter/material.dart';
import '../../core/colors_style.dart';

/// Fila de 6 campos OTP para verificación de código.
/// Gestiona el foco automático entre campos y llama [onComplete]
/// al rellenar el último dígito.
class OtpFields extends StatelessWidget {
  final List<TextEditingController> controllers;
  final List<FocusNode> focusNodes;
  final VoidCallback? onComplete;

  const OtpFields({
    super.key,
    required this.controllers,
    required this.focusNodes,
    this.onComplete,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const gaps = 5 * 8.0;
        final fieldWidth = ((constraints.maxWidth - gaps) / 6).clamp(
          36.0,
          52.0,
        );
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(6, (index) {
            return SizedBox(
              width: fieldWidth,
              child: TextField(
                controller: controllers[index],
                focusNode: focusNodes[index],
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                maxLength: 1,
                style: TextStyle(
                  color: const Color.fromARGB(255, 0, 0, 0),
                  fontSize: (fieldWidth * 0.48).clamp(18.0, 24.0),
                  fontWeight: FontWeight.bold,
                ),
                decoration: InputDecoration(
                  counterText: '',
                  filled: true,
                  fillColor: AppColors.panel,
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: AppColors.line),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(
                      color: AppColors.button,
                      width: 2,
                    ),
                  ),
                ),
                onChanged: (value) {
                  if (value.isNotEmpty && index < 5) {
                    focusNodes[index + 1].requestFocus();
                  }
                  if (value.isEmpty && index > 0) {
                    focusNodes[index - 1].requestFocus();
                  }
                  if (index == 5 && value.isNotEmpty) {
                    onComplete?.call();
                  }
                },
              ),
            );
          }),
        );
      },
    );
  }
}

import 'package:flutter/material.dart';
import 'entrega_constantes.dart';

class FormPanel extends StatelessWidget {
  final Widget child;
  const FormPanel({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.45),
        borderRadius: kRadiusEntrega,
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      padding: const EdgeInsets.all(16),
      child: child,
    );
  }
}

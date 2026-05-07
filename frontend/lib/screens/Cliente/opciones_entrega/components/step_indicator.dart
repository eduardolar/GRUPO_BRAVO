import 'package:flutter/material.dart';
import '../../../../core/colors_style.dart';
import 'entrega_constantes.dart';

// Importamos el enum _Paso; se expone desde el barrel de la carpeta.
// El enum vive en el archivo principal pero es accesible aquí vía import del barrel.

enum EntregaPaso { confirmar, entrega, pago }

extension EntregaPasoX on EntregaPaso {
  String get titulo => switch (this) {
        EntregaPaso.confirmar => 'CONFIRMAR',
        EntregaPaso.entrega => 'ENTREGA',
        EntregaPaso.pago => 'PAGO',
      };

  EntregaPaso? get anterior => switch (this) {
        EntregaPaso.confirmar => null,
        EntregaPaso.entrega => EntregaPaso.confirmar,
        EntregaPaso.pago => EntregaPaso.entrega,
      };
}

class StepIndicator extends StatelessWidget {
  final EntregaPaso paso;

  const StepIndicator({super.key, required this.paso});

  @override
  Widget build(BuildContext context) {
    final pasoIdx = EntregaPaso.values.indexOf(paso);
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.35),
        border: Border(
          bottom: BorderSide(color: Colors.white.withValues(alpha: 0.10)),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
      child: Row(
        children: [
          _StepDot(
            label: 'Confirmar',
            activo: pasoIdx == 0,
            hecho: pasoIdx > 0,
          ),
          _Linea(activa: pasoIdx > 0),
          _StepDot(
            label: 'Entrega',
            activo: pasoIdx == 1,
            hecho: pasoIdx > 1,
          ),
          _Linea(activa: pasoIdx > 1),
          _StepDot(label: 'Pago', activo: pasoIdx == 2, hecho: false),
        ],
      ),
    );
  }
}

class _Linea extends StatelessWidget {
  final bool activa;
  const _Linea({required this.activa});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 350),
        height: 1,
        margin: const EdgeInsets.symmetric(horizontal: 10),
        color: activa ? AppColors.button : Colors.white.withValues(alpha: 0.20),
      ),
    );
  }
}

class _StepDot extends StatelessWidget {
  final String label;
  final bool activo;
  final bool hecho;

  const _StepDot({
    required this.label,
    required this.activo,
    required this.hecho,
  });

  @override
  Widget build(BuildContext context) {
    final filled = activo || hecho;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedContainer(
          duration: kAnimMed,
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: filled ? AppColors.button : Colors.transparent,
            border: Border.all(
              color: filled
                  ? AppColors.button
                  : Colors.white.withValues(alpha: 0.30),
              width: 1.5,
            ),
          ),
          child: Center(
            child: hecho
                ? const Icon(Icons.check, size: 14, color: Colors.white)
                : Icon(
                    activo ? Icons.circle : Icons.circle_outlined,
                    size: 7,
                    color: filled
                        ? Colors.white
                        : Colors.white.withValues(alpha: 0.35),
                  ),
          ),
        ),
        const SizedBox(height: 5),
        Text(
          label.toUpperCase(),
          style: TextStyle(
            color: filled ? Colors.white : Colors.white.withValues(alpha: 0.35),
            fontSize: 8,
            letterSpacing: 1.2,
            fontWeight: filled ? FontWeight.w700 : FontWeight.w400,
          ),
        ),
      ],
    );
  }
}

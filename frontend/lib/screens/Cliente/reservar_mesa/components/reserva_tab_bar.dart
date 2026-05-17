import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/colors_style.dart';

/// Segmented control en píldora que actúa como TabBar para la pantalla
/// de reservar mesa. Recibe el [TabController] externo para sincronización.
class ReservaTabBar extends StatelessWidget {
  const ReservaTabBar({super.key, required this.tabController});

  final TabController tabController;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 18, 24, 14),
      child: AnimatedBuilder(
        animation: tabController,
        builder: (_, _) {
          final i = tabController.index;
          return Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
            ),
            child: Row(
              children: [
                _SegmentoTab(
                  label: 'NUEVA RESERVA',
                  activo: i == 0,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    tabController.animateTo(0);
                  },
                ),
                _SegmentoTab(
                  label: 'MIS RESERVAS',
                  activo: i == 1,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    tabController.animateTo(1);
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _SegmentoTab extends StatelessWidget {
  const _SegmentoTab({
    required this.label,
    required this.activo,
    required this.onTap,
  });

  final String label;
  final bool activo;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          height: 38,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: activo ? AppColors.primaryAccent : Colors.transparent,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: activo ? Colors.white : Colors.white60,
              fontSize: 11,
              fontWeight: activo ? FontWeight.w800 : FontWeight.w600,
              letterSpacing: 1.6,
            ),
          ),
        ),
      ),
    );
  }
}

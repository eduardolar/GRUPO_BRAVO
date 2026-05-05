import 'package:flutter/material.dart';

import '../skeleton.dart';
import '../../../core/colors_style.dart';

/// Loader animado mientras se descargan las reservas del cliente.
class SkeletonReservas extends StatefulWidget {
  const SkeletonReservas({super.key});

  @override
  State<SkeletonReservas> createState() => _SkeletonReservasState();
}

class _SkeletonReservasState extends State<SkeletonReservas>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, _) => CustomScrollView(
        physics: const NeverScrollableScrollPhysics(),
        slivers: [
          // Label "PRÓXIMAS"
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 28, 20, 14),
              child: Row(
                children: const [
                  SkeletonBlock.dark(width: 96, height: 11),
                  SizedBox(width: 10),
                  SkeletonBlock.dark(width: 22, height: 22, borderRadius: 11),
                ],
              ),
            ),
          ),
          // Tarjetas skeleton (próximas)
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _tarjeta(notas: false),
                _tarjeta(notas: true),
                _tarjeta(notas: false),
              ]),
            ),
          ),
          // Segunda sección (pasadas)
          SliverToBoxAdapter(
            child: const Padding(
              padding: EdgeInsets.fromLTRB(20, 20, 20, 14),
              child: SkeletonBlock.dark(width: 80, height: 11),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _tarjeta(notas: false, pasada: true),
                _tarjeta(notas: false, pasada: true),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tarjeta({required bool notas, bool pasada = false}) {
    final t = Curves.easeInOut.transform(_ctrl.value);
    final cardColor = Color.lerp(
      AppColors.panel.withValues(alpha: pasada ? 0.40 : 0.55),
      AppColors.panel.withValues(alpha: pasada ? 0.55 : 0.72),
      t,
    )!;
    final colFecha = Color.lerp(
      AppColors.button.withValues(alpha: pasada ? 0.03 : 0.05),
      AppColors.button.withValues(alpha: pasada ? 0.07 : 0.12),
      t,
    )!;

    return Opacity(
      opacity: pasada ? 0.55 : 1.0,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white10),
        ),
        child: IntrinsicHeight(
          child: Row(
            children: [
              // ── Columna fecha ──
              Container(
                width: 70,
                decoration: BoxDecoration(
                  color: colFecha,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(14),
                    bottomLeft: Radius.circular(14),
                  ),
                ),
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    SkeletonBlock.dark(width: 30, height: 28, borderRadius: 4),
                    SizedBox(height: 6),
                    SkeletonBlock.dark(width: 22, height: 10, borderRadius: 3),
                    SizedBox(height: 4),
                    SkeletonBlock.dark(width: 18, height: 9, borderRadius: 3),
                  ],
                ),
              ),
              // ── Contenido ──
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 14, 12, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          SkeletonBlock.dark(width: 56, height: 20),
                          SizedBox(width: 8),
                          SkeletonBlock.dark(width: 68, height: 20),
                        ],
                      ),
                      const SizedBox(height: 10),
                      const SkeletonBlock.dark(height: 14, borderRadius: 4),
                      if (notas) ...[
                        const SizedBox(height: 8),
                        const SkeletonBlock.dark(
                          width: 120,
                          height: 11,
                          borderRadius: 4,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:frontend/core/colors_style.dart';

// ─── Paleta 60-30-10 ───────────────────────────────────────────────
// 60% → negro cálido profundo:  AppColors.background
// 30% → marrón oscuro cálido:   AppColors.backgroundButton
// 10% → dorado:                 AppColors.gold
// ───────────────────────────────────────────────────────────────────

class GestionStock extends StatefulWidget {
  const GestionStock({super.key});

  @override
  State<GestionStock> createState() => _GestionStockState();
}

class _GestionStockState extends State<GestionStock> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // 60% — fondo dominante, negro cálido
      backgroundColor: AppColors.background,

      body: SafeArea(
        child: Column(
          children: [
            // ── HEADER — superficie 30% ──────────────────────────
            _buildHeader(),

            // ── CUERPO — fondo 60% ───────────────────────────────
            const Spacer(),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                children: [
                  _menuButton(
                    icon: Icons.block_outlined,
                    text: "Bloquear producto",
                    subtitle: "Marcar como no disponible",
                    onTap: () {},
                  ),

                  const SizedBox(height: 40),

                  _menuButton(
                    icon: Icons.warning_amber_outlined,
                    text: "Avisar de falta de producto",
                    subtitle: "Notificar stock bajo",
                    onTap: () {},
                  ),
                ],
              ),
            ),

            const Spacer(),
          ],
        ),
      ),
    );
  }

  // ── Header con superficie 30% y acento dorado 10% ─────────────────
  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      // 30% — superficie cálida para el encabezado
      color: AppColors.backgroundButton,
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
      child: Column(
        children: [
          // Círculo con icono — acento dorado 10%
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.gold, width: 1.5),
            ),
            child: const Icon(
              Icons.inventory_2_outlined,
              color: AppColors.gold, // 10% dorado
              size: 24,
            ),
          ),

          const SizedBox(height: 12),

          // Título principal
          const Text(
            "Gestión de Stock",
            style: TextStyle(
              fontFamily: 'Playfair Display',
              color: Color(0xFFF5ECD4), // blanco cálido
              fontSize: 24,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),

          const SizedBox(height: 6),

          // Subtítulo en dorado — acento 10%
          Text(
            "SELECCIONA UNA OPCIÓN",
            style: TextStyle(
              color: AppColors.gold.withOpacity(0.8), // 10% dorado
              fontSize: 10,
              letterSpacing: 3,
              fontWeight: FontWeight.w400,
            ),
          ),

          const SizedBox(height: 16),

          // Separador con degradado dorado — acento 10%
          Row(
            children: [
              const Expanded(child: Divider(color: Color(0xFF2e2418))),
              Container(
                width: 60,
                height: 1.5,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.transparent,
                      AppColors.gold, // 10% dorado
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
              const Expanded(child: Divider(color: Color(0xFF2e2418))),
            ],
          ),
        ],
      ),
    );
  }

  // ── Botón de menú con diseño 60-30-10 ────────────────────────────
  Widget _menuButton({
    required IconData icon,
    required String text,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        decoration: BoxDecoration(
          // 30% — superficie de la tarjeta
          color: AppColors.backgroundButton,
          border: Border.all(color: const Color(0xFF2e2418)),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            // Icono en su contenedor — 30% con acento 10%
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: const Color(0xFF251D12), // 30% más oscuro
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF3a2e1e)),
              ),
              child: Icon(
                icon,
                color: AppColors.gold, // 10% dorado
                size: 20,
              ),
            ),

            const SizedBox(width: 14),

            // Textos
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    text,
                    style: const TextStyle(
                      color: Color(0xFFF0E4C8), // blanco cálido
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.2,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: Color(0xFF7a6a50), // gris dorado apagado
                      fontSize: 11,
                      fontWeight: FontWeight.w300,
                      letterSpacing: 0.4,
                    ),
                  ),
                ],
              ),
            ),

            // Flecha — acento dorado 10%
            Icon(
              Icons.chevron_right,
              color: AppColors.gold.withOpacity(0.7), // 10% dorado
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}
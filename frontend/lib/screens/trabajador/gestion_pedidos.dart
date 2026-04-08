import 'package:flutter/material.dart';
import 'package:frontend/core/colors_style.dart';

// ─── Paleta 60-30-10 ───────────────────────────────────────────────
// 60% → negro cálido profundo:  AppColors.background
// 30% → marrón oscuro cálido:   AppColors.backgroundButton
// 10% → dorado:                 AppColors.gold
// ───────────────────────────────────────────────────────────────────

class GestionPedidos extends StatefulWidget {
  const GestionPedidos({super.key});

  @override
  State<GestionPedidos> createState() => _GestionPedidosState();
}

class _GestionPedidosState extends State<GestionPedidos> {
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
                    icon: Icons.add_shopping_cart_outlined,
                    text: "Crear un pedido",
                    subtitle: "Nueva comanda de mesa",
                    onTap: () {},
                  ),

                  const SizedBox(height: 16),

                  _menuButton(
                    icon: Icons.edit_outlined,
                    text: "Modificar un pedido",
                    subtitle: "Editar o cancelar líneas",
                    onTap: () {},
                    
                  ),
                  const SizedBox(height: 16),
                  _menuButton(
                    icon: Icons.delete_outline,
                    text: "Eliminar un pedido",
                    subtitle: "Borrar un pedido",
                    onTap: () {},
                    
                  ),
                  const SizedBox(height: 16),
                  _menuButton(
                    icon: Icons.list_alt_outlined,
                    text: "Lista de pedidos",
                    subtitle: "Ver todos los pedidos",
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
              border: Border.all(color: Colors.white, width: 1.5),
            ),
            child: const Icon(
              Icons.receipt_long_outlined,
              color: Colors.white, // acento claro
              size: 24,
            ),
          ),

          const SizedBox(height: 12),

          // Título principal
          const Text(
            "Gestión de pedidos",
            style: TextStyle(
              fontFamily: 'Playfair Display',
              color: Colors.white, // blanco cálido
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
              color: Colors.white70, // 10% dorado
              fontSize: 10,
              letterSpacing: 3,
              fontWeight: FontWeight.w400,
            ),
          ),

          const SizedBox(height: 16),

          // Separador con degradado dorado — acento 10%
          Row(
            children: [
              const Expanded(child: Divider(color: Color(0xFFE0DBD3))),
              Container(
                width: 60,
                height: 1.5,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.transparent,
                      Colors.white, // acento claro
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
              const Expanded(child: Divider(color: Color(0xFFE0DBD3))),
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
          border: Border.all(color: const Color(0xFFE0DBD3)),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            // Icono en su contenedor — 30% con acento 10%
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: const Color(0xFF660019), // 30% más oscuro
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFA6405A)),
              ),
              child: Icon(
                icon,
                color: Colors.white, // acento claro
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
                      color: Colors.white, // blanco cálido
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.2,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: Colors.white70, // gris dorado apagado
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
              color: Colors.white54, // 10% dorado
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}
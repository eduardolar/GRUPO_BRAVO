import 'package:flutter/material.dart';
import 'package:frontend/core/colors_style.dart';
import 'package:frontend/screens/trabajador/avisar_falta.dart';
import 'package:frontend/screens/trabajador/bloquear_producto.dart';



class GestionStock extends StatefulWidget {
  const GestionStock({super.key});

  @override
  State<GestionStock> createState() => _GestionStockState();
}

class _GestionStockState extends State<GestionStock> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,

      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),

            const Spacer(),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                children: [
                  _menuButton(
                    icon: Icons.block_outlined,
                    text: "Bloquear producto",
                    subtitle: "Marcar como no disponible",
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const BloquearProducto()),
                    );
                    },
                  ),

                  const SizedBox(height: 40),

                  _menuButton(
                    icon: Icons.warning_amber_outlined,
                    text: "Avisar de falta de producto",
                    subtitle: "Notificar stock bajo",
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const AvisarFaltaScreen()),
                        );
                    },
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

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      color: AppColors.backgroundButton,
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
      child: Column(
        children: [
          
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 1.5),
            ),
            child: const Icon(
              Icons.inventory_2_outlined,
              color: AppColors.background, 
              size: 24,
            ),
          ),

          const SizedBox(height: 12),

          // Título principal
          const Text(
            "Gestión de Stock",
            style: TextStyle(
              fontFamily: 'Playfair Display',
              color: Colors.white, 
              fontSize: 24,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),

          const SizedBox(height: 6),

          
          Text(
            "SELECCIONA UNA OPCIÓN",
            style: TextStyle(
              color: Colors.white70, 
              fontSize: 10,
              letterSpacing: 3,
              fontWeight: FontWeight.w400,
            ),
          ),

          const SizedBox(height: 16),

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
                      Colors.white, 
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
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: const Color(0xFF660019), 
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFA6405A)),
              ),
              child: Icon(
                icon,
                color: AppColors.background, 
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
                      color: AppColors.background, 
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.2,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 11,
                      fontWeight: FontWeight.w300,
                      letterSpacing: 0.4,
                    ),
                  ),
                ],
              ),
            ),

            Icon(
              Icons.chevron_right,
              color: Colors.white54, 
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}
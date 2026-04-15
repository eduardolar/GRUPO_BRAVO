import 'package:flutter/material.dart';
import 'package:frontend/core/colors_style.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:frontend/screens/trabajador/gestion_pedidos.dart';
import 'package:frontend/screens/trabajador/Reservas/gestion_reservas.dart';
import 'package:frontend/screens/trabajador/Stock/gestion_stock.dart';
import 'package:frontend/screens/trabajador/servicio.dart';

class HomeTrabajador extends StatefulWidget {
  const HomeTrabajador({super.key});

  @override
  State<HomeTrabajador> createState() => _HomeTrabajadorState();
}

class _HomeTrabajadorState extends State<HomeTrabajador> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // ── ENCABEZADO ──
            Container(
              width: double.infinity,
              padding: const EdgeInsets.only(top: 40, bottom: 28),
              color: AppColors.backgroundButton,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 1.5),
                    ),
                    child: const Icon(
                      Icons.restaurant_outlined,
                      color: Colors.white,
                      size: 32,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    "Tu Restaurante",
                    style: GoogleFonts.playfairDisplay(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "BIENVENIDO",
                    style: GoogleFonts.lato(
                      color: Colors.white54,
                      fontSize: 12,
                      letterSpacing: 3.0,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40),
                    child: Row(
                      children: [
                        const Expanded(
                          child: Divider(color: Colors.white38, thickness: 0.8),
                        ),
                        Container(
                          margin: const EdgeInsets.symmetric(horizontal: 6),
                          width: 5,
                          height: 5,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white38,
                          ),
                        ),
                        const Expanded(
                          child: Divider(color: Colors.white38, thickness: 0.8),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // ── CONTENIDO ──
            Expanded(
              child: Container(
                margin: const EdgeInsets.all(12),
                
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const SizedBox(height: 20),
                      const Text(
                        "Selecciona una opción:",
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 40),
                      _menuButton(
                        icon: Icons.inventory_2_outlined,
                        text: "Gestión de stock",
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const GestionStock()),
                          );
                        },
                      ),
                      const SizedBox(height: 20),
                      _menuButton(
                        icon: Icons.room_service_outlined,
                        text: "Servicio",
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const ServicioTrabajador()),
                          );
                        },
                      ),
                      const SizedBox(height: 20),
                      _menuButton(
                        icon: Icons.receipt_long_outlined,
                        text: "Gestión de pedidos",
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const GestionPedidos()),
                          );
                        },
                      ),
                      const SizedBox(height: 20),
                      _menuButton(
                        icon: Icons.event_available_outlined,
                        text: "Gestión de reservas",
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const GestionReservas()),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _menuButton({
    required IconData icon,
    required String text,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 70,
        decoration: BoxDecoration(
          color: AppColors.button,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.sombra, width: 1),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 28),
            const SizedBox(width: 12),
            Text(
              text,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
import 'package:flutter/material.dart';
import 'package:frontend/core/colors_style.dart';
import 'package:frontend/screens/trabajador/gestion_pedidos.dart';
import 'package:frontend/screens/trabajador/gestion_reservas.dart';
import 'package:frontend/screens/trabajador/gestion_stock.dart';
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
        child: Container(
           margin: const EdgeInsets.all(12), // margen para que se vea el borde
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.gold, width: 1), // borde exterior
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 20),
          
                // Título
                const Text(
                  "Tu Restaurante",
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 26,
                  ),
                ),
          
                const SizedBox(height: 10),
          
                const Text(
                  "Bienvenido",
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 20,
                  ),
                ),
          
                const SizedBox(height: 5),
          
                const Text(
                  "Selecciona una opción:",
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 16,
                  ),
                ),
          
                const SizedBox(height: 40),
          
                // BOTÓN 1 - Gestión de stock
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
          
                // BOTÓN 2 - Servicio
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
          
                // BOTÓN 3 - Gestión de pedidos
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
          
                // BOTÓN 4 - Gestión de reservas
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
    );
  }

  // Widget reutilizable para los botones
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
          border: Border.all(color: AppColors.gold, width: 2),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: AppColors.textPrimary, size: 28),
            const SizedBox(width: 12),
            Text(
              text,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 20,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
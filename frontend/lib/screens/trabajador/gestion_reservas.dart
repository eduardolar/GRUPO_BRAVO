import 'package:flutter/material.dart';
import 'package:frontend/core/colors_style.dart';

class GestionReservas extends StatefulWidget {
  const GestionReservas({super.key});

  @override
  State<GestionReservas> createState() => _GestionReservasState();
}

class _GestionReservasState extends State<GestionReservas> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Container(
          margin: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.gold, width: 2),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              const SizedBox(height: 20),

              const Text(
                "Gestión de reservas",
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 26,
                ),
              ),

              const Spacer(), 

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Column(
                  children: [
                    _menuButton(
                      icon: Icons.edit,
                      text: "Modificar reserva",
                      onTap: () {},
                    ),

                    const SizedBox(height: 70),

                    _menuButton(
                      icon: Icons.list,
                      text: "Lista de reservas",
                      onTap: () {},
                    ),
                  ],
                ),
              ),

              const Spacer(), 
            ],
          ),
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
        border: Border.all(color: AppColors.gold, width: 2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row( 
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon, 
            color: AppColors.gold,
            size: 28,
          ),
          const SizedBox(width: 15), 
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
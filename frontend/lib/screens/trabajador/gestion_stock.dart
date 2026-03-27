import 'package:flutter/material.dart';
import 'package:frontend/core/colors_style.dart';

class GestionStock extends StatefulWidget {
  const GestionStock({super.key});

  @override
  State<GestionStock> createState() => _GestionStockState();
}

class _GestionStockState extends State<GestionStock> {
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
                "Gestión de Stock",
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
                      icon: Icons.block,
                      text: "Bloquear producto",
                      onTap: () {},
                    ),

                    const SizedBox(height: 70),

                    _menuButton(
                      icon: Icons.warning,
                      text: "Avisar de falta de producto",
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

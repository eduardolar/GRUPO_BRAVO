import 'package:flutter/material.dart';
import 'package:frontend/core/colors_style.dart';

class GestionPedidos extends StatefulWidget {
  const GestionPedidos({super.key});

  @override
  State<GestionPedidos> createState() => _GestionPedidosState();
}

class _GestionPedidosState extends State<GestionPedidos> {
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
                "Gestión de pedidos",
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
                      icon: Icons.add_shopping_cart,
                      text: "Crear un pedido",
                      onTap: () {},
                    ),

                    const SizedBox(height: 70),

                    _menuButton(
                      icon: Icons.edit,
                      text: "Modificar un pedido",
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
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:frontend/core/colors_style.dart';
import 'package:frontend/providers/auth_provider.dart';
import 'package:frontend/screens/cliente/home_screen.dart';

class HomeScreenAdmin extends StatelessWidget {
  const HomeScreenAdmin({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundButton,
        title: const Text(
          'Panel de Administración',
          style: TextStyle(
            fontFamily: 'Playfair Display',
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: () {
              Provider.of<AuthProvider>(context, listen: false).cerrarSesion();
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const HomeScreen()),
                (route) => false,
              );
            },
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.gold, width: 2),
              ),
              child: const Icon(
                Icons.admin_panel_settings,
                color: AppColors.gold,
                size: 40,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Bienvenido, Administrador',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 22,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Panel en construcción',
              style: TextStyle(
                color: AppColors.gold.withOpacity(0.7),
                fontSize: 14,
                letterSpacing: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

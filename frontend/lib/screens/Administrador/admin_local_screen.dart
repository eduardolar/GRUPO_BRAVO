import 'package:flutter/material.dart';
import 'package:frontend/core/colors_style.dart';

class AdminLocalScreen extends StatefulWidget {
  const AdminLocalScreen({super.key});

  @override
  State<AdminLocalScreen> createState() => _AdminLocalScreenState();
}

class _AdminLocalScreenState extends State<AdminLocalScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Text(
        "Pantalla de configuración del local",
        style: TextStyle(color: AppColors.gold),
      ),
    );
  }
}

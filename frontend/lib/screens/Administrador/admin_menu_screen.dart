import 'package:flutter/material.dart';
import 'package:frontend/core/colors_style.dart';

class AdminMenuScreen extends StatefulWidget {
  const AdminMenuScreen({super.key});

  @override
  State<AdminMenuScreen> createState() => _AdminMenuScreenState();
}

class _AdminMenuScreenState extends State<AdminMenuScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Text("Pantalla de administracion del menú del restaurante", style: TextStyle(color: AppColors.gold),),
    );
  }
}
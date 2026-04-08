import 'package:flutter/material.dart';
import 'package:frontend/core/colors_style.dart';

class AdminUsuariosScreen extends StatefulWidget {
  const AdminUsuariosScreen({super.key});

  @override
  State<AdminUsuariosScreen> createState() => _AdminUsuariosScreenState();
}

class _AdminUsuariosScreenState extends State<AdminUsuariosScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Text("Pantalla d eadministracion de usuarios", style: TextStyle(color: AppColors.gold)),
    );
  }
}
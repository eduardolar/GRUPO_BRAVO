import 'package:flutter/material.dart';
import 'package:frontend/core/colors_style.dart';

class AdminContabilidadScreen extends StatefulWidget {
  const AdminContabilidadScreen({super.key});

  @override
  State<AdminContabilidadScreen> createState() => _AdminContabilidadScreenState();
}

class _AdminContabilidadScreenState extends State<AdminContabilidadScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Text("Pantalla de administracion de contabilidad", style: TextStyle(color: AppColors.gold)),
    );
  }
}
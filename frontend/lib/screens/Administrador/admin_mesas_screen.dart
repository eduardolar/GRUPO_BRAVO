import 'package:flutter/material.dart';
import 'package:frontend/core/colors_style.dart';

class AdminMesasScreen extends StatefulWidget {
  const AdminMesasScreen({super.key});

  @override
  State<AdminMesasScreen> createState() => _AdminMesasScreenState();
}

class _AdminMesasScreenState extends State<AdminMesasScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Text("Pantalla de administracion de mesas", style: TextStyle(color: AppColors.gold)) ,
    );
  }


}
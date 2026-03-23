import 'package:flutter/material.dart';
import 'package:frontend/core/colors_style.dart';
import 'package:frontend/screens/home_screen.dart';


void main() {
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: Text("Nombre_Restaurante"),
        backgroundColor: AppColors.panel,
        foregroundColor: Colors.white,),
        backgroundColor: AppColors.background,
        body: HomeScreen(),
        ),
      )
    ;
  }
}

import 'package:flutter/material.dart';
import 'package:frontend/core/colors_style.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.panel,
        elevation: 0,
        title: Text("NombreRestaurante", style: TextStyle(
          color: Colors.black
        )),
      centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Bienvenido", style: TextStyle(
                fontSize: 26, fontWeight: FontWeight.bold
              )),
              const SizedBox(height: 10,),
              const Text("Selecciona una opcion", style: TextStyle(
                fontSize: 16, color: AppColors.panel
              ))
            ],
                ),
        )
      ),
      

      
    );
  }
}
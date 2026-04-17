import 'package:flutter/material.dart';
import 'package:frontend/core/colors_style.dart';

class EditarIngredienteStock extends StatefulWidget {
  const EditarIngredienteStock({super.key});

  @override
  State<EditarIngredienteStock> createState() => _EditarIngredienteStockState();
}

class _EditarIngredienteStockState extends State<EditarIngredienteStock> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(),
      body: Column(
        children: [
          Text(
            "Pagina edicion de ingredientes",
            style: TextStyle(color: AppColors.textPrimary),
          ),
          ElevatedButton(onPressed: (){

          }, child: Text("Cambiar disponibilidad"))
        ],
      ),

    );
  }
}

import 'package:flutter/material.dart';
import 'package:frontend/core/colors_style.dart';

class EditarStock extends StatefulWidget {
  const EditarStock({super.key});

  @override
  State<EditarStock> createState() => _EditarStockState();
}

class _EditarStockState extends State<EditarStock> {
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

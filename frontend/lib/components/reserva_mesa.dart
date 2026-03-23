import 'package:flutter/material.dart';
import 'package:frontend/core/colors_style.dart';

class ReservaMesa extends StatefulWidget {
  const ReservaMesa({super.key});

  @override
  State<ReservaMesa> createState() => _ReservaMesaState();
}

class _ReservaMesaState extends State<ReservaMesa> {
  @override
  Widget build(BuildContext context) {
    //AÑADO PADDING
    return Padding(
      padding: const EdgeInsets.all(16),
      //WIDGET QUE CONVIERTE EL CONTAINER EN BOTON
      child: GestureDetector(
        onTap: () {
            //RELLENAR PARA ABRIR LA CAMARA Y ESCANEE QR
        },
        child: Container(
            width: double.infinity,
          decoration: BoxDecoration(
            color: AppColors.background,
            border: Border.all(color: AppColors.gold),
            borderRadius: BorderRadius.circular(16),
             ),
             child: Row(
              children: [
                Text("Reserva ya tu mesa", style: TextStyle(
                  fontSize: 24,
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.bold,
                ),)
              
              ],
              
             ),
        ),
      ),
    );
  }
}
import 'package:flutter/material.dart';
import 'package:frontend/core/colors_style.dart';
import 'package:frontend/screens/Cliente/login_screen.dart';

class ReservarMesa extends StatefulWidget {
  const ReservarMesa({super.key});

  @override
  State<ReservarMesa> createState() => _ReservarMesaState();
}

class _ReservarMesaState extends State<ReservarMesa> {
  @override
  Widget build(BuildContext context) {
    //AÑADO PADDING
    return Padding(
      padding: const EdgeInsets.all(16),
      //WIDGET QUE CONVIERTE EL CONTAINER EN BOTON
      child: GestureDetector(
        onTap: () {
          Navigator.push(context, MaterialPageRoute(builder: (context) => LoginScreen()));
        },
        child: Container(
            width: double.infinity,
          decoration: BoxDecoration(
            color: AppColors.background,
            border: Border.all(color: AppColors.gold),
            borderRadius: BorderRadius.circular(16),
             ),
             child: Column(
              children: [
                //ICONO DEL QR
              Icon(Icons.table_bar_rounded, size: 100, color: AppColors.iconPrimary,),
              //BOTON DE QR SCAN
              Text("RESERVA YA", style: TextStyle(
                fontSize: 32, color: AppColors.textPrimary
              ),)
              ],
              
             ),
        ),
      ),
    );
  }
}
import 'package:flutter/material.dart';
import 'package:frontend/core/colors_style.dart';

class CodigoQr extends StatefulWidget {
  const CodigoQr({super.key});

  @override
  State<CodigoQr> createState() => _CodigoQrState();
}

class _CodigoQrState extends State<CodigoQr> {
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
             child: Column(
              children: [
                //ICONO DEL QR
              Icon(Icons.qr_code_sharp, size: 100, color: AppColors.iconPrimary,),
              //BOTON DE QR SCAN
              Text("QR", style: TextStyle(
                fontSize: 32, color: AppColors.textPrimary, fontWeight: FontWeight.bold
              ),)
              ],
              
             ),
        ),
      ),
    );
  }
}
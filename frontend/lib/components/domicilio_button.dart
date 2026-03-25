import 'package:flutter/material.dart';
import 'package:frontend/core/colors_style.dart';
import 'package:frontend/screens/login_screen.dart';

class DomicilioButton extends StatefulWidget {
  const DomicilioButton({super.key});

  @override
  State<DomicilioButton> createState() => _DomicilioButtonState();
}

class _DomicilioButtonState extends State<DomicilioButton> {
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
             child: Row(
              children: [
                //ICONO DE A DOMICILIO
              Icon(Icons.motorcycle, size: 150, color: AppColors.iconPrimary,),
              //BOTON DE PEDIR A DOMICILIO O REOCOGER
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text("A DOMICILIO", style: TextStyle(
                    fontSize: 25, color: AppColors.textPrimary, fontWeight: FontWeight.bold
                  ),),
                  const SizedBox(height: 8,),
                  Text("A RECOGER", style: TextStyle(
                    fontSize: 25, color: AppColors.textPrimary, fontWeight: FontWeight.bold
                  ),)
                ],
              )
              ],
              
             ),
        ),
      ),
    );
  }
}
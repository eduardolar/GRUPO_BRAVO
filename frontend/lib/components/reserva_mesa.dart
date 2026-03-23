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
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: AppColors.background,
            border: Border.all(color: AppColors.gold),
            borderRadius: BorderRadius.circular(16),
             ),
          child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
               children: [
                Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Reserva ya tu mesa", style: TextStyle(
                      fontSize: 20,
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.bold
                    ),
                    ),
          
                    const SizedBox(height: 4,),
          
                    Text("Sin esperas", style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary
                    ),)
                  ],
                ),
          
                Center(
                  child: SizedBox(
                    height: 48,
                  child: ElevatedButton(onPressed: ( ) {
                  
                  },
                   style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.button,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadiusGeometry.circular(8)
                    )
                  ),
                  child: const Text("Reservar", style: TextStyle(
                    fontSize: 15,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.bold
                  ),)),
                )
                )
               ]
          ),
        ),
      );
    
  }
}
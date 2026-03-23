import 'package:flutter/material.dart';
import 'package:frontend/components/codigo_qr.dart';
import 'package:frontend/components/domicilio_button.dart';
import 'package:frontend/components/reserva_mesa.dart';
import 'package:frontend/core/colors_style.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
Widget build(BuildContext context) {
  return Padding(
    padding: const EdgeInsets.all(16),
    child: Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color:AppColors.gold, width: 1)
      ),
      
      child: Scaffold(
        backgroundColor: Colors.transparent, 
        //APP BAR CON EL TITULO DE LA APLICACIÓN
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: const Icon(Icons.room_service, color: AppColors.button, size: 28),
          title: const Text(
            "Tu Restaurante",
            style: TextStyle(color: AppColors.textPrimary, fontSize: 20),
          ),
          shape: Border(
            bottom: BorderSide(
              color:AppColors.line,
              width: 0.5
            )
          ),
        ),
        body: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                //TEXTO DE ARRIBA DE LA PAGINA 
                const Text(
                  "Bienvenido",
                  style: TextStyle(
                    fontSize: 32,
                    fontFamily: 'PlayfairDisplay',
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  "Selecciona una opción:",
                  style: TextStyle(
                    fontSize: 16,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 30),
                SizedBox(
                  width: double.infinity,
                  height: 200,
                  child: CodigoQr(),
                ),
                SizedBox(
                  width: double.infinity,
                  height: 200,
                  child: DomicilioButton(),
                ),
                SizedBox(height: 30),
                 SizedBox(
                  width: double.infinity,
                  height: 200,
                  child: ReservaMesa(),
                )
                
              ],
            ),
          ),
        ),
      ),
    ),
  );
}}
import 'package:flutter/material.dart';
import 'package:frontend/core/colors_style.dart';

class ForgottenPassword extends StatefulWidget {
  const ForgottenPassword({super.key});

  @override
  State<ForgottenPassword> createState() => _ForgottenPasswordState();
}

class _ForgottenPasswordState extends State<ForgottenPassword> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: appBarLogin(),
      body: Column(
        children: [
          Spacer(),
          _customInput(label: "Correo electrónico", icon: Icons.mail),
          Padding(
            padding: EdgeInsets.only(top: 20,),

            child: ElevatedButton(
              onPressed: () {},
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.button,
                foregroundColor:
                    AppColors.background, // Texto oscuro sobre fondo dorado
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
              ),
              child: Text(
                "Cambiar contraseña",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
            
          ),
          Spacer()
        ],
      ),
    );
  }
}

Widget _customInput({
  required String label,
  required IconData icon,
  TextInputType keyboardType = TextInputType.text,
}) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 20),
    child: TextFormField(
      keyboardType: keyboardType,
      style: const TextStyle(color: AppColors.textPrimary),
      decoration: InputDecoration(
        prefixIcon: Icon(icon, color: AppColors.iconDetail), // Icono Dorado
        labelText: label,
        labelStyle: const TextStyle(color: AppColors.textSecundary),
        filled: true,
        fillColor: AppColors.panel, // Fondo Gris muy oscuro
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: const BorderSide(color: AppColors.line), // Borde sutil
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: const BorderSide(
            color: AppColors.button,
            width: 2,
          ), // Borde dorado al escribir
        ),
        errorStyle: const TextStyle(color: AppColors.error),
      ),
    ),
  );
}

AppBar appBarLogin() {
  return AppBar(
    backgroundColor: AppColors.panel,
    elevation: 0,
    title: Text("NombreRestaurante", style: TextStyle(color: Colors.black)),
    centerTitle: true,
  );
}

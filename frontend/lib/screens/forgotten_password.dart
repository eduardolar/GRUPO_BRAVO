import 'package:flutter/material.dart';
import 'package:frontend/components/entrada_texto.dart';
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
          Padding(
            padding: const EdgeInsets.all(16),
            child: EntradaTexto(etiqueta: "Correo electrónico", icono: Icons.mail),
          ),
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



AppBar appBarLogin() {
  return AppBar(
    backgroundColor: AppColors.panel,
    elevation: 0,
    title: Text("NombreRestaurante", style: TextStyle(color: Colors.black)),
    centerTitle: true,
  );
}

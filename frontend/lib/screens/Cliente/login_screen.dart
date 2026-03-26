import 'package:flutter/material.dart';
import 'package:frontend/core/colors_style.dart';
import 'package:frontend/screens/Cliente/forgotten_password.dart';
import 'package:frontend/screens/Cliente/menu_screen.dart';
import 'package:frontend/screens/Cliente/register_screen.dart';
import 'package:frontend/components/Cliente/entrada_texto.dart';

// ignore: camel_case_types
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _MyWidgetState();
}

class _MyWidgetState extends State<LoginScreen> {

  bool _obscureText = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: appBarLogin(),
      body: bodyLogin(),
    );
  }

  Padding bodyLogin() {

    return Padding(
      padding: const EdgeInsets.all(8),
      child: Column(
        children: [
          Spacer(),
          Padding(
            padding: const EdgeInsets.only(bottom: 90),
            child: Text(
              "Iniciar sesión",
              style: TextStyle(color: AppColors.textPrimary),
            ),
          ),
          Column(
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 16, left: 16, right: 16),
                child: EntradaTexto(etiqueta: "Correo electrónico", icono: Icons.mail,)
              ),
              Padding(
                padding: const EdgeInsets.only(top: 16, left: 16, right: 16),
                child: EntradaTexto(etiqueta: 'Contraseña', icono: Icons.visibility_off, esContrasena: true, mostrarTexto: true,)
              ),
              TextButton(
                onPressed: () {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => ForgottenPassword()));
                },
                child: Text(
                  "¿Has olvidado la contraseña?",
                  style: TextStyle(fontSize: 10),
                ),
              ),
            ],
          ),
           Container(
                  height: 55,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(15),
                    boxShadow: const [
                      BoxShadow(
                        color: AppColors.shadow,
                        blurRadius: 10,
                        offset: Offset(0, 5),
                      ),
                    ],
                  ),
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.button,
                      foregroundColor: AppColors
                          .background, // Texto oscuro sobre fondo dorado
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                    ),
                    onPressed: () {
                      Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => MenuScreen()),  // Direccionar a la pantalla de menú
                  );
                        
                      }
                    ,
                    child: const Text(
                      "IINICIAR SESIÓN",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
          Spacer(),
          Row(
            children: [
              Spacer(),
              Text("¿No tienes cuenta?"),
              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => RegisterScreen()),  // Direccionar a la pantalla de registro
                  );
                },
                child: Text("Regístrate"),
              ),
              Spacer(),
            ],
          ),
          Spacer(),
        ],
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

}

import 'package:flutter/material.dart';
import 'package:frontend/core/colors_style.dart';
import 'package:frontend/screens/forgotten_password.dart';
import 'package:frontend/screens/register.dart';

class loginScreen extends StatefulWidget {
  const loginScreen({super.key});

  @override
  State<loginScreen> createState() => _MyWidgetState();
}

class _MyWidgetState extends State<loginScreen> {

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
                child: _customInput(label: "Correo electrónico", icon: Icons.mail)
              ),
              Padding(
                padding: const EdgeInsets.only(top: 16, left: 16, right: 16),
                child: _customPasswordInput(label: "contraseña")
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
                    MaterialPageRoute(builder: (context) => loginScreen()),  // Direccionar a la pantalla de menú
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

  Widget _customPasswordInput({required String label}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: TextFormField(
        obscureText: _obscureText,
        style: const TextStyle(color: AppColors.textPrimary),
        decoration: InputDecoration(
          prefixIcon: const Icon(
            Icons.lock_outline,
            color: AppColors.iconDetail,
          ),
          suffixIcon: IconButton(
            icon: Icon(
              _obscureText
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined,
              color: AppColors.iconPrimary,
            ),
            onPressed: () => setState(() => _obscureText = !_obscureText),
          ),
          labelText: label,
          labelStyle: const TextStyle(color: AppColors.textSecundary),
          filled: true,
          fillColor: AppColors.panel,
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: const BorderSide(color: AppColors.line),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: const BorderSide(color: AppColors.button, width: 2),
          ),
          errorStyle: const TextStyle(color: AppColors.error),
        ),
      ),
    );
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
}

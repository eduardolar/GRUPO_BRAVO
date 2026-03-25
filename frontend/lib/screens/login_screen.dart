import 'package:flutter/material.dart';
import 'package:frontend/core/colors_style.dart';
import 'package:frontend/screens/forgotten_password.dart';
import 'package:frontend/screens/menu_screen.dart';
import 'package:frontend/screens/register_screen.dart';
import 'package:frontend/components/entrada_texto.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  // Variable para controlar si se muestra la contraseña o no
  bool _oscurecerContrasena = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: appBarLogin(),
      body: SingleChildScrollView(
        child: SizedBox(
          // Ajustamos el alto para que los Spacers funcionen bien sin desbordar
          height: MediaQuery.of(context).size.height - 100, 
          child: bodyLogin(),
        ),
      ),
    );
  }

  Widget bodyLogin() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Column(
        children: [
          const Spacer(flex: 2),
          
          // --- Cabecera ---
          Text(
            "Iniciar Sesión",
            style: TextStyle(
              color: AppColors.textPrimary, 
              fontSize: 32, 
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            "Bienvenido a NombreRestaurante",
            style: TextStyle(color: Colors.grey, fontSize: 16),
          ),
          
          const Spacer(flex: 2),

          // --- Inputs ---
          EntradaTexto(
            etiqueta: "Correo electrónico", 
            icono: Icons.mail_outline,
            tipoTeclado: TextInputType.emailAddress,
          ),
          
          EntradaTexto(
            etiqueta: 'Contraseña', 
            icono: Icons.lock_outline,
            esContrasena: true, 
            // Usamos nuestra variable de estado
            mostrarTexto: _oscurecerContrasena, 
            // Función para cambiar el estado al tocar el ojo
            alPresionarIcono: () {
              setState(() {
                _oscurecerContrasena = !_oscurecerContrasena;
              });
            },
          ),
          
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(builder: (context) => const ForgottenPassword()));
              },
              child: Text(
                "¿Olvidaste tu contraseña?",
                style: TextStyle(color: AppColors.button, fontWeight: FontWeight.w600),
              ),
            ),
          ),

          const Spacer(flex: 1),

          // --- Botón Principal ---
          _botonLogin(),

          const Spacer(flex: 3),

          // --- Footer ---
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text("¿Aún no tienes cuenta?", style: TextStyle(color: Colors.white70)),
              TextButton(
                onPressed: () {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const RegisterScreen()));
                },
                child: Text(
                  "Regístrate",
                  style: TextStyle(color: AppColors.button, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _botonLogin() {
    return Container(
      width: double.infinity,
      height: 55,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: AppColors.button.withOpacity(0.2),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.button,
          foregroundColor: AppColors.background,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          elevation: 0,
        ),
        onPressed: () {
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const MenuScreen()));
        },
        child: const Text(
          "ENTRAR",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 2),
        ),
      ),
    );
  }

  AppBar appBarLogin() {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      centerTitle: true,
    );
  }
}
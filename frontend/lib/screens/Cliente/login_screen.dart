import 'package:flutter/material.dart';
import 'package:frontend/screens/Administrador/admin_home_screen.dart';
import 'package:provider/provider.dart';
import 'package:frontend/core/colors_style.dart';
import 'package:frontend/screens/Cliente/forgotten_password.dart';
import 'package:frontend/screens/Cliente/menu_screen.dart';
import 'package:frontend/screens/Cliente/register_screen.dart';
import 'package:frontend/components/Cliente/entrada_texto.dart';
import 'package:frontend/providers/auth_provider.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  // Variable para controlar si se muestra la contraseña o no
  bool _oscurecerContrasena = true;

  // Controladores para los campos de texto
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  // Variable para mostrar loading
  bool _isLoading = false;

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
              letterSpacing: 1.5,
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
            controlador: _emailController,
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
            controlador: _passwordController,
          ),

          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ForgottenPassword(),
                  ),
                );
              },
              child: Text(
                "¿Olvidaste tu contraseña?",
                style: TextStyle(
                  color: AppColors.button,
                  fontWeight: FontWeight.w600,
                ),
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
              const Text(
                "¿Aún no tienes cuenta?",
                style: TextStyle(color: Colors.white70),
              ),
              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const RegisterScreen(),
                    ),
                  );
                },
                child: Text(
                  "Regístrate",
                  style: TextStyle(
                    color: AppColors.button,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              ElevatedButton(
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
                    MaterialPageRoute(builder: (context) => MenuAdministrador()),  // Direccionar a la pantalla de menú
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
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          elevation: 0,
        ),
        onPressed: _isLoading ? null : _iniciarSesion,
        child: _isLoading
            ? const CircularProgressIndicator(color: Colors.white)
            : const Text(
                "ENTRAR",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  letterSpacing: 2,
                ),
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

  Future<void> _iniciarSesion() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor, completa todos los campos')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final success = await authProvider.iniciarSesion(email, password);

      if (success && mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const MenuScreen()),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
}

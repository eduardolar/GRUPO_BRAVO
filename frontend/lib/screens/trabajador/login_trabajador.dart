import 'package:flutter/material.dart';
import 'package:frontend/components/Cliente/entrada_texto.dart';
import 'package:frontend/core/colors_style.dart';
import 'package:frontend/providers/auth_provider.dart';
import 'package:frontend/screens/Cliente/menu_screen.dart';
import 'package:frontend/screens/home_screen_trabajador.dart';
import 'package:provider/provider.dart';

class LoginTrabajador extends StatefulWidget {
  const LoginTrabajador({super.key});

  @override
  State<LoginTrabajador> createState() => _LoginTrabajadorState();
}

class _LoginTrabajadorState extends State<LoginTrabajador> {
  bool _oscurecerContrasena = true;

  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: appBarLogin(),
      body: SingleChildScrollView(
        child: SizedBox(
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
            mostrarTexto: _oscurecerContrasena,
            alPresionarIcono: () {
              setState(() {
                _oscurecerContrasena = !_oscurecerContrasena;
              });
            },
            controlador: _passwordController,
          ),

          const Spacer(flex: 1),

          _botonLogin(),

          const Spacer(flex: 3),
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
          MaterialPageRoute(builder: (context) => const HomeTrabajador()),
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

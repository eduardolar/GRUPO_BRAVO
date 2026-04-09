import 'package:flutter/material.dart';
import 'package:frontend/components/Cliente/entrada_texto.dart';
import 'package:frontend/core/colors_style.dart';
import 'package:frontend/providers/auth_provider.dart';
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
      appBar: _appBarLogin(),
      body: SingleChildScrollView(
        child: SizedBox(
          height: MediaQuery.of(context).size.height - 100,
          child: _bodyLogin(),
        ),
      ),
    );
  }

  Widget _bodyLogin() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Column(
        children: [
          const Spacer(flex: 2),

          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.gold, width: 1.5),
            ),
            child: const Icon(
              Icons.restaurant,
              color: AppColors.gold,
              size: 28,
            ),
          ),

          const SizedBox(height: 20),

          const Text(
            "Iniciar Sesión",
            style: TextStyle(
              fontFamily: 'Playfair Display',
              color: Color(0xFF2D2D2D),
              fontSize: 30,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),

          const SizedBox(height: 8),

          Text(
            "BIENVENIDO A NOMBRERESTAURANTE",
            style: TextStyle(
              color: AppColors.gold.withOpacity(0.7),
              fontSize: 10,
              letterSpacing: 2.5,
              fontWeight: FontWeight.w400,
            ),
          ),

          const SizedBox(height: 20),

          Row(
            children: [
              const Expanded(child: Divider(color: Color(0xFFE0DBD3))),
              Container(
                width: 60,
                height: 1.5,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.transparent,
                      AppColors.gold,
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
              const Expanded(child: Divider(color: Color(0xFFE0DBD3))),
            ],
          ),

          const Spacer(flex: 2),

          _inputWrapper(
            child: EntradaTexto(
              etiqueta: "Correo electrónico",
              icono: Icons.mail_outline,
              tipoTeclado: TextInputType.emailAddress,
              controlador: _emailController,
            ),
          ),

          const SizedBox(height: 12),

          _inputWrapper(
            child: EntradaTexto(
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
          ),

          const Spacer(flex: 1),

          _botonLogin(),

          const Spacer(flex: 3),
        ],
      ),
    );
  }

  Widget _inputWrapper({required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.panel,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.line),
      ),
      child: child,
    );
  }

  Widget _botonLogin() {
    return Container(
      width: double.infinity,
      height: 55,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        // Borde dorado sutil — 10%
        border: Border.all(color: AppColors.gold, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: AppColors.gold.withOpacity(0.15),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.button,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(13),
          ),
          elevation: 0,
        ),
        onPressed: _isLoading ? null : _iniciarSesion,
        child: _isLoading
            ? const CircularProgressIndicator(
                color: AppColors.gold,
                strokeWidth: 2,
              )
            : const Text(
                "ENTRAR",
                style: TextStyle(
                  fontFamily: 'Playfair Display',
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  letterSpacing: 3,
                ),
              ),
      ),
    );
  }

  AppBar _appBarLogin() {
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

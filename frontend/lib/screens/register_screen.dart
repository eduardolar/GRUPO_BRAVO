import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:frontend/screens/login_screen.dart';
import '../core/colors_style.dart';
import '../components/entrada_texto.dart';
import '../components/crear_cuenta_button.dart';
import '../providers/auth_provider.dart';
import 'menu_screen.dart';
<<<<<<< HEAD:frontend/lib/screens/Cliente/register_screen.dart
import '../core/colors_style.dart';
import '../components/entrada_texto.dart';
import '../components/crear_cuenta_button.dart'; // Importamos el nuevo botón
import 'home_screen.dart';
=======
import 'package:provider/provider.dart';
import 'package:frontend/screens/login_screen.dart';
import 'core/colors_style.dart';
import 'components/entrada_texto.dart';
import 'components/crear_cuenta_button.dart';
import 'providers/auth_provider.dart';
import 'menu_screen.dart';
>>>>>>> origin/main:frontend/lib/screens/register_screen.dart

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _ocultarPass = true;

  // Controladores para los campos
  final TextEditingController _nombreController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _telefonoController = TextEditingController();
  final TextEditingController _direccionController = TextEditingController();

  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.iconPrimary),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 30),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Center(
                  child: Text(
                    "Regístrate",
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 40),

                // Inputs reutilizables con validación
                EntradaTexto(
                  etiqueta: "Nombre",
                  icono: Icons.person_outline,
                  controlador: _nombreController,
                  validador: (v) => v!.isEmpty ? "Campo requerido" : null,
                ),

                EntradaTexto(
                  etiqueta: "Contraseña",
                  icono: Icons.lock_outline,
                  esContrasena: true,
                  mostrarTexto: _ocultarPass,
                  alPresionarIcono: () =>
                      setState(() => _ocultarPass = !_ocultarPass),
                  controlador: _passwordController,
                  validador: (v) =>
                      v!.length < 6 ? "Mínimo 6 caracteres" : null,
                ),

                EntradaTexto(
                  etiqueta: "Correo electrónico",
                  icono: Icons.email_outlined,
                  tipoTeclado: TextInputType.emailAddress,
                  controlador: _emailController,
                  validador: (v) => !v!.contains("@") ? "Email inválido" : null,
                ),

                EntradaTexto(
                  etiqueta: "Teléfono",
                  icono: Icons.phone_android_outlined,
                  tipoTeclado: TextInputType.phone, // Abre el teclado numérico
                  controlador: _telefonoController,
                  validador: (valor) {
                    if (valor == null || valor.isEmpty) {
                      return "Por favor, introduce tu teléfono";
                    }
                    // Validación básica: que tenga al menos 7-9 dígitos
                    if (valor.length < 7) {
                      return "Número de teléfono incompleto";
                    }
                    return null;
                  },
                ),

                // Campo de Dirección
                EntradaTexto(
                  etiqueta: "Dirección",
                  icono: Icons.map_outlined,
                  tipoTeclado: TextInputType
                      .streetAddress, // Optimiza el teclado para direcciones
                  controlador: _direccionController,
                  validador: (valor) {
                    if (valor == null || valor.isEmpty) {
                      return "La dirección es obligatoria para el envío";
                    }
                    if (valor.length < 5) {
                      return "Especifica una dirección más detallada";
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 40),

                CrearCuentaButton(
                  alPresionar: _isLoading ? null : _registrarse,
                  texto: _isLoading ? "CREANDO..." : "CREAR CUENTA",
                ),

                const SizedBox(height: 20),

                TextButton(
                  onPressed: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const LoginScreen(),
                      ),
                    );
                  },
                  child: const Text(
                    "¿Ya tienes cuenta? Volver",
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _registrarse() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isLoading = true);

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      await authProvider.registrarse(
        nombre: _nombreController.text.trim(),
        email: _emailController.text.trim(),
        contrasena: _passwordController.text,
        telefono: _telefonoController.text.trim(),
        direccion: _direccionController.text.trim(),
      );

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const MenuScreen()),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
}

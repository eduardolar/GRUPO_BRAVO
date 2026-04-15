import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/colors_style.dart';
import '../../components/Cliente/entrada_texto.dart';
import '../../components/Cliente/crear_cuenta_button.dart';
import '../../providers/auth_provider.dart';
import 'login_screen.dart';
import 'menu_screen.dart';
import 'reservar_mesa_screen.dart';

class RegisterScreen extends StatefulWidget {
  final DestinoLogin destino;

  const RegisterScreen({super.key, this.destino = DestinoLogin.menu});

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
                  validador: _validarContrasena,
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
                        builder: (context) =>
                            LoginScreen(destino: widget.destino),
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
        final pantallaDestino = widget.destino == DestinoLogin.reservar
            ? const ReservarMesaScreen()
            : const MenuScreen();
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => pantallaDestino),
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

  String? _validarContrasena(String? v) {
    if (v == null || v.isEmpty) {
      return "Campo requerido";
    }
    if (v.length < 8) {
      return "Mínimo 8 caracteres";
    }
    if (!RegExp(r'[A-Z]').hasMatch(v)) {
      return "Debe tener al menos una mayúscula";
    }
    if (!RegExp(r'[0-9]').hasMatch(v)) {
      return "Debe tener al menos un número";
    }
    if (!RegExp(r'[!@#$%^&*(),.?\":{}|<>_\-\\[\]/+=;]').hasMatch(v)) {
      return "Debe tener un carácter especial";
    }
    return null;
  }
}

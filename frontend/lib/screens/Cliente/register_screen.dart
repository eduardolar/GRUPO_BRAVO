import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

// Estilos y Providers
import '../../core/colors_style.dart';
import '../../providers/auth_provider.dart';

// Componentes
import '../../components/Cliente/entrada_texto.dart';

// Pantallas
import 'package:frontend/screens/cliente/login_screen.dart';
import 'package:frontend/screens/cliente/verificacion_screen.dart';

class RegisterScreen extends StatefulWidget {
  final DestinoLogin destino;

  const RegisterScreen({super.key, this.destino = DestinoLogin.menu});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _ocultarPass = true;
  bool _isLoading = false;

  // Controladores
  final TextEditingController _nombreController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _telefonoController = TextEditingController();
  final TextEditingController _direccionController = TextEditingController();

  @override
  void dispose() {
    _nombreController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _telefonoController.dispose();
    _direccionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 1. Fondo Inmersivo
          Positioned.fill(
            child: Image.asset(
              'assets/images/Bravo restaurante.jpg',
              fit: BoxFit.cover,
            ),
          ),

          // 2. Overlay de Contraste (AppColors.shadow)
          Positioned.fill(
            child: Container(
              color: AppColors.shadow.withValues(alpha: 0.85),
            ),
          ),

          // 3. Formulario
          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 500),
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 20),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        _buildHeader(),
                        const SizedBox(height: 30),
                        _buildInputs(),
                        const SizedBox(height: 40),
                        _buildRegisterButton(),
                        _buildFooter(),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Botón Volver
          Positioned(
            top: 20,
            left: 10,
            child: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        const Text(
          "Crea tu Cuenta",
          style: TextStyle(
            fontFamily: 'Playfair Display',
            color: Colors.white,
            fontSize: 36,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 10),
        Container(height: 2, width: 40, color: AppColors.button),
        const SizedBox(height: 15),
        Text(
          "Completa tus datos para empezar",
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 15),
        ),
      ],
    );
  }

  Widget _buildInputs() {
    return Column(
      children: [
        EntradaTexto(
          etiqueta: "Nombre completo",
          icono: Icons.person_outline,
          controlador: _nombreController,
          validador: (v) => v!.isEmpty ? "Campo requerido" : null,
        ),
        const SizedBox(height: 15),
        EntradaTexto(
          etiqueta: "Correo electrónico",
          icono: Icons.email_outlined,
          tipoTeclado: TextInputType.emailAddress,
          controlador: _emailController,
          validador: (v) => !v!.contains("@") ? "Email inválido" : null,
        ),
        const SizedBox(height: 15),
        EntradaTexto(
          etiqueta: "Contraseña",
          icono: Icons.lock_outline,
          esContrasena: true,
          mostrarTexto: _ocultarPass,
          alPresionarIcono: () => setState(() => _ocultarPass = !_ocultarPass),
          controlador: _passwordController,
          validador: _validarContrasena,
        ),
        const SizedBox(height: 15),
        EntradaTexto(
          etiqueta: "Teléfono",
          icono: Icons.phone_android_outlined,
          tipoTeclado: TextInputType.phone,
          controlador: _telefonoController,
          validador: (v) => v!.length < 7 ? "Teléfono incompleto" : null,
        ),
        const SizedBox(height: 15),
        EntradaTexto(
          etiqueta: "Dirección de entrega",
          icono: Icons.map_outlined,
          tipoTeclado: TextInputType.streetAddress,
          controlador: _direccionController,
          validador: (v) => v!.isEmpty ? "La dirección es obligatoria" : null,
        ),
      ],
    );
  }

  Widget _buildRegisterButton() {
    return SizedBox(
      width: double.infinity,
      height: 55,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.button,
          foregroundColor: Colors.white,
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
          elevation: 0,
        ),
        onPressed: _isLoading ? null : _registrarse,
        child: _isLoading
            ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
            : const Text("CREAR CUENTA", style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 2)),
      ),
    );
  }

  Widget _buildFooter() {
    return Column(
      children: [
        const SizedBox(height: 25),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text("¿Ya tienes cuenta?", style: TextStyle(color: Colors.white60)),
            TextButton(
              onPressed: () => Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => LoginScreen(destino: widget.destino)),
              ),
              child: const Text(
                "Inicia Sesión",
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, decoration: TextDecoration.underline),
              ),
            ),
          ],
        ),
      ],
    );
  }

  String? _validarContrasena(String? v) {
    if (v == null || v.isEmpty) return "Campo requerido";
    if (v.length < 8) return "Mínimo 8 caracteres";
    if (!RegExp(r'[A-Z]').hasMatch(v)) return "Falta una mayúscula";
    if (!RegExp(r'[0-9]').hasMatch(v)) return "Falta un número";
    return null;
  }

  void _registrarse() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      
      // Llamada al servicio de registro
      await authProvider.registrarse(
        nombre: _nombreController.text.trim(),
        email: _emailController.text.trim(),
        contrasena: _passwordController.text,
        telefono: _telefonoController.text.trim(),
        direccion: _direccionController.text.trim(),
      );

      // --- CAMBIO CLAVE: Redirección a Verificación ---
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => VerificationScreen(
              email: _emailController.text.trim(),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}
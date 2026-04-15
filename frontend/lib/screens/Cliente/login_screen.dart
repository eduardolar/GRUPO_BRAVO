import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

// Estilos y Providers
import 'package:frontend/core/colors_style.dart';
import 'package:frontend/providers/auth_provider.dart';
import 'package:frontend/models/usuario_model.dart';

// Pantallas
import 'package:frontend/screens/Cliente/forgotten_password.dart';
import 'package:frontend/screens/Cliente/menu_screen.dart';
import 'package:frontend/screens/Cliente/register_screen.dart';
import 'package:frontend/screens/Cliente/reservar_mesa_screen.dart';
import 'package:frontend/screens/home_screen_trabajador.dart';
import 'package:frontend/screens/admin/home_screen_admin.dart';
import 'package:frontend/screens/super_admin/home_screen_super_admin.dart';

// Componentes
import 'package:frontend/components/Cliente/entrada_texto.dart';

enum DestinoLogin { menu, reservar }

class LoginScreen extends StatefulWidget {
  final DestinoLogin destino;

  const LoginScreen({super.key, this.destino = DestinoLogin.menu});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _oscurecerContrasena = true;
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black, // Fondo base negro para evitar destellos blancos
      body: Stack(
        children: [
          // 1. IMAGEN DE FONDO (Logo/Restaurante)
          Positioned.fill(
            child: Image.asset(
              'assets/images/Bravo restaurante.jpg',
              fit: BoxFit.cover,
            ),
          ),

          // 2. FILTRO OSCURO (Capa de legibilidad)
          Positioned.fill(
            child: Container(
              color: Colors.black.withOpacity(0.75), // Ajusta la opacidad según necesites
            ),
          ),

          // 3. CONTENIDO
          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 450),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 30),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildHeader(),
                      const SizedBox(height: 40),
                      _buildForm(),
                      _buildForgotPassword(),
                      const SizedBox(height: 40),
                      _buildActionButtons(),
                    ],
                  ),
                ),
              ),
            ),
          ),
          
          // Botón volver
          Positioned(
            top: 40,
            left: 10,
            child: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
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
          "Iniciar Sesión",
          style: TextStyle(
            fontFamily: 'Playfair Display',
            color: Colors.white,
            fontSize: 38,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 10),
        Container(
          height: 1.5,
          width: 50,
          color: AppColors.button,
        ),
        const SizedBox(height: 15),
        const Text(
          "Bienvenido a Restaurante Bravo",
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white70,
            fontSize: 15,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }

  Widget _buildForm() {
    return Column(
      children: [
        // Nota: Asegúrate de que el componente 'EntradaTexto' tenga colores claros para los labels
        EntradaTexto(
          etiqueta: "Correo electrónico",
          icono: Icons.mail_outline,
          tipoTeclado: TextInputType.emailAddress,
          controlador: _emailController,
        ),
        const SizedBox(height: 15),
        EntradaTexto(
          etiqueta: 'Contraseña',
          icono: Icons.lock_outline,
          esContrasena: true,
          mostrarTexto: _oscurecerContrasena,
          alPresionarIcono: () {
            setState(() => _oscurecerContrasena = !_oscurecerContrasena);
          },
          controlador: _passwordController,
        ),
      ],
    );
  }

  Widget _buildForgotPassword() {
    return Align(
      alignment: Alignment.centerRight,
      child: TextButton(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ForgottenPassword()),
        ),
        child: Text(
          "¿Olvidaste tu contraseña?",
          style: TextStyle(
            color: Colors.white.withOpacity(0.8),
            fontWeight: FontWeight.w400,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 55,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.button,
              foregroundColor: Colors.white,
              elevation: 5,
              shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
            ),
            onPressed: _isLoading ? null : _iniciarSesion,
            child: _isLoading
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Text(
                    "ENTRAR",
                    style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 3),
                  ),
          ),
        ),
        const SizedBox(height: 30),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text("¿Aún no tienes cuenta?", style: TextStyle(color: Colors.white60)),
            TextButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => RegisterScreen(destino: widget.destino)),
              ),
              child: Text(
                "Regístrate",
                style: TextStyle(color: AppColors.button, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // Lógica de _iniciarSesion y navegación se mantiene igual que antes...
  Future<void> _iniciarSesion() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    if (email.isEmpty || password.isEmpty) {
      _showSnackBar('Por favor, completa todos los campos');
      return;
    }
    setState(() => _isLoading = true);
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final success = await authProvider.iniciarSesion(email, password);
      if (success && mounted) {
        final usuario = authProvider.usuarioActual!;
        _navigateToRoleHome(usuario);
      }
    } catch (e) {
      if (mounted) _showSnackBar('Error: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _navigateToRoleHome(Usuario usuario) {
    Widget pantallaDestino;
    switch (usuario.rol) {
      case RolUsuario.trabajador: pantallaDestino = const HomeTrabajador(); break;
      case RolUsuario.administrador: pantallaDestino = const HomeScreenAdmin(); break;
      case RolUsuario.superadministrador: pantallaDestino = const HomeScreenSuperAdmin(); break;
      case RolUsuario.cliente:
      default:
        pantallaDestino = widget.destino == DestinoLogin.reservar ? const ReservarMesaScreen() : const MenuScreen();
        break;
    }
    Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => pantallaDestino), (route) => false);
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: AppColors.error));
  }
}
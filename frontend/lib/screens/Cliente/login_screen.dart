import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:frontend/core/app_routes.dart';
import 'package:frontend/core/colors_style.dart';
import 'package:frontend/providers/auth_provider.dart';
import 'package:frontend/models/usuario_model.dart';
import 'package:frontend/models/destino_login.dart';

import 'package:frontend/screens/cliente/forgotten_password.dart';
import 'package:frontend/screens/cliente/menu_screen.dart';
import 'package:frontend/screens/cliente/register_screen.dart';
import 'package:frontend/screens/cliente/reservar_mesa_screen.dart';
import 'package:frontend/screens/cocinero/home_screen_cocinero.dart';
import 'package:frontend/screens/home_screen_trabajador.dart';
import 'package:frontend/screens/super_admin/seleccionar_restaurante_screen.dart';
import 'package:frontend/screens/cliente/seleccionar_restaurante_screen.dart' as sel_rest_cliente;
import 'package:frontend/screens/Administrador/admin_home_screen.dart';
import 'package:frontend/screens/super_admin/activar_cuenta_screen.dart';

import 'package:frontend/components/Cliente/entrada_texto.dart';
import 'package:frontend/components/Cliente/auth_scaffold.dart';
import 'package:frontend/components/Cliente/auth_header.dart';
import 'package:frontend/components/Cliente/primary_button.dart';

// Import para la verificación del 2FA
import 'package:frontend/screens/cliente/verificacion_screen.dart';

class LoginScreen extends StatefulWidget {
  final DestinoLogin destino;
  final bool mostrarActivarCuenta;

  const LoginScreen({
    super.key,
    this.destino = DestinoLogin.menu,
    this.mostrarActivarCuenta = false,
  });

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
    return ClienteAuthScaffold(
      maxWidth: 450,
      padding: const EdgeInsets.symmetric(horizontal: 30),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 60),
          const AuthHeader(
            titulo: 'Iniciar Sesión',
            subtitulo: 'Bienvenido a Restaurante Bravo',
          ),
          const SizedBox(height: 40),
          _buildForm(),
          _buildForgotPassword(),
          const SizedBox(height: 40),
          _buildActionButtons(),
        ],
      ),
    );
  }

  Widget _buildForm() {
    return Column(
      children: [
        EntradaTexto(
          etiqueta: 'Correo electrónico',
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
          alPresionarIcono: () =>
              setState(() => _oscurecerContrasena = !_oscurecerContrasena),
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
          AppRoute.slide(const ForgottenPassword()),
        ),
        child: Text(
          '¿Olvidaste tu contraseña?',
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
        PrimaryButton(
          label: 'ENTRAR',
          isLoading: _isLoading,
          onPressed: _iniciarSesion,
        ),
        const SizedBox(height: 30),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('¿Aún no tienes cuenta?',
                style: TextStyle(color: Colors.white60)),
            TextButton(
              onPressed: () => Navigator.push(
                context,
                AppRoute.slide(RegisterScreen(destino: widget.destino)),
              ),
              child: const Text(
                'Regístrate',
                style: TextStyle(
                    color: AppColors.button, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        if (widget.mostrarActivarCuenta) ...[
          const SizedBox(height: 16),
          TextButton.icon(
            onPressed: () => Navigator.push(
              context,
              AppRoute.slide(const ActivarCuentaScreen()),
            ),
            icon: const Icon(Icons.vpn_key_outlined,
                size: 16, color: Colors.white54),
            label: const Text(
              '¿Eres nuevo empleado? Activa tu cuenta',
              style: TextStyle(color: Colors.white54, fontSize: 13),
            ),
          ),
        ],
      ],
    );
  }

  // --- FUNCIÓN DE LOGICA DE INICIO DE SESIÓN CON 2FA ---
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
      
      // 1. Intentamos el login
      final respuesta = await authProvider.iniciarSesion(email, password);

      if (!mounted) return;

      // 2. CASO 2FA: Si la respuesta indica que requiere verificación por correo
      if (respuesta != null && respuesta['requires_2fa'] == true) {
        final emailParaVerificar = respuesta['correo'] ?? email; // Usar el email del formulario si no viene en la respuesta
        _showSnackBar('¡Revisa tu bandeja de entrada! Te hemos enviado un código.', isError: false);

        Navigator.push(
          context,
          AppRoute.slide(VerificacionScreen(
            email: emailParaVerificar,
            esModo2FA: true, // Bandera para que la pantalla sepa que es LOGIN y no registro
          )),
        );
        return;
      }

      // 3. CASO ÉXITO: Si no hay 2FA y el login es directo
      if (authProvider.usuarioActual != null) {
        _navigateToRoleHome(authProvider.usuarioActual!);
      }

    } catch (e) {
      if (mounted) _showSnackBar('Error: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _navigateToRoleHome(Usuario usuario) {
    Widget destino;
    switch (usuario.rol) {
      case RolUsuario.trabajador:
        destino = const HomeTrabajador();
        break;
      case RolUsuario.administrador:
        destino = const MenuAdministrador();
        break;
      case RolUsuario.superadministrador:
        destino = const SeleccionarRestauranteScreen();
        break;
      case RolUsuario.cliente:
        destino = sel_rest_cliente.SeleccionarRestauranteScreen(
          siguiente: widget.destino == DestinoLogin.reservar
              ? const ReservarMesaScreen()
              : const MenuScreen(),
        );
        break;
      case RolUsuario.cocinero:
        destino = const HomeCocinero();
        break;
    }
    Navigator.pushAndRemoveUntil(
      context,
      AppRoute.reveal(destino),
      (route) => false,
    );
  }

void _showSnackBar(String message, {bool isError = true}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message, 
          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)
        ),
        // Si isError es true pinta tu AppColors.error, si es false pinta el verde
        backgroundColor: isError ? AppColors.error : const Color.fromARGB(255, 16, 230, 27),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        margin: const EdgeInsets.all(16),
      ),
    );
  }
}
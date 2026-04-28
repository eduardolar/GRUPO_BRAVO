import 'package:flutter/material.dart';
import 'package:frontend/screens/Administrador/admin_home_screen.dart';
import 'package:frontend/screens/Administrador/admin_menu_screen.dart';
import 'package:frontend/screens/super_admin/activar_cuenta_screen.dart';
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

import 'package:frontend/components/Cliente/entrada_texto.dart';
import 'package:frontend/components/Cliente/auth_scaffold.dart';
import 'package:frontend/components/Cliente/auth_header.dart';
import 'package:frontend/components/Cliente/primary_button.dart';
import 'package:frontend/screens/cliente/totp_login_screen.dart';

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
            color: Colors.white.withValues(alpha: 0.8),
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
              child: Text(
                'Regístrate',
                style: TextStyle(
                    color: AppColors.button, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        // Acceso oculto al panel de administrador
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            foregroundColor: Colors.transparent,
            elevation: 0,
            shape:
                const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
          ),
          onPressed: () => Navigator.push(
            context,
            AppRoute.fade(const MenuAdministrador()),
          ),
          child: null,
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
      if (!mounted) return;
      if (success) {
        _navigateToRoleHome(authProvider.usuarioActual!);
      } else {
        Navigator.push(
          context,
          AppRoute.slide(TotpLoginScreen(destino: widget.destino)),
        );
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
        destino = widget.destino == DestinoLogin.reservar
            ? const ReservarMesaScreen()
            : const MenuScreen();
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

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppColors.error),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:frontend/core/app_routes.dart';
import 'package:frontend/core/app_snackbar.dart';
import 'package:frontend/core/colors_style.dart';
import 'package:frontend/providers/auth_provider.dart';
import 'package:frontend/models/usuario_model.dart';
import 'package:frontend/models/destino_login.dart';

import 'package:frontend/screens/cliente/recuperar_contrasena_screen.dart';
import 'package:frontend/screens/cliente/carta_screen.dart';
import 'package:frontend/screens/cliente/registro_screen.dart';
import 'package:frontend/screens/cliente/reservar_mesa_screen.dart';
import 'package:frontend/screens/cocinero/home_screen_cocinero.dart';
import 'package:frontend/screens/home_screen_trabajador.dart';
import 'package:frontend/screens/super_admin/home_screen_super_admin.dart';
import 'package:frontend/screens/cliente/seleccionar_restaurante_screen.dart'
    as sel_rest_cliente;
import 'package:frontend/screens/Administrador/admin_home_screen.dart';
import 'package:frontend/screens/super_admin/activar_cuenta_screen.dart';

import 'package:frontend/components/Cliente/entrada_texto.dart';
import 'package:frontend/components/Cliente/auth_scaffold.dart';
import 'package:frontend/components/Cliente/auth_header.dart';
import 'package:frontend/components/Cliente/primary_button.dart';

// Import para la verificación del 2FA
import 'package:frontend/screens/cliente/verificacion_screen.dart';

/// Pantalla de inicio de sesión común a todos los roles (cliente, trabajador,
/// cocinero, administrador y superadministrador).
///
/// El backend decide si la cuenta requiere verificación 2FA por correo. Si la
/// requiere, esta pantalla redirige a [VerificacionScreen] en modo 2FA. En caso
/// contrario navega directamente al home propio del rol del usuario mediante
/// [_navigateToRoleHome].
class LoginScreen extends StatefulWidget {
  /// Destino post-login para clientes (carta o reservar mesa).
  /// Se ignora para empleados porque ellos tienen su propio home por rol.
  final DestinoLogin destino;

  /// Si es `true`, muestra el enlace "¿Eres nuevo empleado? Activa tu cuenta",
  /// que abre el flujo de canje de código de invitación enviado por el
  /// superadmin al dar de alta a un trabajador.
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
  // Controla si el campo de contraseña enmascara el texto (ojito de "ver/ocultar").
  bool _oscurecerContrasena = true;
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  // Bloquea el botón ENTRAR mientras hay una petición en curso para evitar
  // doble submit y enviar dos veces las credenciales al backend.
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
          autofillHints: const [AutofillHints.email],
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
          autofillHints: const [AutofillHints.password],
          textInputAction: TextInputAction.done,
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
          AppRoute.slide(const RecuperarContrasenaScreen()),
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
            const Text(
              '¿Aún no tienes cuenta?',
              style: TextStyle(color: Colors.white60),
            ),
            TextButton(
              onPressed: () => Navigator.push(
                context,
                AppRoute.slide(RegistroScreen(destino: widget.destino)),
              ),
              child: const Text(
                'Regístrate',
                style: TextStyle(
                  color: AppColors.button,
                  fontWeight: FontWeight.bold,
                ),
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
            icon: const Icon(
              Icons.vpn_key_outlined,
              size: 16,
              color: Colors.white54,
            ),
            label: const Text(
              '¿Eres nuevo empleado? Activa tu cuenta',
              style: TextStyle(color: Colors.white54, fontSize: 13),
            ),
          ),
        ],
      ],
    );
  }

  /// Lanza el login contra el backend y maneja las dos posibles ramas:
  /// éxito directo (sesión creada) o requerimiento de 2FA por correo.
  ///
  /// La lógica de detección de 2FA vive en el backend: si la respuesta trae
  /// `requires_2fa: true`, no hay sesión todavía y debemos mandar al usuario
  /// a [VerificacionScreen] en modo 2FA para introducir el código que recibió
  /// por email.
  Future<void> _iniciarSesion() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      showAppError(context, 'Por favor, completa todos los campos');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);

      // 1. Intentamos el login
      final respuesta = await authProvider.iniciarSesion(email, password);

      // Tras un await el widget puede haber sido removido del árbol; sin esta
      // guarda, usar `context` provoca una excepción en runtime.
      if (!mounted) return;

      // 2. CASO 2FA: Si la respuesta indica que requiere verificación por correo
      if (respuesta != null && respuesta['requires_2fa'] == true) {
        final emailParaVerificar =
            respuesta['correo'] ??
            email; // Usar el email del formulario si no viene en la respuesta
        showAppSuccess(
          context,
          '¡Revisa tu bandeja de entrada! Te hemos enviado un código.',
        );

        Navigator.push(
          context,
          AppRoute.slide(
            VerificacionScreen(
              email: emailParaVerificar,
              esModo2FA:
                  true, // Bandera para que la pantalla sepa que es LOGIN y no registro
            ),
          ),
        );
        return;
      }

      // 3. CASO ÉXITO: Si no hay 2FA y el login es directo
      if (authProvider.usuarioActual != null) {
        _navigateToRoleHome(authProvider.usuarioActual!);
      }
    } catch (e) {
      if (mounted) showAppError(context, 'Error: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Reemplaza la pila de navegación por el home correspondiente al rol.
  ///
  /// Usa `pushAndRemoveUntil` con predicado `(_) => false` para que el botón
  /// "atrás" no devuelva al usuario a la pantalla de login después de haber
  /// autenticado correctamente.
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
        destino = const HomeScreenSuperAdmin();
        break;
      case RolUsuario.cliente:
        destino = sel_rest_cliente.SeleccionarRestauranteScreen(
          siguiente: widget.destino == DestinoLogin.reservar
              ? const ReservarMesaScreen()
              : const CartaScreen(),
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
}

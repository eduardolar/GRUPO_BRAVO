import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/colors_style.dart';
import '../../providers/auth_provider.dart';
import '../../components/Cliente/auth_scaffold.dart';
import '../../components/Cliente/auth_header.dart';
import '../../components/Cliente/primary_button.dart';
import '../../components/Cliente/otp_fields.dart';

// Importes para la redirección de roles
import '../../models/usuario_model.dart';
import '../cliente/carta_screen.dart';
import '../cliente/seleccionar_restaurante_screen.dart' as sel_rest_cliente;
import '../home_screen_trabajador.dart';
import '../Administrador/admin_home_screen.dart';
import '../super_admin/home_screen_super_admin.dart';
import '../cocinero/home_screen_cocinero.dart';

/// Pantalla de introducción del código OTP de 6 dígitos.
///
/// Se reutiliza para dos flujos distintos según el flag [esModo2FA]:
/// - **Registro** ([esModo2FA] = false): el cliente acaba de registrarse y
///   verifica que el correo es suyo. Tras éxito se navega a la selección de
///   restaurante + carta.
/// - **Login 2FA** ([esModo2FA] = true): la cuenta tiene 2FA activado y debe
///   confirmar el código antes de que el backend cree la sesión. Tras éxito se
///   navega al home propio del rol del usuario.
///
/// El temporizador de reenvío arranca en 60s y se reinicia cada vez que se
/// solicita un nuevo código para evitar abusar del envío de correos.
class VerificacionScreen extends StatefulWidget {
  /// Email destinatario del código (mostrado en pantalla y usado al verificar).
  final String email;

  /// `true` si venimos del flujo de login con 2FA; `false` si venimos del
  /// registro de cuenta. Decide a qué endpoint llamar y a dónde navegar
  /// después.
  final bool esModo2FA;

  const VerificacionScreen({
    super.key,
    required this.email,
    this.esModo2FA = false, // Por defecto es false (para registro normal)
  });

  @override
  State<VerificacionScreen> createState() => _VerificacionScreenState();
}

class _VerificacionScreenState extends State<VerificacionScreen> {
  // Un controller y un FocusNode por cada uno de los 6 dígitos del OTP.
  final List<TextEditingController> _controllers = List.generate(
    6,
    (_) => TextEditingController(),
  );
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());
  bool _isLoading = false;
  // Cooldown del botón "Reenviar código". Se reinicia tras cada reenvío
  // exitoso para proteger al backend de spam de correos.
  int _secondsRemaining = 60;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    _secondsRemaining = 60;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          if (_secondsRemaining > 0) {
            _secondsRemaining--;
          } else {
            _timer?.cancel();
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (var c in _controllers) {
      c.dispose();
    }
    for (var n in _focusNodes) {
      n.dispose();
    }
    super.dispose();
  }

  /// Concatena los 6 dígitos y los manda al backend según el modo.
  ///
  /// En modo 2FA se llama a `verificarLogin2FA` (el backend crea la sesión
  /// solo si el código es correcto). En modo registro se llama a
  /// `verificarCodigo` y el cliente todavía no está logueado.
  Future<void> _verifyCode() async {
    final code = _controllers.map((c) => c.text).join();
    if (code.length < 6) {
      _showSnackBar('Introduce el código de 6 dígitos', isError: true);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);

      if (widget.esModo2FA) {
        // --- FLUJO 2: VERIFICACIÓN DEL LOGIN ---
        final success = await authProvider.verificarLogin2FA(
          widget.email,
          code,
        );

        if (success && mounted) {
          _showSnackBar('¡Sesión iniciada con éxito!', isError: false);
          _navigateToRoleHome(authProvider.usuarioActual!);
        }
      } else {
        // --- FLUJO 1: VERIFICACIÓN DE REGISTRO ---
        final success = await authProvider.verificarCodigo(widget.email, code);

        if (success && mounted) {
          _showSnackBar('¡Cuenta verificada!', isError: false);
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(
              builder: (_) => sel_rest_cliente.SeleccionarRestauranteScreen(
                siguiente: const CartaScreen(),
              ),
            ),
            (route) => false,
          );
        }
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar(
          e.toString().replaceAll('Exception: ', ''),
          isError: true,
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Helper para redirigir al usuario según su rol tras hacer login
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
      case RolUsuario.cocinero:
        destino = const HomeCocinero();
        break;
      case RolUsuario.cliente:
        destino = sel_rest_cliente.SeleccionarRestauranteScreen(
          siguiente: const CartaScreen(),
        );
        break;
    }

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => destino),
      (route) => false,
    );
  }

  /// Pide al backend que reemita el código. La API que se invoca cambia según
  /// el modo (login 2FA o verificación de registro) porque viven en endpoints
  /// distintos.
  Future<void> _reenviarCodigo() async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);

      // Lógica condicional: Si es login 2FA llama a uno, si es registro llama al otro
      if (widget.esModo2FA) {
        await authProvider.reenviarLogin2FA(widget.email);
      } else {
        await authProvider.reenviarCodigo(widget.email);
      }

      _startTimer();

      if (mounted) {
        _showSnackBar(
          'Código reenviado. Revisa tu carpeta de Spam.',
          isError: false,
        );
      }
    } catch (e) {
      if (mounted) {
        final mensajeLimpio = e.toString().replaceAll('Exception: ', '');
        _showSnackBar(mensajeLimpio, isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ClienteAuthScaffold(
      child: Column(
        children: [
          AuthHeader(
            titulo: widget.esModo2FA ? 'Doble Factor' : 'Verificación',
            subtituloWidget: Column(
              children: [
                Text(
                  widget.esModo2FA
                      ? 'Escribe el código de seguridad enviado a:'
                      : 'Hemos enviado un código de activación a:',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 13,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 5),
                Text(
                  widget.email,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 40),
          OtpFields(
            controllers: _controllers,
            focusNodes: _focusNodes,
            onComplete: _verifyCode,
          ),
          const SizedBox(height: 40),
          PrimaryButton(
            label: widget.esModo2FA ? 'ACCEDER' : 'VERIFICAR CÓDIGO',
            isLoading: _isLoading,
            onPressed: _verifyCode,
          ),
          _buildResendSection(),
        ],
      ),
    );
  }

  Widget _buildResendSection() {
    return Padding(
      padding: const EdgeInsets.only(top: 30),
      child: TextButton(
        onPressed: _secondsRemaining == 0 ? _reenviarCodigo : null,
        child: Text(
          _secondsRemaining > 0
              ? 'Reenviar en ${_secondsRemaining}s'
              : 'REENVIAR CÓDIGO',
          style: TextStyle(
            color: _secondsRemaining == 0 ? AppColors.button : Colors.white38,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: isError ? AppColors.error : AppColors.disp,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

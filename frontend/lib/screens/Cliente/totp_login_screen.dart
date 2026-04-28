import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_routes.dart';
import '../../core/colors_style.dart';
import '../../models/usuario_model.dart';
import '../../models/destino_login.dart';
import '../../providers/auth_provider.dart';
import '../../components/Cliente/otp_fields.dart';
import '../../components/Cliente/auth_scaffold.dart';
import '../../components/Cliente/auth_header.dart';

import 'menu_screen.dart';
import 'reservar_mesa_screen.dart';
import '../home_screen_trabajador.dart';
import '../cocinero/home_screen_cocinero.dart';
import '../Administrador/admin_home_screen.dart';
import '../super_admin/seleccionar_restaurante_screen.dart';

class TotpLoginScreen extends StatefulWidget {
  final DestinoLogin destino;

  const TotpLoginScreen({super.key, this.destino = DestinoLogin.menu});

  @override
  State<TotpLoginScreen> createState() => _TotpLoginScreenState();
}

class _TotpLoginScreenState extends State<TotpLoginScreen> {
  final List<TextEditingController> _controllers =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());
  bool _isLoading = false;

  @override
  void dispose() {
    for (final c in _controllers) { c.dispose(); }
    for (final f in _focusNodes) { f.dispose(); }
    super.dispose();
  }

  String get _codigo => _controllers.map((c) => c.text).join();

  Future<void> _verificar() async {
    final codigo = _codigo;
    if (codigo.length < 6) {
      _showError('Introduce el código de 6 dígitos');
      return;
    }
    setState(() => _isLoading = true);
    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      await auth.completarLogin2fa(codigo);
      if (mounted) _navigateToRoleHome(auth.usuarioActual!);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      for (final c in _controllers) { c.clear(); }
      _focusNodes[0].requestFocus();
      _showError(e.toString().replaceAll('Exception: ', ''));
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
      case RolUsuario.cocinero:
        destino = const HomeCocinero();
        break;
      case RolUsuario.cliente:
        destino = widget.destino == DestinoLogin.reservar
            ? const ReservarMesaScreen()
            : const MenuScreen();
        break;
    }
    Navigator.pushAndRemoveUntil(
      context,
      AppRoute.reveal(destino),
      (route) => false,
    );
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: AppColors.error),
    );
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
            titulo: 'Verificación 2FA',
            subtitulo: 'Introduce el código de Google Authenticator',
          ),
          const SizedBox(height: 40),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white12),
            ),
            child: Column(
              children: [
                const Icon(Icons.shield_outlined, color: AppColors.button, size: 36),
                const SizedBox(height: 12),
                Text(
                  'Abre Google Authenticator y copia el código de 6 dígitos de Restaurante Bravo.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.65),
                    fontSize: 13,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          OtpFields(
            controllers: _controllers,
            focusNodes: _focusNodes,
            onComplete: _verificar,
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _verificar,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.button,
                foregroundColor: Colors.white,
                disabledBackgroundColor: Colors.white12,
                shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                elevation: 0,
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 20, height: 20,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : const Text(
                      'VERIFICAR',
                      style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 2, fontSize: 13),
                    ),
            ),
          ),
          const SizedBox(height: 20),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Volver al inicio de sesión',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5),
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../components/Cliente/auth_header.dart';
import '../../components/Cliente/auth_scaffold.dart';
import '../../components/Cliente/entrada_texto.dart';
import '../../components/Cliente/primary_button.dart';
import '../../core/app_snackbar.dart';
import '../../providers/auth_provider.dart';
import 'login_screen.dart';

class NuevaContrasenaScreen extends StatefulWidget {
  final String email;
  final String codigo;

  const NuevaContrasenaScreen({
    super.key,
    required this.email,
    required this.codigo,
  });

  @override
  State<NuevaContrasenaScreen> createState() => _NuevaContrasenaScreenState();
}

class _NuevaContrasenaScreenState extends State<NuevaContrasenaScreen> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  String? _validarContrasena(String? v) {
    if (v == null || v.isEmpty) return 'Campo requerido';
    if (v.length < 8) return 'Mínimo 8 caracteres';
    if (!RegExp(r'[A-Z]').hasMatch(v)) return 'Falta una mayúscula';
    if (!RegExp(r'[0-9]').hasMatch(v)) return 'Falta un número';
    return null;
  }

  String? _validarConfirmar(String? v) {
    if (v == null || v.isEmpty) return 'Campo requerido';
    if (v != _passwordController.text) return 'Las contraseñas no coinciden';
    return null;
  }

  Future<void> _confirmar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    final auth = context.read<AuthProvider>();
    final navigator = Navigator.of(context);
    try {
      await auth.resetPassword(
        email: widget.email,
        codigo: widget.codigo,
        nuevaPassword: _passwordController.text,
      );
      if (!mounted) return;
      showAppSuccess(context, '¡Contraseña actualizada!');
      navigator.pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;
      showAppError(context, e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ClienteAuthScaffold(
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            const AuthHeader(
              titulo: 'Nueva Contraseña',
              subtitulo: 'Elige una contraseña segura para tu cuenta.',
            ),
            const SizedBox(height: 40),
            EntradaTexto(
              etiqueta: 'Nueva contraseña',
              icono: Icons.lock_outline,
              esContrasena: true,
              mostrarTexto: _obscurePassword,
              alPresionarIcono: () =>
                  setState(() => _obscurePassword = !_obscurePassword),
              autofillHints: const [AutofillHints.newPassword],
              controlador: _passwordController,
              validador: _validarContrasena,
            ),
            const SizedBox(height: 15),
            EntradaTexto(
              etiqueta: 'Confirmar contraseña',
              icono: Icons.lock_outline,
              esContrasena: true,
              mostrarTexto: _obscureConfirm,
              alPresionarIcono: () =>
                  setState(() => _obscureConfirm = !_obscureConfirm),
              autofillHints: const [AutofillHints.newPassword],
              controlador: _confirmController,
              validador: _validarConfirmar,
            ),
            const SizedBox(height: 10),
            PrimaryButton(
              label: 'CONFIRMAR',
              isLoading: _isLoading,
              onPressed: _confirmar,
            ),
          ],
        ),
      ),
    );
  }
}

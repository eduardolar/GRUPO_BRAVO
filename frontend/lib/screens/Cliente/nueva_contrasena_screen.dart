import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/colors_style.dart';
import '../../providers/auth_provider.dart';
import '../../components/Cliente/entrada_texto.dart';
import '../../components/Cliente/auth_scaffold.dart';
import '../../components/Cliente/auth_header.dart';
import '../../components/Cliente/primary_button.dart';
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
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _confirmar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      await auth.resetPassword(
        email: widget.email,
        codigo: widget.codigo,
        nuevaPassword: _passwordController.text,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('¡Contraseña actualizada!'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e.toString().replaceAll('Exception: ', '')),
          backgroundColor: AppColors.error,
        ));
      }
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
              controlador: _passwordController,
              validador: (v) {
                if (v == null || v.isEmpty) return 'Campo requerido';
                if (v.length < 8) return 'Mínimo 8 caracteres';
                if (!RegExp(r'[A-Z]').hasMatch(v)) return 'Falta una mayúscula';
                if (!RegExp(r'[0-9]').hasMatch(v)) return 'Falta un número';
                return null;
              },
            ),
            const SizedBox(height: 15),
            EntradaTexto(
              etiqueta: 'Confirmar contraseña',
              icono: Icons.lock_outline,
              esContrasena: true,
              mostrarTexto: _obscureConfirm,
              alPresionarIcono: () =>
                  setState(() => _obscureConfirm = !_obscureConfirm),
              controlador: _confirmController,
              validador: (v) {
                if (v == null || v.isEmpty) return 'Campo requerido';
                if (v != _passwordController.text) {
                  return 'Las contraseñas no coinciden';
                }
                return null;
              },
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

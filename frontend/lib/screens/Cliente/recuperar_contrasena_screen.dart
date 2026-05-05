import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../components/Cliente/auth_header.dart';
import '../../components/Cliente/auth_scaffold.dart';
import '../../components/Cliente/entrada_texto.dart';
import '../../components/Cliente/primary_button.dart';
import '../../core/app_snackbar.dart';
import '../../providers/auth_provider.dart';
import 'codigo_recuperacion_screen.dart';

class RecuperarContrasenaScreen extends StatefulWidget {
  const RecuperarContrasenaScreen({super.key});

  @override
  State<RecuperarContrasenaScreen> createState() =>
      _RecuperarContrasenaScreenState();
}

class _RecuperarContrasenaScreenState extends State<RecuperarContrasenaScreen> {
  final _formKey = GlobalKey<FormState>();
  final _correoController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _correoController.dispose();
    super.dispose();
  }

  Future<void> _enviarCodigo() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    final auth = context.read<AuthProvider>();
    final navigator = Navigator.of(context);
    try {
      await auth.recuperarPassword(_correoController.text.trim());
      if (!mounted) return;
      navigator.push(
        MaterialPageRoute(
          builder: (_) =>
              CodigoRecuperacionScreen(email: _correoController.text.trim()),
        ),
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
              titulo: 'Restablecer Contraseña',
              subtitulo:
                  'Escribe tu correo para recibir un código de recuperación.',
            ),
            const SizedBox(height: 40),
            EntradaTexto(
              etiqueta: 'Correo electrónico',
              icono: Icons.email_outlined,
              tipoTeclado: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              controlador: _correoController,
              validador: (v) =>
                  (v == null || !v.contains('@')) ? 'Email inválido' : null,
            ),
            const SizedBox(height: 10),
            PrimaryButton(
              label: 'ENVIAR CÓDIGO',
              isLoading: _isLoading,
              onPressed: _enviarCodigo,
            ),
          ],
        ),
      ),
    );
  }
}

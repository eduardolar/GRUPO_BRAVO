import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_snackbar.dart';
import '../../providers/auth_provider.dart';
import '../../components/Cliente/entrada_texto.dart';
import '../../components/Cliente/auth_scaffold.dart';
import '../../components/Cliente/auth_header.dart';
import '../../components/Cliente/primary_button.dart';
import 'codigo_recuperacion_screen.dart';

class ForgottenPassword extends StatefulWidget {
  const ForgottenPassword({super.key});

  @override
  State<ForgottenPassword> createState() => _ForgottenPasswordState();
}

class _ForgottenPasswordState extends State<ForgottenPassword> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _correoController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _correoController.dispose();
    super.dispose();
  }

  Future<void> _enviarCodigo() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      await auth.recuperarPassword(_correoController.text.trim());
      if (!mounted) return;
      Navigator.push(
        context,
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

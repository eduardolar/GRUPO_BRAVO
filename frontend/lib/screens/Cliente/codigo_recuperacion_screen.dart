import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/colors_style.dart';
import '../../providers/auth_provider.dart';
import '../../components/Cliente/auth_scaffold.dart';
import '../../components/Cliente/auth_header.dart';
import '../../components/Cliente/primary_button.dart';
import '../../components/Cliente/otp_fields.dart';
import 'nueva_contrasena_screen.dart';

class CodigoRecuperacionScreen extends StatefulWidget {
  final String email;
  const CodigoRecuperacionScreen({super.key, required this.email});

  @override
  State<CodigoRecuperacionScreen> createState() =>
      _CodigoRecuperacionScreenState();
}

class _CodigoRecuperacionScreenState extends State<CodigoRecuperacionScreen> {
  final List<TextEditingController> _controllers =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());

  bool _isLoading = false;
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
    for (var c in _controllers) { c.dispose(); }
    for (var n in _focusNodes) { n.dispose(); }
    super.dispose();
  }

  void _continuar() {
    final code = _controllers.map((c) => c.text).join();
    if (code.length < 6) {
      _showSnackBar('Introduce el código de 6 dígitos', isError: true);
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            NuevaContrasenaScreen(email: widget.email, codigo: code),
      ),
    );
  }

  Future<void> _reenviarCodigo() async {
    setState(() => _isLoading = true);
    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      await auth.recuperarPassword(widget.email);
      _startTimer();
      if (mounted) {
        _showSnackBar('Código reenviado. Revisa tu correo.', isError: false);
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar(e.toString().replaceAll('Exception: ', ''), isError: true);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ClienteAuthScaffold(
      child: Column(
        children: [
          AuthHeader(
            titulo: 'Verificar Código',
            subtituloWidget: Column(
              children: [
                Text(
                  'Hemos enviado un código a:',
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7), fontSize: 15),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.email,
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 15),
                ),
              ],
            ),
          ),
          const SizedBox(height: 40),
          OtpFields(
            controllers: _controllers,
            focusNodes: _focusNodes,
            onComplete: _continuar,
          ),
          const SizedBox(height: 40),
          PrimaryButton(
            label: 'CONTINUAR',
            onPressed: _continuar,
          ),
          _buildReenviarSeccion(),
        ],
      ),
    );
  }

  Widget _buildReenviarSeccion() {
    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '¿No recibiste el código?',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.6)),
          ),
          TextButton(
            onPressed: (_secondsRemaining == 0 && !_isLoading)
                ? _reenviarCodigo
                : null,
            child: Text(
              _secondsRemaining > 0
                  ? 'Reenviar en ${_secondsRemaining}s'
                  : 'Reenviar',
              style: TextStyle(
                color: _secondsRemaining == 0 ? Colors.white : Colors.white38,
                fontWeight: FontWeight.bold,
                decoration: _secondsRemaining == 0
                    ? TextDecoration.underline
                    : TextDecoration.none,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: isError ? AppColors.error : Colors.green,
    ));
  }
}

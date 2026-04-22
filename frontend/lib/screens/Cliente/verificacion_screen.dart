import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/colors_style.dart';
import '../../providers/auth_provider.dart';
import '../../components/Cliente/auth_scaffold.dart';
import '../../components/Cliente/auth_header.dart';
import '../../components/Cliente/primary_button.dart';
import '../../components/Cliente/otp_fields.dart';
import 'menu_screen.dart';

class VerificationScreen extends StatefulWidget {
  final String email;
  const VerificationScreen({super.key, required this.email});

  @override
  State<VerificationScreen> createState() => _VerificationScreenState();
}

class _VerificationScreenState extends State<VerificationScreen> {
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

  Future<void> _verifyCode() async {
    final code = _controllers.map((c) => c.text).join();
    if (code.length < 6) {
      _showSnackBar('Introduce el código de 6 dígitos', isError: true);
      return;
    }
    setState(() => _isLoading = true);
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final success = await authProvider.verificarCodigo(widget.email, code);
      if (success && mounted) {
        _showSnackBar('¡Cuenta verificada!', isError: false);
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const MenuScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar(e.toString().replaceAll('Exception: ', ''), isError: true);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _reenviarCodigo() async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      await authProvider.reenviarCodigo(widget.email);
      _startTimer();
      if (mounted) {
        _showSnackBar('Código reenviado. Revisa tu correo.', isError: false);
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar(e.toString().replaceAll('Exception: ', ''), isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ClienteAuthScaffold(
      child: Column(
        children: [
          AuthHeader(
            titulo: 'Verificación',
            subtituloWidget: Column(
              children: [
                Text(
                  'Hemos enviado un código a:',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
                ),
                Text(
                  widget.email,
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold),
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
            label: 'VERIFICAR CÓDIGO',
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
          ),
        ),
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

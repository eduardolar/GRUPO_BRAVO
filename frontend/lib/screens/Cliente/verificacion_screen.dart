import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/colors_style.dart';
import '../../providers/auth_provider.dart';
import 'menu_screen.dart';

class VerificationScreen extends StatefulWidget {
  final String email;
  const VerificationScreen({super.key, required this.email});

  @override
  State<VerificationScreen> createState() => _VerificationScreenState();
}

class _VerificationScreenState extends State<VerificationScreen> {
  final List<TextEditingController> _controllers = List.generate(6, (_) => TextEditingController());
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
          if (_secondsRemaining > 0) _secondsRemaining--;
          else _timer?.cancel();
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (var c in _controllers) c.dispose();
    for (var n in _focusNodes) n.dispose();
    super.dispose();
  }

  void _verifyCode() async {
    String code = _controllers.map((c) => c.text).join();
    if (code.length < 6) {
      _showSnackBar("Introduce el código de 6 dígitos", isError: true);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final success = await authProvider.verificarCodigo(widget.email, code);

      if (success && mounted) {
        _showSnackBar("¡Cuenta verificada!", isError: false);
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const MenuScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) _showSnackBar(e.toString().replaceAll("Exception: ", ""), isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(child: Image.asset('assets/images/Bravo restaurante.jpg', fit: BoxFit.cover)),
          Positioned.fill(child: Container(color: AppColors.shadow.withValues(alpha: 0.85))),
          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 500),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 30),
                  child: Column(
                    children: [
                      _buildHeader(),
                      const SizedBox(height: 40),
                      _buildOtpFields(),
                      const SizedBox(height: 40),
                      _buildVerifyButton(),
                      _buildResendSection(),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Positioned(top: 20, left: 10, child: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          )),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Column(children: [
      const Text("Verificación", style: TextStyle(fontFamily: 'Playfair Display', color: Colors.white, fontSize: 36, fontWeight: FontWeight.bold)),
      const SizedBox(height: 15),
      Text("Hemos enviado un código a:", style: TextStyle(color: Colors.white.withValues(alpha: 0.7))),
      Text(widget.email, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
    ]);
  }

  Widget _buildOtpFields() {
    return LayoutBuilder(
      builder: (context, constraints) {
        const gaps = 5 * 8.0;
        final fieldWidth = ((constraints.maxWidth - gaps) / 6).clamp(36.0, 52.0);
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(6, (index) {
            return SizedBox(
              width: fieldWidth,
              child: TextField(
                controller: _controllers[index],
                focusNode: _focusNodes[index],
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                maxLength: 1,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: (fieldWidth * 0.48).clamp(18.0, 24.0),
                  fontWeight: FontWeight.bold,
                ),
                decoration: const InputDecoration(
                  counterText: "",
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.white38),
                  ),
                  focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: AppColors.button, width: 2),
                  ),
                ),
                onChanged: (value) {
                  if (value.isNotEmpty && index < 5) _focusNodes[index + 1].requestFocus();
                  if (value.isEmpty && index > 0) _focusNodes[index - 1].requestFocus();
                  if (index == 5 && value.isNotEmpty) _verifyCode();
                },
              ),
            );
          }),
        );
      },
    );
  }

  Widget _buildVerifyButton() {
    return SizedBox(width: double.infinity, height: 55, child: ElevatedButton(
      style: ElevatedButton.styleFrom(backgroundColor: AppColors.button, foregroundColor: Colors.white, shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero)),
      onPressed: _isLoading ? null : _verifyCode,
      child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text("VERIFICAR CÓDIGO"),
    ));
  }

  Future<void> _reenviarCodigo() async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      await authProvider.reenviarCodigo(widget.email);
      _startTimer();
      if (mounted) _showSnackBar("Código reenviado. Revisa tu correo.", isError: false);
    } catch (e) {
      if (mounted) _showSnackBar(e.toString().replaceAll("Exception: ", ""), isError: true);
    }
  }

  Widget _buildResendSection() {
    return Column(children: [
      const SizedBox(height: 30),
      TextButton(
        onPressed: _secondsRemaining == 0 ? _reenviarCodigo : null,
        child: Text(
          _secondsRemaining > 0 ? "Reenviar en ${_secondsRemaining}s" : "REENVIAR CÓDIGO",
          style: TextStyle(color: _secondsRemaining == 0 ? AppColors.button : Colors.white38),
        ),
      ),
    ]);
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: isError ? Colors.red : Colors.green));
  }
}
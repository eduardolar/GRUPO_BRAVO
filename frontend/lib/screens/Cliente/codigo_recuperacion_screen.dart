import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/colors_style.dart';
import '../../providers/auth_provider.dart';
import 'nueva_contrasena_screen.dart';

class CodigoRecuperacionScreen extends StatefulWidget {
  final String email;
  const CodigoRecuperacionScreen({super.key, required this.email});

  @override
  State<CodigoRecuperacionScreen> createState() => _CodigoRecuperacionScreenState();
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
      _showSnackBar("Introduce el código de 6 dígitos", isError: true);
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => NuevaContrasenaScreen(email: widget.email, codigo: code),
      ),
    );
  }

  Future<void> _reenviarCodigo() async {
    setState(() => _isLoading = true);
    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      await auth.recuperarPassword(widget.email);
      _startTimer();
      if (mounted) _showSnackBar("Código reenviado. Revisa tu correo.", isError: false);
    } catch (e) {
      if (mounted) _showSnackBar(e.toString().replaceAll("Exception: ", ""), isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: isError ? AppColors.error : Colors.green,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset('assets/images/Bravo restaurante.jpg', fit: BoxFit.cover),
          ),
          Positioned.fill(
            child: Container(color: AppColors.shadow.withValues(alpha: 0.85)),
          ),
          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 500),
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 20),
                  child: Column(
                    children: [
                      _buildHeader(),
                      const SizedBox(height: 40),
                      _buildOtpFields(),
                      const SizedBox(height: 40),
                      _buildBotonContinuar(),
                      _buildReenviarSeccion(),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: 20,
            left: 10,
            child: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        const Text(
          "Verificar Código",
          style: TextStyle(
            fontFamily: 'Playfair Display',
            color: Colors.white,
            fontSize: 36,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 10),
        Container(height: 2, width: 40, color: AppColors.button),
        const SizedBox(height: 15),
        Text(
          "Hemos enviado un código a:",
          style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 15),
        ),
        const SizedBox(height: 4),
        Text(
          widget.email,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 15,
          ),
        ),
      ],
    );
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
                decoration: InputDecoration(
                  counterText: "",
                  filled: true,
                  fillColor: AppColors.panel,
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: AppColors.line),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: AppColors.button, width: 2),
                  ),
                ),
                onChanged: (value) {
                  if (value.isNotEmpty && index < 5) {
                    _focusNodes[index + 1].requestFocus();
                  }
                  if (value.isEmpty && index > 0) {
                    _focusNodes[index - 1].requestFocus();
                  }
                  if (index == 5 && value.isNotEmpty) {
                    _continuar();
                  }
                },
              ),
            );
          }),
        );
      },
    );
  }

  Widget _buildBotonContinuar() {
    return SizedBox(
      width: double.infinity,
      height: 55,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.button,
          foregroundColor: Colors.white,
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
          elevation: 0,
        ),
        onPressed: _continuar,
        child: const Text(
          "CONTINUAR",
          style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 2),
        ),
      ),
    );
  }

  Widget _buildReenviarSeccion() {
    return Column(
      children: [
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              "¿No recibiste el código?",
              style: TextStyle(color: Colors.white.withValues(alpha: 0.6)),
            ),
            TextButton(
              onPressed: (_secondsRemaining == 0 && !_isLoading) ? _reenviarCodigo : null,
              child: Text(
                _secondsRemaining > 0 ? "Reenviar en ${_secondsRemaining}s" : "Reenviar",
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
      ],
    );
  }
}

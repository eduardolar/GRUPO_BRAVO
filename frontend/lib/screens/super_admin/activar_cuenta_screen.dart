import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/colors_style.dart';
import '../../components/Cliente/entrada_texto.dart';
import '../cliente/codigo_recuperacion_screen.dart';

class ActivarCuentaScreen extends StatefulWidget {
  const ActivarCuentaScreen({super.key});

  @override
  State<ActivarCuentaScreen> createState() => _ActivarCuentaScreenState();
}

class _ActivarCuentaScreenState extends State<ActivarCuentaScreen> {
  final _formKey = GlobalKey<FormState>();
  final _correoCtrl = TextEditingController();

  @override
  void dispose() {
    _correoCtrl.dispose();
    super.dispose();
  }

  void _continuar() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CodigoRecuperacionScreen(email: _correoCtrl.text.trim()),
      ),
    );
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
                  child: Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        _buildHeader(),
                        const SizedBox(height: 40),
                        EntradaTexto(
                          etiqueta: 'Correo Electrónico',
                          icono: Icons.email_outlined,
                          tipoTeclado: TextInputType.emailAddress,
                          controlador: _correoCtrl,
                          validador: (v) {
                            if (v == null || v.isEmpty) return 'Campo obligatorio';
                            if (!v.contains('@')) return 'Correo inválido';
                            return null;
                          },
                        ),
                        const SizedBox(height: 8),
                        _buildInfoBox(),
                        const SizedBox(height: 32),
                        SizedBox(
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
                            child: Text(
                              'INGRESAR CÓDIGO',
                              style: GoogleFonts.manrope(fontWeight: FontWeight.w700, letterSpacing: 2),
                            ),
                          ),
                        ),
                      ],
                    ),
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
        const SizedBox(height: 40),
        const Text(
          'Activar Cuenta',
          textAlign: TextAlign.center,
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
          'Ingresa tu correo para continuar con el código que recibiste.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 15),
        ),
      ],
    );
  }

  Widget _buildInfoBox() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.white24),
        color: Colors.white.withValues(alpha: 0.06),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, color: Colors.white54, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'El código fue enviado a tu correo cuando el administrador creó tu cuenta. Si no lo tienes, pulsa "Reenviar" en la siguiente pantalla.',
              style: GoogleFonts.manrope(color: Colors.white54, fontSize: 12, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }
}

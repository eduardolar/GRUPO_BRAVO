import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/colors_style.dart';
import '../../providers/auth_provider.dart';
import '../../components/Cliente/entrada_texto.dart';
import 'login_screen.dart';

class NuevaContrasenaScreen extends StatefulWidget {
  final String email;
  final String codigo;
  const NuevaContrasenaScreen({super.key, required this.email, required this.codigo});

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
          content: Text("¡Contraseña actualizada!"),
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
          content: Text(e.toString().replaceAll("Exception: ", "")),
          backgroundColor: AppColors.error,
        ));
      }
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
                          etiqueta: "Nueva contraseña",
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
                        EntradaTexto(
                          etiqueta: "Confirmar contraseña",
                          icono: Icons.lock_outline,
                          esContrasena: true,
                          mostrarTexto: _obscureConfirm,
                          alPresionarIcono: () =>
                              setState(() => _obscureConfirm = !_obscureConfirm),
                          controlador: _confirmController,
                          validador: (v) {
                            if (v == null || v.isEmpty) return 'Campo requerido';
                            if (v != _passwordController.text) return 'Las contraseñas no coinciden';
                            return null;
                          },
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          height: 55,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.button,
                              foregroundColor: Colors.white,
                              shape: const RoundedRectangleBorder(
                                  borderRadius: BorderRadius.zero),
                              elevation: 0,
                            ),
                            onPressed: _isLoading ? null : _confirmar,
                            child: _isLoading
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                        color: Colors.white, strokeWidth: 2),
                                  )
                                : const Text(
                                    "CONFIRMAR",
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold, letterSpacing: 2),
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
        const Text(
          "Nueva Contraseña",
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
          "Elige una contraseña segura para tu cuenta.",
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 15),
        ),
      ],
    );
  }
}

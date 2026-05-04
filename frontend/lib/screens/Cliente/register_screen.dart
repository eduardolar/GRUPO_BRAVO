import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_snackbar.dart';
import '../../core/colors_style.dart';
import '../../providers/auth_provider.dart';
import '../../models/destino_login.dart';

import '../../components/Cliente/entrada_texto.dart';
import '../../components/Cliente/auth_scaffold.dart';
import '../../components/Cliente/auth_header.dart';
import '../../components/Cliente/primary_button.dart';

import 'login_screen.dart';
import 'verificacion_screen.dart';
import 'direccion_screen.dart';

class RegisterScreen extends StatefulWidget {
  final DestinoLogin destino;

  const RegisterScreen({super.key, this.destino = DestinoLogin.menu});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _ocultarPass = true;
  bool _ocultarConfirm = true;
  bool _isLoading = false;

  final _nombreCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  final _telefonoCtrl = TextEditingController();
  final _direccionCtrl = TextEditingController();

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    _telefonoCtrl.dispose();
    _direccionCtrl.dispose();
    super.dispose();
  }

  // ── Validadores ──────────────────────────────────────────────────────────

  String? _validarEmail(String? v) {
    if (v == null || v.trim().isEmpty) return 'Campo requerido';
    final regex = RegExp(r'^[\w.+\-]+@[\w\-]+\.[a-z]{2,}$', caseSensitive: false);
    if (!regex.hasMatch(v.trim())) return 'Correo electrónico no válido';
    return null;
  }

  String? _validarContrasena(String? v) {
    if (v == null || v.isEmpty) return 'Campo requerido';
    if (v.length < 8) return 'Mínimo 8 caracteres';
    if (!RegExp(r'[A-Z]').hasMatch(v)) return 'Debe incluir una mayúscula';
    if (!RegExp(r'[0-9]').hasMatch(v)) return 'Debe incluir un número';
    return null;
  }

  String? _validarConfirmar(String? v) {
    if (v == null || v.isEmpty) return 'Campo requerido';
    if (v != _passwordCtrl.text) return 'Las contraseñas no coinciden';
    return null;
  }

  String? _validarTelefono(String? v) {
    if (v == null || v.trim().isEmpty) return 'Campo requerido';
    final digits = v.trim().replaceAll(RegExp(r'\D'), '');
    if (digits.length < 9) return 'Número de teléfono incompleto';
    return null;
  }

  // ── Acciones ─────────────────────────────────────────────────────────────

  Future<void> _abrirSelectorDireccion() async {
    final resultado = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
          builder: (_) => const DireccionScreen(soloSeleccionar: true)),
    );
    if (resultado != null && mounted) {
      setState(() {
        _direccionCtrl.text = resultado['direccion'] as String;
      });
    }
  }

  Future<void> _registrarse() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      await auth.registrarse(
        nombre: _nombreCtrl.text.trim(),
        email: _emailCtrl.text.trim(),
        contrasena: _passwordCtrl.text,
        telefono: _telefonoCtrl.text.trim(),
        direccion: _direccionCtrl.text.trim(),
      );
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              VerificacionScreen(email: _emailCtrl.text.trim()),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      showAppError(context, 'Error: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return ClienteAuthScaffold(
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            const AuthHeader(
              titulo: 'Crea tu Cuenta',
              subtitulo: 'Completa tus datos para empezar',
            ),
            const SizedBox(height: 28),
            _buildInputs(),
            const SizedBox(height: 8),
            PrimaryButton(
              label: 'CREAR CUENTA',
              isLoading: _isLoading,
              onPressed: _registrarse,
            ),
            _buildFooter(),
          ],
        ),
      ),
    );
  }

  // ── Campos del formulario ─────────────────────────────────────────────────

  Widget _buildInputs() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Nombre
        EntradaTexto(
          etiqueta: 'Nombre completo',
          icono: Icons.person_outline,
          autofillHints: const [AutofillHints.name],
          controlador: _nombreCtrl,
          validador: (v) =>
              (v == null || v.trim().isEmpty) ? 'Campo requerido' : null,
        ),

        // Email
        EntradaTexto(
          etiqueta: 'Correo electrónico',
          icono: Icons.email_outlined,
          tipoTeclado: TextInputType.emailAddress,
          autofillHints: const [AutofillHints.email],
          controlador: _emailCtrl,
          validador: _validarEmail,
        ),

        // Contraseña
        EntradaTexto(
          etiqueta: 'Contraseña',
          icono: Icons.lock_outline,
          esContrasena: true,
          mostrarTexto: _ocultarPass,
          alPresionarIcono: () =>
              setState(() => _ocultarPass = !_ocultarPass),
          autofillHints: const [AutofillHints.newPassword],
          controlador: _passwordCtrl,
          validador: _validarContrasena,
        ),

        // Indicador de fuerza
        _PasswordStrengthBar(password: _passwordCtrl),

        const SizedBox(height: 16),

        // Confirmar contraseña
        EntradaTexto(
          etiqueta: 'Confirmar contraseña',
          icono: Icons.lock_outline,
          esContrasena: true,
          mostrarTexto: _ocultarConfirm,
          alPresionarIcono: () =>
              setState(() => _ocultarConfirm = !_ocultarConfirm),
          autofillHints: const [AutofillHints.newPassword],
          controlador: _confirmCtrl,
          validador: _validarConfirmar,
        ),

        // Teléfono
        EntradaTexto(
          etiqueta: 'Teléfono',
          icono: Icons.phone_android_outlined,
          tipoTeclado: TextInputType.phone,
          autofillHints: const [AutofillHints.telephoneNumber],
          controlador: _telefonoCtrl,
          validador: _validarTelefono,
        ),

        // Dirección (selector externo)
        _DireccionField(
          controller: _direccionCtrl,
          onTap: _abrirSelectorDireccion,
        ),
      ],
    );
  }

  // ── Footer ────────────────────────────────────────────────────────────────

  Widget _buildFooter() {
    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '¿Ya tienes cuenta?',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.6)),
          ),
          TextButton(
            onPressed: () => Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (_) => LoginScreen(destino: widget.destino),
              ),
            ),
            child: const Text(
              'Inicia sesión',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                decoration: TextDecoration.underline,
                decorationColor: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Widgets auxiliares
// ─────────────────────────────────────────────────────────────────────────────

/// Barra visual de fuerza de contraseña que escucha el controller.
class _PasswordStrengthBar extends StatefulWidget {
  const _PasswordStrengthBar({required this.password});
  final TextEditingController password;

  @override
  State<_PasswordStrengthBar> createState() => _PasswordStrengthBarState();
}

class _PasswordStrengthBarState extends State<_PasswordStrengthBar> {
  int _score = 0;

  @override
  void initState() {
    super.initState();
    widget.password.addListener(_update);
  }

  void _update() => setState(() => _score = _calcScore(widget.password.text));

  @override
  void dispose() {
    widget.password.removeListener(_update);
    super.dispose();
  }

  int _calcScore(String v) {
    int s = 0;
    if (v.length >= 8) s++;
    if (RegExp(r'[A-Z]').hasMatch(v)) s++;
    if (RegExp(r'[0-9]').hasMatch(v)) s++;
    if (RegExp(r'[^A-Za-z0-9]').hasMatch(v)) s++;
    return s;
  }

  Color get _color {
    if (_score <= 1) return AppColors.error;
    if (_score == 2) return AppColors.noDisp;
    if (_score == 3) return const Color(0xFFD97706);
    return AppColors.disp;
  }

  String get _label {
    if (_score == 0) return '';
    if (_score <= 1) return 'Débil';
    if (_score == 2) return 'Regular';
    if (_score == 3) return 'Buena';
    return 'Segura';
  }

  @override
  Widget build(BuildContext context) {
    if (widget.password.text.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: List.generate(4, (i) {
              final active = i < _score;
              return Expanded(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  margin: EdgeInsets.only(right: i < 3 ? 4 : 0),
                  height: 4,
                  decoration: BoxDecoration(
                    color: active
                        ? _color
                        : Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 5),
          Text(
            _label,
            style: TextStyle(
              color: _color,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// Campo de dirección de solo lectura que abre el selector al tocar.
class _DireccionField extends StatelessWidget {
  const _DireccionField({required this.controller, required this.onTap});
  final TextEditingController controller;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AbsorbPointer(
        child: TextFormField(
          controller: controller,
          readOnly: true,
          validator: (v) => (v == null || v.trim().isEmpty)
              ? 'La dirección es obligatoria'
              : null,
          style: const TextStyle(color: AppColors.textPrimary),
          decoration: InputDecoration(
            labelText: 'Dirección de entrega',
            labelStyle: const TextStyle(color: AppColors.textSecondary),
            prefixIcon:
                const Icon(Icons.map_outlined, color: AppColors.gold),
            suffixIcon:
                const Icon(Icons.chevron_right, color: AppColors.gold),
            filled: true,
            fillColor: AppColors.panel,
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(15),
              borderSide: const BorderSide(color: AppColors.line),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(15),
              borderSide:
                  const BorderSide(color: AppColors.button, width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(15),
              borderSide: const BorderSide(color: AppColors.error),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(15),
              borderSide:
                  const BorderSide(color: AppColors.error, width: 2),
            ),
            errorStyle: const TextStyle(color: AppColors.error),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15)),
          ),
        ),
      ),
    );
  }
}

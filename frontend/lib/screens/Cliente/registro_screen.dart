import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../components/Cliente/auth_header.dart';
import '../../components/Cliente/auth_scaffold.dart';
import '../../components/Cliente/entrada_texto.dart';
import '../../components/Cliente/primary_button.dart';
import '../../core/app_snackbar.dart';
import '../../core/colors_style.dart';
import '../../models/destino_login.dart';
import '../../providers/auth_provider.dart';
import '../../services/restaurante_service.dart'; // Asegúrate que esta ruta es correcta
import 'direccion_screen.dart';
import 'login_screen.dart';
import 'verificacion_screen.dart';

const BorderRadius _kFieldRadius = BorderRadius.all(Radius.circular(15));

class RegistroScreen extends StatefulWidget {
  final DestinoLogin destino;
  const RegistroScreen({super.key, this.destino = DestinoLogin.menu});

  @override
  State<RegistroScreen> createState() => _RegistroScreenState();
}

class _RegistroScreenState extends State<RegistroScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _ocultarPass = true;
  bool _ocultarConfirm = true;
  bool _isLoading = false;
  bool _aceptaPrivacidad = false;
  bool _privacidadError = false;

  // Variables para Restaurantes
  List<dynamic> _restaurantes = [];
  String? _restauranteSeleccionado;
  bool _restauranteError = false;

  final _nombreCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  final _telefonoCtrl = TextEditingController();
  final _direccionCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _cargarRestaurantes(); // Cargamos los restaurantes al iniciar la pantalla
  }

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

  // Función para cargar restaurantes (AQUÍ ES DONDE DEBE IR)
  Future<void> _cargarRestaurantes() async {
    try {
      final lista = await RestauranteService().obtenerTodos();
      if (!mounted) return;
      setState(() => _restaurantes = lista);
    } catch (e) {
      debugPrint('Error al cargar restaurantes: $e');
    }
  }

  // ── Validadores ─────────────────────────────────────────────────────────
  String? _validarEmail(String? v) {
    if (v == null || v.trim().isEmpty) return 'Campo requerido';
    final regex = RegExp(
      r'^[\w.+\-]+@[\w\-]+\.[a-z]{2,}$',
      caseSensitive: false,
    );
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

  // ── Acciones ────────────────────────────────────────────────────────────
  Future<void> _abrirSelectorDireccion() async {
    final resultado = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (_) => const DireccionScreen(soloSeleccionar: true),
      ),
    );
    if (!mounted || resultado == null) return;
    setState(() => _direccionCtrl.text = resultado['direccion'] as String);
  }

  Future<void> _registrarse() async {
    if (!_formKey.currentState!.validate()) return;

    if (_restauranteSeleccionado == null) {
      setState(() => _restauranteError = true);
      return;
    }

    if (!_aceptaPrivacidad) {
      setState(() => _privacidadError = true);
      return;
    }

    setState(() => _isLoading = true);
    final auth = context.read<AuthProvider>();
    try {
      await auth.registrarse(
        nombre: _nombreCtrl.text.trim(),
        email: _emailCtrl.text.trim(),
        contrasena: _passwordCtrl.text,
        telefono: _telefonoCtrl.text.trim(),
        direccion: _direccionCtrl.text.trim(),
        restauranteId:
            _restauranteSeleccionado, // Asegúrate que AuthProvider acepte esto
        consentimientoRgpd: true,
      );
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => VerificacionScreen(email: _emailCtrl.text.trim()),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      showAppError(context, 'Error: $e');
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

  Widget _buildInputs() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        EntradaTexto(
          etiqueta: 'Nombre completo',
          icono: Icons.person_outline,
          autofillHints: const [AutofillHints.name],
          controlador: _nombreCtrl,
          validador: (v) =>
              (v == null || v.trim().isEmpty) ? 'Campo requerido' : null,
        ),
        EntradaTexto(
          etiqueta: 'Correo electrónico',
          icono: Icons.email_outlined,
          tipoTeclado: TextInputType.emailAddress,
          autofillHints: const [AutofillHints.email],
          controlador: _emailCtrl,
          validador: _validarEmail,
        ),
        EntradaTexto(
          etiqueta: 'Contraseña',
          icono: Icons.lock_outline,
          autofillHints: const [AutofillHints.password],
          esContrasena: true,
          mostrarTexto: _ocultarPass,
          alPresionarIcono: () => setState(() => _ocultarPass = !_ocultarPass),
          controlador: _passwordCtrl,
          validador: _validarContrasena,
        ),
        _PasswordStrengthBar(password: _passwordCtrl),
        const SizedBox(height: 16),
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
        EntradaTexto(
          etiqueta: 'Teléfono',
          icono: Icons.phone_android_outlined,
          controlador: _telefonoCtrl,
          validador: _validarTelefono,
        ),
        // SELECTOR DE RESTAURANTE
        _SelectorRestaurante(
          restaurantes: _restaurantes,
          seleccionado: _restauranteSeleccionado,
          hayError: _restauranteError,
          onChanged: (val) => setState(() {
            _restauranteSeleccionado = val;
            _restauranteError = false;
          }),
        ),
        _DireccionField(
          controller: _direccionCtrl,
          onTap: _abrirSelectorDireccion,
        ),
        const SizedBox(height: 16),
        _ConsentimientoRgpd(
          aceptado: _aceptaPrivacidad,
          hayError: _privacidadError,
          onChange: (v) => setState(() {
            _aceptaPrivacidad = v ?? false;
            if (_aceptaPrivacidad) _privacidadError = false;
          }),
        ),
      ],
    );
  }

  Widget _buildFooter() {
    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '¿Ya tienes cuenta?',
            style: TextStyle(color: Colors.white.withOpacity(0.6)),
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
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Widgets auxiliares (FUERA DE LAS OTRAS CLASES) ────────────────────────

class _SelectorRestaurante extends StatelessWidget {
  const _SelectorRestaurante({
    required this.restaurantes,
    required this.seleccionado,
    required this.onChanged,
    required this.hayError,
  });

  final List<dynamic> restaurantes;
  final String? seleccionado;
  final ValueChanged<String?> onChanged;
  final bool hayError;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.panel,
        borderRadius: _kFieldRadius,
        border: Border.all(
          color: hayError ? AppColors.error : AppColors.line,
          width: hayError ? 2 : 1,
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: seleccionado,
          isExpanded: true,
          dropdownColor: AppColors.panel,
          hint: const Text(
            "Tu restaurante más cercano",
            style: TextStyle(color: AppColors.textSecondary, fontSize: 16),
          ),
          icon: const Icon(Icons.arrow_drop_down, color: AppColors.gold),
          items: restaurantes.map((res) {
            return DropdownMenuItem<String>(
              value: res.id.toString(),
              child: Text(
                res.nombre,
                style: const TextStyle(color: AppColors.textPrimary),
              ),
            );
          }).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}

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

  @override
  Widget build(BuildContext context) {
    if (widget.password.text.isEmpty) return const SizedBox.shrink();
    // ... resto de tu lógica de la barra (la he omitido para abreviar)
    return Container(); // Reemplaza por tu código de la barra
  }
}

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
          style: const TextStyle(color: AppColors.textPrimary),
          decoration: InputDecoration(
            labelText: 'Dirección de entrega',
            prefixIcon: const Icon(Icons.map_outlined, color: AppColors.gold),
            filled: true,
            fillColor: AppColors.panel,
            border: OutlineInputBorder(borderRadius: _kFieldRadius),
          ),
        ),
      ),
    );
  }
}

class _ConsentimientoRgpd extends StatelessWidget {
  const _ConsentimientoRgpd({
    required this.aceptado,
    required this.hayError,
    required this.onChange,
  });
  final bool aceptado;
  final bool hayError;
  final ValueChanged<bool?> onChange;

  @override
  Widget build(BuildContext context) {
    return CheckboxListTile(
      value: aceptado,
      onChanged: onChange,
      title: const Text(
        "Acepto la política de privacidad",
        style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
      ),
      controlAffinity: ListTileControlAffinity.leading,
    );
  }
}

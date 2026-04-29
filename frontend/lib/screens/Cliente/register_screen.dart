import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

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
  bool _isLoading = false;

  final TextEditingController _nombreController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _telefonoController = TextEditingController();
  final TextEditingController _direccionController = TextEditingController();
  double? _latitud;
  double? _longitud;

  @override
  void dispose() {
    _nombreController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _telefonoController.dispose();
    _direccionController.dispose();
    super.dispose();
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
            const SizedBox(height: 30),
            _buildInputs(),
            const SizedBox(height: 40),
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
      children: [
        EntradaTexto(
          etiqueta: 'Nombre completo',
          icono: Icons.person_outline,
          controlador: _nombreController,
          validador: (v) => v!.isEmpty ? 'Campo requerido' : null,
        ),
        const SizedBox(height: 15),
        EntradaTexto(
          etiqueta: 'Correo electrónico',
          icono: Icons.email_outlined,
          tipoTeclado: TextInputType.emailAddress,
          controlador: _emailController,
          validador: (v) => !v!.contains('@') ? 'Email inválido' : null,
        ),
        const SizedBox(height: 15),
        EntradaTexto(
          etiqueta: 'Contraseña',
          icono: Icons.lock_outline,
          esContrasena: true,
          mostrarTexto: _ocultarPass,
          alPresionarIcono: () => setState(() => _ocultarPass = !_ocultarPass),
          controlador: _passwordController,
          validador: _validarContrasena,
        ),
        const SizedBox(height: 15),
        EntradaTexto(
          etiqueta: 'Teléfono',
          icono: Icons.phone_android_outlined,
          tipoTeclado: TextInputType.phone,
          controlador: _telefonoController,
          validador: (v) => v!.length < 7 ? 'Teléfono incompleto' : null,
        ),
        const SizedBox(height: 15),
        GestureDetector(
          onTap: _abrirSelectorDireccion,
          child: AbsorbPointer(
            child: TextFormField(
              controller: _direccionController,
              readOnly: true,
              validator: (v) => (v == null || v.isEmpty) ? 'La dirección es obligatoria' : null,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: InputDecoration(
                labelText: 'Dirección de entrega',
                labelStyle: const TextStyle(color: AppColors.textSecondary),
                prefixIcon: const Icon(Icons.map_outlined, color: AppColors.gold),
                suffixIcon: const Icon(Icons.chevron_right, color: AppColors.gold),
                filled: true,
                fillColor: AppColors.panel,
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                  borderSide: const BorderSide(color: AppColors.line),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                  borderSide: const BorderSide(color: AppColors.button, width: 2),
                ),
                errorStyle: const TextStyle(color: AppColors.error),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFooter() {
    return Padding(
      padding: const EdgeInsets.only(top: 25),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('¿Ya tienes cuenta?',
              style: TextStyle(color: Colors.white60)),
          TextButton(
            onPressed: () => Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                  builder: (_) => LoginScreen(destino: widget.destino)),
            ),
            child: const Text(
              'Inicia Sesión',
              style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  decoration: TextDecoration.underline),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _abrirSelectorDireccion() async {
    final resultado = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(builder: (_) => const DireccionScreen(soloSeleccionar: true)),
    );
    if (resultado != null && mounted) {
      setState(() {
        _direccionController.text = resultado['direccion'] as String;
        _latitud = resultado['latitud'] as double;
        _longitud = resultado['longitud'] as double;
      });
    }
  }

  String? _validarContrasena(String? v) {
    if (v == null || v.isEmpty) return 'Campo requerido';
    if (v.length < 8) return 'Mínimo 8 caracteres';
    if (!RegExp(r'[A-Z]').hasMatch(v)) return 'Falta una mayúscula';
    if (!RegExp(r'[0-9]').hasMatch(v)) return 'Falta un número';
    return null;
  }

  Future<void> _registrarse() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      await authProvider.registrarse(
        nombre: _nombreController.text.trim(),
        email: _emailController.text.trim(),
        contrasena: _passwordController.text,
        telefono: _telefonoController.text.trim(),
        direccion: _direccionController.text.trim(),
      );
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                VerificacionScreen(email: _emailController.text.trim()),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error: ${e.toString()}'),
              backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}

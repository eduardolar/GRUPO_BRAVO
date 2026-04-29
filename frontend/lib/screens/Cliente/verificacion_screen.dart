import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/colors_style.dart';
import '../../providers/auth_provider.dart';
import '../../components/Cliente/auth_scaffold.dart';
import '../../components/Cliente/auth_header.dart';
import '../../components/Cliente/primary_button.dart';
import '../../components/Cliente/otp_fields.dart';

// Importes para la redirección de roles
import '../../models/usuario_model.dart';
import '../cliente/menu_screen.dart';
import '../home_screen_trabajador.dart';
import '../Administrador/admin_home_screen.dart';
import '../super_admin/seleccionar_restaurante_screen.dart';
import '../cocinero/home_screen_cocinero.dart';

class VerificacionScreen extends StatefulWidget {
  final String email;
  final bool esModo2FA; // NUEVO: Bandera para saber de dónde venimos

  const VerificacionScreen({
    super.key, 
    required this.email,
    this.esModo2FA = false, // Por defecto es false (para registro normal)
  });

  @override
  State<VerificacionScreen> createState() => _VerificacionScreenState();
}

class _VerificacionScreenState extends State<VerificacionScreen> {
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

      if (widget.esModo2FA) {
        // --- FLUJO 2: VERIFICACIÓN DEL LOGIN ---
        final success = await authProvider.verificarLogin2FA(widget.email, code);
        
        if (success && mounted) {
          _showSnackBar('¡Sesión iniciada con éxito!', isError: false);
          _navigateToRoleHome(authProvider.usuarioActual!);
        }

      } else {
        // --- FLUJO 1: VERIFICACIÓN DE REGISTRO ---
        final success = await authProvider.verificarCodigo(widget.email, code);
        
        if (success && mounted) {
          _showSnackBar('¡Cuenta verificada!', isError: false);
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => const MenuScreen()),
            (route) => false,
          );
        }
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar(e.toString().replaceAll('Exception: ', ''), isError: true);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Helper para redirigir al usuario según su rol tras hacer login
  void _navigateToRoleHome(Usuario usuario) {
    Widget destino;
    switch (usuario.rol) {
      case RolUsuario.trabajador:
        destino = const HomeTrabajador();
        break;
      case RolUsuario.administrador:
        destino = const MenuAdministrador();
        break;
      case RolUsuario.superadministrador:
        destino = const SeleccionarRestauranteScreen();
        break;
      case RolUsuario.cocinero:
        destino = const HomeCocinero();
        break;
      case RolUsuario.cliente:
      default:
        destino = const MenuScreen();
        break;
    }
    
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => destino),
      (route) => false,
    );
  }

Future<void> _reenviarCodigo() async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      
      // Lógica condicional: Si es login 2FA llama a uno, si es registro llama al otro
      if (widget.esModo2FA) {
        await authProvider.reenviarLogin2FA(widget.email);
      } else {
        await authProvider.reenviarCodigo(widget.email);
      }
      
      _startTimer();
      
      if (mounted) {
        _showSnackBar('Código reenviado. Revisa tu carpeta de Spam.', isError: false);
      }
    } catch (e) {
      if (mounted) {
        final mensajeLimpio = e.toString().replaceAll('Exception: ', '');
        _showSnackBar(mensajeLimpio, isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ClienteAuthScaffold(
      child: Column(
        children: [
          AuthHeader(
            titulo: widget.esModo2FA ? 'Doble Factor' : 'Verificación',
            subtituloWidget: Column(
              children: [
                Text(
                  widget.esModo2FA 
                    ? 'Escribe el código de seguridad enviado a:' 
                    : 'Hemos enviado un código de activación a:',
                  style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 13),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 5),
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
            label: widget.esModo2FA ? 'ACCEDER' : 'VERIFICAR CÓDIGO',
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
            fontWeight: FontWeight.bold
          ),
        ),
      ),
    );
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
      backgroundColor: isError ? AppColors.error : Colors.green.shade700,
      behavior: SnackBarBehavior.floating,
    ));
  }
}
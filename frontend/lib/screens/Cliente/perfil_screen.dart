import 'package:flutter/material.dart';
import '../../core/app_snackbar.dart';
import 'package:flutter/services.dart' show TextInputFormatter, LengthLimitingTextInputFormatter;
import 'package:frontend/screens/cliente/login_screen.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/colors_style.dart';
import '../../models/usuario_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/cart_provider.dart';
import 'home_screen.dart';
import 'historial_pedidos_screen.dart';
import 'direccion_screen.dart';
import 'totp_setup_screen.dart';

// Azul fijo para el estado de email-2FA (no está en AppColors)
const _kBlue2FA = Color(0xFF3B82F6);

class PerfilScreen extends StatefulWidget {
  const PerfilScreen({super.key});

  @override
  State<PerfilScreen> createState() => _PerfilScreenState();
}

class _PerfilScreenState extends State<PerfilScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nombreController;
  late TextEditingController _emailController;
  late TextEditingController _telefonoController;
  late TextEditingController _direccionController;
  bool _hayCambios = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final usuario = auth.usuarioActual;
    _nombreController = TextEditingController(text: usuario?.nombre ?? '');
    _emailController = TextEditingController(text: usuario?.email ?? '');
    _telefonoController = TextEditingController(text: usuario?.telefono ?? '');
    _direccionController = TextEditingController(text: usuario?.direccion ?? '');

    _nombreController.addListener(_detectarCambios);
    _emailController.addListener(_detectarCambios);
    _telefonoController.addListener(_detectarCambios);
    _direccionController.addListener(_detectarCambios);
  }

  void _detectarCambios() {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final usuario = auth.usuarioActual;
    final cambio =
        _nombreController.text != (usuario?.nombre ?? '') ||
        _emailController.text != (usuario?.email ?? '') ||
        _telefonoController.text != (usuario?.telefono ?? '') ||
        _direccionController.text != (usuario?.direccion ?? '');
    if (cambio != _hayCambios) setState(() => _hayCambios = cambio);
  }

  @override
  void dispose() {
    _nombreController.removeListener(_detectarCambios);
    _emailController.removeListener(_detectarCambios);
    _telefonoController.removeListener(_detectarCambios);
    _direccionController.removeListener(_detectarCambios);
    _nombreController.dispose();
    _emailController.dispose();
    _telefonoController.dispose();
    _direccionController.dispose();
    super.dispose();
  }

  // ── SnackBar helper ──────────────────────────────────────────────────────

  void _snack(String msg, {bool error = false, bool success = false}) {
    if (error) {
      showAppError(context, msg);
    } else if (success) {
      showAppSuccess(context, msg);
    } else {
      showAppInfo(context, msg);
    }
  }

  // ── Lógica ───────────────────────────────────────────────────────────────

  Future<void> _guardarCambios() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    final auth = Provider.of<AuthProvider>(context, listen: false);
    try {
      await auth.actualizarPerfil(
        nombre: _nombreController.text.trim(),
        email: _emailController.text.trim(),
        telefono: _telefonoController.text.trim(),
        direccion: _direccionController.text.trim(),
      );
      if (!mounted) return;
      _snack('Datos actualizados correctamente', success: true);
      setState(() => _hayCambios = false);
    } catch (e) {
      if (!mounted) return;
      _snack('Error: ${e.toString()}', error: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _abrirSelectorDireccion() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const DireccionScreen()),
    );
    if (!mounted) return;
    final auth = Provider.of<AuthProvider>(context, listen: false);
    _direccionController.text = auth.usuarioActual?.direccion ?? '';
    _detectarCambios();
  }

  void _mostrarDialogoEliminarCuenta() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.backgroundDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded,
                color: AppColors.error, size: 26),
            const SizedBox(width: 10),
            Text(
              'Eliminar cuenta',
              style: GoogleFonts.manrope(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Text(
          '¿Estás seguro? Esta acción no se puede deshacer y perderás todos tus datos.',
          style: GoogleFonts.manrope(
              color: Colors.white60, fontSize: 14, height: 1.5),
        ),
        actions: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white60,
                    side: const BorderSide(color: Colors.white24),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  child: Text('CANCELAR',
                      style: GoogleFonts.manrope(
                          fontSize: 12, letterSpacing: 1)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  onPressed: () async {
                    Navigator.pop(ctx);
                    await _eliminarCuenta();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.error,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    elevation: 0,
                  ),
                  child: Text('ELIMINAR',
                      style: GoogleFonts.manrope(
                          fontSize: 12,
                          letterSpacing: 1,
                          fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _eliminarCuenta() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    try {
      await auth.eliminarCuenta();
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;
      _snack('Error al eliminar cuenta: ${e.toString()}', error: true);
    }
  }

  Future<void> _mostrarActivar2FA() async {
    final activado = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const TotpSetupScreen()),
    );
    if (activado == true && mounted) setState(() {});
  }

  void _mostrarDesactivar2FA() {
    final formKey = GlobalKey<FormState>();
    final codigoCtrl = TextEditingController();
    bool cargando = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: _BottomSheetContainer(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _SheetHandle(),
                  const SizedBox(height: 20),
                  Text('Desactivar 2FA',
                      style: GoogleFonts.manrope(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text(
                    'Introduce el código de Google Authenticator para confirmar.',
                    style: GoogleFonts.manrope(
                        color: Colors.white.withValues(alpha: 0.6),
                        fontSize: 13),
                  ),
                  const SizedBox(height: 20),
                  _campoSheet(
                    ctrl: codigoCtrl,
                    label: 'Código de 6 dígitos',
                    oculto: false,
                    onToggle: () {},
                    validator: (v) => (v == null || v.trim().length != 6)
                        ? 'Introduce el código de 6 dígitos'
                        : null,
                  ),
                  const SizedBox(height: 24),
                  _SheetButton(
                    label: 'DESACTIVAR 2FA',
                    color: AppColors.error,
                    cargando: cargando,
                    onPressed: () async {
                      if (!formKey.currentState!.validate()) return;
                      setSheet(() => cargando = true);
                      try {
                        final auth = Provider.of<AuthProvider>(
                            context,
                            listen: false);
                        await auth.desactivar2fa(codigoCtrl.text.trim());
                        if (ctx.mounted) Navigator.pop(ctx);
                        if (mounted) {
                          setState(() {});
                          _snack('2FA desactivado correctamente',
                              success: true);
                        }
                      } catch (e) {
                        if (ctx.mounted) {
                          setSheet(() => cargando = false);
                        }
                        if (mounted) {
                          _snack(
                              e.toString().replaceAll('Exception: ', ''),
                              error: true);
                        }
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _mostrarGestionEmail2FA({required bool activar}) {
    final formKey = GlobalKey<FormState>();
    final codigoCtrl = TextEditingController();
    bool codigoEnviado = false;
    bool cargando = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: _BottomSheetContainer(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _SheetHandle(),
                  const SizedBox(height: 20),
                  Text(
                    activar
                        ? 'Activar verificación por correo'
                        : 'Desactivar verificación por correo',
                    style: GoogleFonts.manrope(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    activar
                        ? 'Al activarla, cada vez que inicies sesión recibirás un código de seguridad en tu correo.'
                        : 'Al desactivarla, podrás iniciar sesión directamente sin código adicional.',
                    style: GoogleFonts.manrope(
                        color: Colors.white.withValues(alpha: 0.6),
                        fontSize: 13,
                        height: 1.5),
                  ),
                  const SizedBox(height: 20),
                  if (!codigoEnviado) ...[
                    _SheetButton(
                      label: 'Enviar código a mi correo',
                      color: AppColors.button,
                      cargando: cargando,
                      icon: Icons.email_outlined,
                      onPressed: () async {
                        setSheet(() => cargando = true);
                        try {
                          final auth = Provider.of<AuthProvider>(
                              context,
                              listen: false);
                          await auth.solicitarCodigoEmail2FA();
                          setSheet(() {
                            codigoEnviado = true;
                            cargando = false;
                          });
                        } catch (e) {
                          setSheet(() => cargando = false);
                          if (mounted) {
                            _snack(
                                e.toString().replaceAll('Exception: ', ''),
                                error: true);
                          }
                        }
                      },
                    ),
                  ] else ...[
                    _campoSheet(
                      ctrl: codigoCtrl,
                      label: 'Código de 6 dígitos',
                      oculto: false,
                      onToggle: () {},
                      validator: (v) =>
                          (v == null || v.trim().length != 6)
                              ? 'Introduce el código de 6 dígitos'
                              : null,
                    ),
                    const SizedBox(height: 16),
                    _SheetButton(
                      label: activar
                          ? 'ACTIVAR VERIFICACIÓN'
                          : 'DESACTIVAR VERIFICACIÓN',
                      color: activar ? AppColors.button : AppColors.error,
                      cargando: cargando,
                      onPressed: () async {
                        if (!formKey.currentState!.validate()) return;
                        setSheet(() => cargando = true);
                        try {
                          final auth = Provider.of<AuthProvider>(
                              context,
                              listen: false);
                          if (activar) {
                            await auth
                                .activarEmail2FA(codigoCtrl.text.trim());
                          } else {
                            await auth.desactivarEmail2FA(
                                codigoCtrl.text.trim());
                          }
                          if (ctx.mounted) Navigator.pop(ctx);
                          if (mounted) {
                            setState(() {});
                            _snack(
                              activar
                                  ? 'Verificación por correo activada'
                                  : 'Verificación por correo desactivada',
                              success: activar,
                            );
                          }
                        } catch (e) {
                          setSheet(() => cargando = false);
                          if (mounted) {
                            _snack(
                                e.toString().replaceAll('Exception: ', ''),
                                error: true);
                          }
                        }
                      },
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _mostrarCambioContrasena() {
    final formKey = GlobalKey<FormState>();
    final actualCtrl = TextEditingController();
    final nuevaCtrl = TextEditingController();
    final confirmarCtrl = TextEditingController();
    bool verActual = false;
    bool verNueva = false;
    bool verConfirmar = false;
    bool cargando = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: _BottomSheetContainer(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _SheetHandle(),
                  const SizedBox(height: 20),
                  Text(
                    'Cambiar contraseña',
                    style: GoogleFonts.manrope(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 20),
                  _campoSheet(
                    ctrl: actualCtrl,
                    label: 'Contraseña actual',
                    oculto: !verActual,
                    onToggle: () =>
                        setSheet(() => verActual = !verActual),
                    validator: (v) => (v == null || v.isEmpty)
                        ? 'Introduce tu contraseña actual'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  _campoSheet(
                    ctrl: nuevaCtrl,
                    label: 'Nueva contraseña',
                    oculto: !verNueva,
                    onToggle: () =>
                        setSheet(() => verNueva = !verNueva),
                    validator: (v) {
                      if (v == null || v.isEmpty) {
                        return 'Introduce la nueva contraseña';
                      }
                      if (v.length < 8) return 'Mínimo 8 caracteres';
                      if (!RegExp(r'[A-Z]').hasMatch(v)) {
                        return 'Falta una mayúscula';
                      }
                      if (!RegExp(r'[0-9]').hasMatch(v)) {
                        return 'Falta un número';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  _campoSheet(
                    ctrl: confirmarCtrl,
                    label: 'Confirmar nueva contraseña',
                    oculto: !verConfirmar,
                    onToggle: () =>
                        setSheet(() => verConfirmar = !verConfirmar),
                    validator: (v) => v != nuevaCtrl.text
                        ? 'Las contraseñas no coinciden'
                        : null,
                  ),
                  const SizedBox(height: 24),
                  _SheetButton(
                    label: 'CAMBIAR CONTRASEÑA',
                    color: AppColors.button,
                    cargando: cargando,
                    onPressed: () async {
                      if (!formKey.currentState!.validate()) return;
                      setSheet(() => cargando = true);
                      try {
                        final auth = Provider.of<AuthProvider>(
                            context,
                            listen: false);
                        await auth.cambiarContrasena(
                          passwordActual: actualCtrl.text,
                          nuevaPassword: nuevaCtrl.text,
                        );
                        if (ctx.mounted) Navigator.pop(ctx);
                        if (mounted) {
                          _snack('Contraseña actualizada correctamente',
                              success: true);
                        }
                      } catch (e) {
                        if (ctx.mounted) {
                          setSheet(() => cargando = false);
                        }
                        if (mounted) {
                          _snack(
                              e.toString().replaceAll('Exception: ', ''),
                              error: true);
                        }
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _campoSheet({
    required TextEditingController ctrl,
    required String label,
    required bool oculto,
    required VoidCallback onToggle,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: ctrl,
      obscureText: oculto,
      validator: validator,
      style: GoogleFonts.manrope(color: Colors.white, fontSize: 15),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.manrope(
            color: Colors.white.withValues(alpha: 0.5), fontSize: 14),
        prefixIcon: const Icon(Icons.lock_outline,
            color: AppColors.button, size: 20),
        suffixIcon: IconButton(
          icon: Icon(
              oculto
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined,
              color: Colors.white38,
              size: 20),
          onPressed: onToggle,
        ),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.07),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.white24),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.button, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.error, width: 2),
        ),
        errorStyle: const TextStyle(color: AppColors.error),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }

  Future<void> _recargarPerfil() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    await auth.cargarSesion();
    if (!mounted) return;
    final usuario = auth.usuarioActual;
    setState(() {
      _nombreController.text = usuario?.nombre ?? '';
      _emailController.text = usuario?.email ?? '';
      _telefonoController.text = usuario?.telefono ?? '';
      _direccionController.text = usuario?.direccion ?? '';
      _hayCambios = false;
    });
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final usuario =
        Provider.of<AuthProvider>(context, listen: false).usuarioActual;
    final iniciales = (usuario?.nombre ?? 'U')
        .trim()
        .split(' ')
        .where((w) => w.isNotEmpty)
        .take(2)
        .map((w) => w[0].toUpperCase())
        .join();

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset('assets/images/Bravo restaurante.jpg',
                fit: BoxFit.cover),
          ),
          Positioned.fill(
            child: Container(
                color: Colors.black.withValues(alpha: 0.82)),
          ),
          SafeArea(
            child: Column(
              children: [
                _buildAppBar(),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _recargarPerfil,
                    color: AppColors.button,
                    child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(
                        parent: BouncingScrollPhysics()),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 24),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          const SizedBox(height: 28),
                          _buildAvatar(iniciales),
                          const SizedBox(height: 32),
                          _buildSeccionLabel('DATOS PERSONALES'),
                          const SizedBox(height: 14),
                          _buildCampo(
                            'Nombre completo',
                            _nombreController,
                            Icons.person_outline,
                            autofillHints: const [AutofillHints.name],
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) {
                                return 'El nombre es obligatorio';
                              }
                              if (v.trim().length < 2) {
                                return 'Mínimo 2 caracteres';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 12),
                          _buildCampo(
                            'Correo electrónico',
                            _emailController,
                            Icons.email_outlined,
                            keyboardType: TextInputType.emailAddress,
                            autofillHints: const [AutofillHints.email],
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) {
                                return 'El email es obligatorio';
                              }
                              if (!RegExp(r'^[\w\.-]+@[\w\.-]+\.\w{2,}$')
                                  .hasMatch(v.trim())) {
                                return 'Email no válido';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 12),
                          _buildCampo(
                            'Teléfono',
                            _telefonoController,
                            Icons.phone_outlined,
                            keyboardType: TextInputType.phone,
                            autofillHints: const [AutofillHints.telephoneNumber],
                            inputFormatters: [LengthLimitingTextInputFormatter(15)],
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) {
                                return 'El teléfono es obligatorio';
                              }
                              if (!RegExp(r'^\+?\d{6,15}$')
                                  .hasMatch(v.trim())) {
                                return 'Teléfono no válido';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 12),
                          GestureDetector(
                            onTap: _abrirSelectorDireccion,
                            child: AbsorbPointer(
                              child: _buildCampo(
                                'Dirección de entrega',
                                _direccionController,
                                Icons.map_outlined,
                                readOnly: true,
                                suffixIcon: const Icon(
                                    Icons.chevron_right,
                                    color: AppColors.button,
                                    size: 20),
                                validator: (v) {
                                  if (v == null || v.trim().isEmpty) {
                                    return 'La dirección es obligatoria';
                                  }
                                  return null;
                                },
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Botón guardar
                          SizedBox(
                            width: double.infinity,
                            height: 52,
                            child: ElevatedButton(
                              onPressed: (_hayCambios && !_isLoading)
                                  ? _guardarCambios
                                  : null,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.button,
                                disabledBackgroundColor:
                                    Colors.white.withValues(alpha: 0.08),
                                foregroundColor: Colors.white,
                                disabledForegroundColor: Colors.white38,
                                shape: RoundedRectangleBorder(
                                    borderRadius:
                                        BorderRadius.circular(12)),
                                elevation: 0,
                              ),
                              child: _isLoading
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                          color: Colors.white,
                                          strokeWidth: 2))
                                  : Text(
                                      _hayCambios
                                          ? 'GUARDAR CAMBIOS'
                                          : 'SIN CAMBIOS',
                                      style: GoogleFonts.manrope(
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 1.5,
                                          fontSize: 13),
                                    ),
                            ),
                          ),

                          const SizedBox(height: 36),
                          _buildSeccionLabel('CUENTA'),
                          const SizedBox(height: 14),

                          _buildAccion(
                            icono: Icons.lock_outline,
                            label: 'Cambiar contraseña',
                            onTap: _mostrarCambioContrasena,
                          ),
                          const SizedBox(height: 10),
                          Consumer<AuthProvider>(
                            builder: (_, auth, _) {
                              final totp2fa =
                                  auth.usuarioActual?.totpEnabled ?? false;
                              return _buildAccion2fa(habilitado: totp2fa);
                            },
                          ),
                          const SizedBox(height: 10),
                          Consumer<AuthProvider>(
                            builder: (_, auth, _) {
                              final email2fa = auth.usuarioActual
                                      ?.emailDosFactoresEnabled ??
                                  true;
                              return _buildAccionEmail2fa(
                                  habilitado: email2fa);
                            },
                          ),
                          const SizedBox(height: 10),
                          if (usuario?.rol == RolUsuario.cliente) ...[
                            _buildAccion(
                              icono: Icons.receipt_long_outlined,
                              label: 'Historial de pedidos',
                              onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) =>
                                          const HistorialPedidosScreen())),
                            ),
                            const SizedBox(height: 10),
                          ],
                          _buildAccion(
                            icono: Icons.logout,
                            label: 'Cerrar sesión',
                            onTap: () async {
                              final auth = Provider.of<AuthProvider>(
                                  context,
                                  listen: false);
                              final cart = Provider.of<CartProvider>(
                                  context,
                                  listen: false);
                              await auth.cerrarSesion();
                              if (!context.mounted) return;
                              cart.limpiarRestaurante();
                              Navigator.of(context).pushAndRemoveUntil(
                                MaterialPageRoute(
                                    builder: (_) => const HomeScreen()),
                                (route) => false,
                              );
                            },
                          ),
                          const SizedBox(height: 10),
                          _buildAccion(
                            icono: Icons.delete_outline,
                            label: 'Eliminar cuenta',
                            onTap: _mostrarDialogoEliminarCuenta,
                            isDestructive: true,
                          ),
                          const SizedBox(height: 40),
                        ],
                      ),
                    ),
                  ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Widgets de layout ─────────────────────────────────────────────────────

  Widget _buildAppBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new,
                color: Colors.white, size: 20),
            onPressed: () => Navigator.pop(context),
          ),
          Expanded(
            child: Text(
              'MI PERFIL',
              textAlign: TextAlign.center,
              style: GoogleFonts.manrope(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                letterSpacing: 2.5,
                fontSize: 15,
              ),
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }

  Widget _buildAvatar(String iniciales) {
    return Column(
      children: [
        Container(
          width: 88,
          height: 88,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.button.withValues(alpha: 0.15),
            border: Border.all(color: AppColors.button, width: 2),
          ),
          child: Center(
            child: Text(
              iniciales,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 30,
                fontWeight: FontWeight.bold,
                fontFamily: 'Playfair Display',
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        Consumer<AuthProvider>(
          builder: (_, auth, _) => Column(
            children: [
              Text(
                auth.usuarioActual?.nombre ?? '',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Playfair Display',
                ),
              ),
              const SizedBox(height: 4),
              Text(
                auth.usuarioActual?.email ?? '',
                style: GoogleFonts.manrope(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: 13),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSeccionLabel(String titulo) {
    return Row(
      children: [
        Text(
          titulo,
          style: GoogleFonts.manrope(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 2.5,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(child: Container(height: 1, color: Colors.white12)),
      ],
    );
  }

  Widget _buildCampo(
    String label,
    TextEditingController controller,
    IconData icono, {
    String? Function(String?)? validator,
    TextInputType? keyboardType,
    bool readOnly = false,
    Widget? suffixIcon,
    List<String>? autofillHints,
    TextInputAction textInputAction = TextInputAction.next,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return TextFormField(
      controller: controller,
      validator: validator,
      keyboardType: keyboardType,
      readOnly: readOnly,
      autofillHints: autofillHints,
      textInputAction: textInputAction,
      inputFormatters: inputFormatters,
      style: GoogleFonts.manrope(color: Colors.white, fontSize: 15),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.manrope(
            color: Colors.white.withValues(alpha: 0.5), fontSize: 14),
        prefixIcon: Icon(icono, color: AppColors.button, size: 20),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.07),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.white24),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.button, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
              const BorderSide(color: AppColors.error, width: 2),
        ),
        errorStyle: const TextStyle(color: AppColors.error),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }

  Widget _buildAccion({
    required IconData icono,
    required String label,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    final color = isDestructive ? AppColors.error : Colors.white;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        decoration: BoxDecoration(
          color: isDestructive
              ? AppColors.error.withValues(alpha: 0.08)
              : Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDestructive
                ? AppColors.error.withValues(alpha: 0.3)
                : Colors.white12,
          ),
        ),
        child: Row(
          children: [
            Icon(icono,
                color: isDestructive ? AppColors.error : Colors.white70,
                size: 20),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: GoogleFonts.manrope(
                  color: color,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Icon(Icons.chevron_right,
                color: isDestructive
                    ? AppColors.error.withValues(alpha: 0.5)
                    : Colors.white24,
                size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildAccion2fa({required bool habilitado}) {
    return GestureDetector(
      onTap: habilitado ? _mostrarDesactivar2FA : _mostrarActivar2FA,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white12),
        ),
        child: Row(
          children: [
            Icon(
              habilitado
                  ? Icons.verified_user_outlined
                  : Icons.security_outlined,
              color: habilitado ? AppColors.disp : Colors.white70,
              size: 20,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Autenticación de dos factores',
                      style: GoogleFonts.manrope(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w500)),
                  const SizedBox(height: 2),
                  Text(
                    habilitado
                        ? 'Activada · toca para desactivar'
                        : 'No activada · toca para activar',
                    style: GoogleFonts.manrope(
                      color: habilitado
                          ? AppColors.disp.withValues(alpha: 0.8)
                          : Colors.white38,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right,
                color: Colors.white24, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildAccionEmail2fa({required bool habilitado}) {
    return GestureDetector(
      onTap: () => _mostrarGestionEmail2FA(activar: !habilitado),
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white12),
        ),
        child: Row(
          children: [
            Icon(
              habilitado
                  ? Icons.mark_email_read_outlined
                  : Icons.email_outlined,
              color: habilitado ? _kBlue2FA : Colors.white70,
              size: 20,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Verificación por correo',
                      style: GoogleFonts.manrope(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w500)),
                  const SizedBox(height: 2),
                  Text(
                    habilitado
                        ? 'Activada · toca para desactivar'
                        : 'No activada · toca para activar',
                    style: GoogleFonts.manrope(
                      color: habilitado
                          ? _kBlue2FA.withValues(alpha: 0.8)
                          : Colors.white38,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right,
                color: Colors.white24, size: 20),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Widgets auxiliares de BottomSheet
// ─────────────────────────────────────────────────────────────────────────────

class _BottomSheetContainer extends StatelessWidget {
  const _BottomSheetContainer({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.gold,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
      child: child,
    );
  }
}

class _SheetHandle extends StatelessWidget {
  const _SheetHandle();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 40,
        height: 4,
        decoration: BoxDecoration(
          color: Colors.white24,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}

class _SheetButton extends StatelessWidget {
  const _SheetButton({
    required this.label,
    required this.color,
    required this.cargando,
    required this.onPressed,
    this.icon,
  });
  final String label;
  final Color color;
  final bool cargando;
  final VoidCallback onPressed;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          disabledBackgroundColor: Colors.white12,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
          elevation: 0,
        ),
        onPressed: cargando ? null : onPressed,
        child: cargando
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2))
            : icon != null
                ? Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(icon, size: 18),
                      const SizedBox(width: 8),
                      Text(label,
                          style: GoogleFonts.manrope(
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.8,
                              fontSize: 13)),
                    ],
                  )
                : Text(label,
                    style: GoogleFonts.manrope(
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                        fontSize: 13)),
      ),
    );
  }
}

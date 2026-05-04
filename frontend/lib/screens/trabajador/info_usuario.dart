import 'package:flutter/material.dart';
import 'package:frontend/screens/Cliente/direccion_screen.dart';
import 'package:frontend/screens/Cliente/historial_pedidos_screen.dart';
import 'package:frontend/screens/Cliente/totp_setup_screen.dart';
import 'package:frontend/screens/Cliente/login_screen.dart';
import 'package:frontend/screens/home_screen_trabajador.dart';
import 'package:provider/provider.dart';
import '../../core/colors_style.dart';
import '../../models/usuario_model.dart';
import '../../providers/auth_provider.dart';

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
    _direccionController = TextEditingController(
      text: usuario?.direccion ?? '',
    );

    _telefonoController.addListener(_detectarCambios);
    _direccionController.addListener(_detectarCambios);
  }

  void _detectarCambios() {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final usuario = auth.usuarioActual;
    final cambio =
        _telefonoController.text != (usuario?.telefono ?? '') ||
        _direccionController.text != (usuario?.direccion ?? '');
    if (cambio != _hayCambios) {
      setState(() => _hayCambios = cambio);
    }
  }

  @override
  void dispose() {
    _telefonoController.removeListener(_detectarCambios);
    _direccionController.removeListener(_detectarCambios);
    _nombreController.dispose();
    _emailController.dispose();
    _telefonoController.dispose();
    _direccionController.dispose();
    super.dispose();
  }

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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Datos actualizados correctamente'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
      setState(() => _hayCambios = false);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
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
        title: const Row(
          children: [
            Icon(
              Icons.warning_amber_rounded,
              color: Colors.redAccent,
              size: 26,
            ),
            SizedBox(width: 10),
            Text(
              'Eliminar cuenta',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: const Text(
          '¿Estás seguro? Esta acción no se puede deshacer y perderás todos tus datos.',
          style: TextStyle(color: Colors.white60, fontSize: 14, height: 1.5),
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
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.zero,
                    ),
                  ),
                  child: const Text(
                    'CANCELAR',
                    style: TextStyle(fontSize: 13, letterSpacing: 1),
                  ),
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
                    backgroundColor: Colors.redAccent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.zero,
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    'ELIMINAR',
                    style: TextStyle(
                      fontSize: 13,
                      letterSpacing: 1,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al eliminar cuenta: ${e.toString()}'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
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
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: Container(
            decoration: const BoxDecoration(
              color: AppColors.gold,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Desactivar 2FA',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Playfair Display',
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Introduce el código de Google Authenticator para confirmar.',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.6),
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 20),
                  _campoSheet(
                    ctrl: codigoCtrl,
                    label: 'Código de 6 dígitos',
                    oculto: false,
                    onToggle: () {},
                    validator: (v) {
                      if (v == null || v.trim().length != 6)
                        return 'Introduce el código de 6 dígitos';
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: Colors.white12,
                        shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.zero,
                        ),
                        elevation: 0,
                      ),
                      onPressed: cargando
                          ? null
                          : () async {
                              if (!formKey.currentState!.validate()) return;
                              setSheet(() => cargando = true);
                              try {
                                final auth = Provider.of<AuthProvider>(
                                  context,
                                  listen: false,
                                );
                                await auth.desactivar2fa(
                                  codigoCtrl.text.trim(),
                                );
                                if (ctx.mounted) Navigator.pop(ctx);
                                if (mounted) {
                                  setState(() {});
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        '2FA desactivado correctamente',
                                      ),
                                      backgroundColor: Colors.green,
                                      behavior: SnackBarBehavior.floating,
                                    ),
                                  );
                                }
                              } catch (e) {
                                if (ctx.mounted)
                                  setSheet(() => cargando = false);
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        e.toString().replaceAll(
                                          'Exception: ',
                                          '',
                                        ),
                                      ),
                                      backgroundColor: AppColors.error,
                                      behavior: SnackBarBehavior.floating,
                                    ),
                                  );
                                }
                              }
                            },
                      child: cargando
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Text(
                              'DESACTIVAR 2FA',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.5,
                                fontSize: 13,
                              ),
                            ),
                    ),
                  ),
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
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: Container(
            decoration: const BoxDecoration(
              color: AppColors.gold,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Handle
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Cambiar contraseña',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Playfair Display',
                    ),
                  ),
                  const SizedBox(height: 20),
                  _campoSheet(
                    ctrl: actualCtrl,
                    label: 'Contraseña actual',
                    oculto: !verActual,
                    onToggle: () => setSheet(() => verActual = !verActual),
                    validator: (v) => (v == null || v.isEmpty)
                        ? 'Introduce tu contraseña actual'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  _campoSheet(
                    ctrl: nuevaCtrl,
                    label: 'Nueva contraseña',
                    oculto: !verNueva,
                    onToggle: () => setSheet(() => verNueva = !verNueva),
                    validator: (v) {
                      if (v == null || v.isEmpty)
                        return 'Introduce la nueva contraseña';
                      if (v.length < 8) return 'Mínimo 8 caracteres';
                      if (!RegExp(r'[A-Z]').hasMatch(v))
                        return 'Falta una mayúscula';
                      if (!RegExp(r'[0-9]').hasMatch(v))
                        return 'Falta un número';
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
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.button,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: Colors.white12,
                        shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.zero,
                        ),
                        elevation: 0,
                      ),
                      onPressed: cargando
                          ? null
                          : () async {
                              if (!formKey.currentState!.validate()) return;
                              setSheet(() => cargando = true);
                              try {
                                final auth = Provider.of<AuthProvider>(
                                  context,
                                  listen: false,
                                );
                                await auth.cambiarContrasena(
                                  passwordActual: actualCtrl.text,
                                  nuevaPassword: nuevaCtrl.text,
                                );
                                if (ctx.mounted) Navigator.pop(ctx);
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Contraseña actualizada correctamente',
                                      ),
                                      backgroundColor: Colors.green,
                                      behavior: SnackBarBehavior.floating,
                                    ),
                                  );
                                }
                              } catch (e) {
                                if (ctx.mounted)
                                  setSheet(() => cargando = false);
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        e.toString().replaceAll(
                                          'Exception: ',
                                          '',
                                        ),
                                      ),
                                      backgroundColor: AppColors.error,
                                      behavior: SnackBarBehavior.floating,
                                    ),
                                  );
                                }
                              }
                            },
                      child: cargando
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Text(
                              'CAMBIAR CONTRASEÑA',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.5,
                                fontSize: 13,
                              ),
                            ),
                    ),
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
      style: const TextStyle(color: Colors.white, fontSize: 15),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
          color: Colors.white.withValues(alpha: 0.5),
          fontSize: 14,
        ),
        prefixIcon: const Icon(
          Icons.lock_outline,
          color: AppColors.button,
          size: 20,
        ),
        suffixIcon: IconButton(
          icon: Icon(
            oculto ? Icons.visibility_off_outlined : Icons.visibility_outlined,
            color: Colors.white38,
            size: 20,
          ),
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
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final usuario = Provider.of<AuthProvider>(
      context,
      listen: false,
    ).usuarioActual;
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
          // Fondo
          Positioned.fill(
            child: Image.asset(
              'assets/images/Bravo restaurante.jpg',
              fit: BoxFit.cover,
            ),
          ),
          Positioned.fill(
            child: Container(color: Colors.black.withValues(alpha: 0.82)),
          ),

          SafeArea(
            child: Column(
              children: [
                _buildAppBar(),
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          const SizedBox(height: 28),
                          _buildAvatar(iniciales),
                          const SizedBox(height: 32),
                          _buildSeccionLabel('DATOS PERSONALES'),
                          const SizedBox(height: 14),
                          _buildCampoInfo(
                            'Nombre completo',
                            _nombreController.text,
                            Icons.person_outline,
                          ),
                          const SizedBox(height: 12),
                          _buildCampoInfo(
                            'Correo electrónico',
                            _emailController.text,
                            Icons.email_outlined,
                          ),
                          const SizedBox(height: 12),
                          _buildCampo(
                            'Teléfono',
                            _telefonoController,
                            Icons.phone_outlined,
                            keyboardType: TextInputType.phone,
                            validator: (v) {
                              if (v == null || v.trim().isEmpty)
                                return 'El teléfono es obligatorio';
                              if (!RegExp(r'^\+?\d{6,15}$').hasMatch(v.trim()))
                                return 'Teléfono no válido';
                              return null;
                            },
                          ),
                          const SizedBox(height: 12),
                          GestureDetector(
                            onTap: _abrirSelectorDireccion,
                            child: AbsorbPointer(
                              child: _buildCampo(
                                'Dirección',
                                _direccionController,
                                Icons.map_outlined,
                                readOnly: true,
                                suffixIcon: const Icon(
                                  Icons.chevron_right,
                                  color: AppColors.button,
                                  size: 20,
                                ),
                                validator: (v) {
                                  if (v == null || v.trim().isEmpty)
                                    return 'La dirección es obligatoria';
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
                                disabledBackgroundColor: Colors.white
                                    .withValues(alpha: 0.08),
                                foregroundColor: Colors.white,
                                disabledForegroundColor: Colors.white38,
                                shape: const RoundedRectangleBorder(
                                  borderRadius: BorderRadius.zero,
                                ),
                                elevation: 0,
                              ),
                              child: _isLoading
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : Text(
                                      _hayCambios
                                          ? 'GUARDAR CAMBIOS'
                                          : 'SIN CAMBIOS',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 2,
                                        fontSize: 13,
                                      ),
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
                          if (usuario?.rol == RolUsuario.cliente) ...[
                            _buildAccion(
                              icono: Icons.receipt_long_outlined,
                              label: 'Historial de pedidos',
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      const HistorialPedidosScreen(),
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                          ],
                          _buildAccion(
                            icono: Icons.logout,
                            label: 'Cerrar sesión',
                            onTap: () async {
                              await Provider.of<AuthProvider>(
                                context,
                                listen: false,
                              ).cerrarSesion();
                              if (!context.mounted) return;
                              Navigator.of(context).pushAndRemoveUntil(
                                MaterialPageRoute(
                                  builder: (_) => const HomeTrabajador(),
                                ),
                                (route) => false,
                              );
                            },
                          ),
                          const SizedBox(height: 10),
                          _buildAccion(
                            icono: Icons.delete_outline,
                            label: 'Eliminar cuenta',
                            color: Colors.redAccent,
                            onTap: _mostrarDialogoEliminarCuenta,
                          ),
                          const SizedBox(height: 40),
                        ],
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

  Widget _buildAppBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(
              Icons.arrow_back_ios_new,
              color: Colors.white,
              size: 20,
            ),
            onPressed: () => Navigator.pop(context),
          ),
          const Expanded(
            child: Text(
              'MI PERFIL',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                letterSpacing: 2.5,
                fontSize: 15,
              ),
            ),
          ),
          const SizedBox(width: 48), // balance del back button
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
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.5),
                  fontSize: 13,
                ),
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
          style: const TextStyle(
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

  Widget _buildCampoInfo(String label, String valor, IconData icono) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white24),
      ),
      child: Row(
        children: [
          Icon(icono, color: AppColors.button, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  valor,
                  style: const TextStyle(color: Colors.white, fontSize: 15),
                ),
              ],
            ),
          ),
        ],
      ),
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
  }) {
    return TextFormField(
      controller: controller,
      validator: validator,
      keyboardType: keyboardType,
      readOnly: readOnly,
      style: const TextStyle(color: Colors.white, fontSize: 15),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
          color: Colors.white.withValues(alpha: 0.5),
          fontSize: 14,
        ),
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
          borderSide: const BorderSide(color: AppColors.error, width: 2),
        ),
        errorStyle: const TextStyle(color: AppColors.error),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),
    );
  }

  Widget _buildAccion2fa({required bool habilitado}) {
    return GestureDetector(
      onTap: habilitado ? _mostrarDesactivar2FA : _mostrarActivar2FA,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
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
              color: habilitado ? Colors.greenAccent : Colors.white70,
              size: 20,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Autenticación de dos factores',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    habilitado
                        ? 'Activada — toca para desactivar'
                        : 'No activada — toca para activar',
                    style: TextStyle(
                      color: habilitado
                          ? Colors.greenAccent.withValues(alpha: 0.8)
                          : Colors.white38,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.white24, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildAccion({
    required IconData icono,
    required String label,
    required VoidCallback onTap,
    Color color = Colors.white,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        decoration: BoxDecoration(
          color: color == Colors.redAccent
              ? Colors.redAccent.withValues(alpha: 0.08)
              : Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: color == Colors.redAccent
                ? Colors.redAccent.withValues(alpha: 0.3)
                : Colors.white12,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icono,
              color: color == Colors.white ? Colors.white70 : color,
              size: 20,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: color == Colors.white ? Colors.white : color,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: color == Colors.white
                  ? Colors.white24
                  : color.withValues(alpha: 0.5),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}

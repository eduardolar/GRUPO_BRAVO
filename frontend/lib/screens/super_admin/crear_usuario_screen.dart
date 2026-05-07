import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

import '../../core/colors_style.dart';
import '../../providers/restaurante_provider.dart';
import '../../services/api_config.dart';
import '../../services/auth_session.dart';
import '../../services/http_client.dart';
import '../../components/Cliente/entrada_texto.dart';

/// Pantalla para crear un usuario desde el panel de super_admin.
///
/// - Si recibe [restauranteId], opera en modo **contextualizado**: la sucursal
///   queda fija y no se muestra el selector.  El [rolFijo] también puede fijar
///   el rol (p.ej. 'administrador' al crear desde SucursalDetailScreen).
///
/// - Si NO recibe [restauranteId] (modo **libre**), muestra dropdown de
///   sucursal y dropdown de rol con la whitelist [admin, cocinero, camarero].
///   Ambos son obligatorios antes de enviar.
class CrearUsuarioScreen extends StatefulWidget {
  /// Sucursal preseleccionada. Si es null la pantalla entra en modo libre.
  final String? restauranteId;

  /// Si se pasa, el rol queda fijo y no se muestra el dropdown de rol.
  final String? rolFijo;

  const CrearUsuarioScreen({super.key, this.restauranteId, this.rolFijo});

  @override
  State<CrearUsuarioScreen> createState() => _CrearUsuarioScreenState();
}

// ─── Roles permitidos para creación libre por super_admin ────────────────────
const _kRolesLibres = [
  _RolOpcion('admin', 'Admin'),
  _RolOpcion('cocinero', 'Cocinero'),
  _RolOpcion('camarero', 'Camarero'),
];

class _RolOpcion {
  final String valor;
  final String etiqueta;
  const _RolOpcion(this.valor, this.etiqueta);
}

// ─── State ───────────────────────────────────────────────────────────────────

class _CrearUsuarioScreenState extends State<CrearUsuarioScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nombreCtrl = TextEditingController();
  final _correoCtrl = TextEditingController();

  // En modo libre estos se inicializan a null y son obligatorios.
  String? _rolSeleccionado;
  String? _sucursalSeleccionadaId;

  bool _cargando = false;

  /// Modo libre: el super_admin no pasó restauranteId por constructor.
  bool get _modoLibre => widget.restauranteId == null;

  @override
  void initState() {
    super.initState();
    if (!_modoLibre) {
      // Modo contextualizado: usamos el rol fijo o camarero por defecto.
      _rolSeleccionado = widget.rolFijo ?? 'camarero';
      _sucursalSeleccionadaId = widget.restauranteId;
    } else {
      // Modo libre: precargamos sucursales si aún no están.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final prov = context.read<RestauranteProvider>();
        if (prov.restaurantes.isEmpty && !prov.cargando) prov.cargar();
      });
    }
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _correoCtrl.dispose();
    super.dispose();
  }

  // ── Guardar ──────────────────────────────────────────────────────────────

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;

    // Validación extra para el modo libre.
    if (_modoLibre) {
      if (_sucursalSeleccionadaId == null || _sucursalSeleccionadaId!.isEmpty) {
        _snackError('Selecciona una sucursal');
        return;
      }
      if (_rolSeleccionado == null || _rolSeleccionado!.isEmpty) {
        _snackError('Selecciona un rol');
        return;
      }
    }

    setState(() => _cargando = true);

    final correo = _correoCtrl.text.trim();

    try {
      // Llamada directa al backend para capturar códigos de estado específicos.
      final body = <String, dynamic>{
        'nombre': _nombreCtrl.text.trim(),
        'correo': correo,
        'rol': _rolSeleccionado!,
        'restaurante_id': _sucursalSeleccionadaId!,
      };

      final response = await http
          .post(
            Uri.parse('$baseUrl/usuarios/'),
            headers: AuthSession.headers(),
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 20));

      if (!mounted) return;

      if (response.statusCode == 200 || response.statusCode == 201) {
        await _mostrarExito(correo);
        if (mounted) Navigator.pop(context);
        return;
      }

      // Errores específicos del backend:
      final decoded = decodeBody(response);
      final detail = (decoded['detail'] ?? '').toString().toLowerCase();

      switch (response.statusCode) {
        case 409:
          _snackError('Ya existe un usuario con ese correo');
        case 403:
          _snackError('No puedes crear este tipo de usuario');
        case 404:
          _snackError('Sucursal no encontrada');
        case 422:
          if (detail.contains('restaurante')) {
            _snackError('Selecciona una sucursal');
          } else {
            _snackError('Datos incorrectos: revisa los campos');
          }
        default:
          _snackError(
            decoded['detail']?.toString() ?? 'Error al crear el usuario',
          );
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      _snackError(e.message);
    } catch (_) {
      if (!mounted) return;
      _snackError('Error de conexión. Comprueba la red');
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  // ── Diálogo de éxito ──────────────────────────────────────────────────────

  Future<void> _mostrarExito(String correo) async {
    final esAdmin =
        _rolSeleccionado == 'admin' || _rolSeleccionado == 'administrador';
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.background,
        shape: const RoundedRectangleBorder(),
        title: Row(
          children: [
            const Icon(Icons.mark_email_read_outlined, color: AppColors.button),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                esAdmin ? '¡Administrador creado!' : '¡Personal registrado!',
                style: GoogleFonts.manrope(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              esAdmin
                  ? 'Se ha enviado un correo de activación al nuevo administrador:'
                  : 'Se ha enviado un correo de activación al nuevo empleado:',
              style: GoogleFonts.manrope(
                color: AppColors.textSecondary,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              color: AppColors.panel,
              child: Text(
                correo,
                style: GoogleFonts.manrope(
                  fontWeight: FontWeight.w700,
                  color: AppColors.button,
                  fontSize: 13,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'El usuario debe abrir la app, ir a "Activar mi cuenta" e '
              'ingresar el código recibido para establecer su contraseña.',
              style: GoogleFonts.manrope(
                color: AppColors.textSecondary,
                fontSize: 12,
                height: 1.5,
              ),
            ),
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.button,
                foregroundColor: Colors.white,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.zero,
                ),
                elevation: 0,
              ),
              onPressed: () => Navigator.pop(ctx),
              child: Text(
                'ENTENDIDO',
                style: GoogleFonts.manrope(
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  void _snackError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: GoogleFonts.manrope()),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ── BUILD ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/images/Bravo restaurante.jpg',
              fit: BoxFit.cover,
            ),
          ),
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.55),
                    Colors.black.withValues(alpha: 0.88),
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 500),
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 30,
                    vertical: 20,
                  ),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        _buildHeader(),
                        const SizedBox(height: 30),
                        _buildInputs(),
                        const SizedBox(height: 24),
                        _buildButton(),
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
              icon: const Icon(
                Icons.arrow_back_ios_new,
                color: Colors.white,
                size: 20,
              ),
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final esAdmin =
        widget.rolFijo == 'administrador' || widget.rolFijo == 'admin';
    return Column(
      children: [
        const SizedBox(height: 40),
        Text(
          _modoLibre
              ? 'Nuevo Usuario'
              : (esAdmin ? 'Nuevo Administrador' : 'Nuevo Personal'),
          textAlign: TextAlign.center,
          style: const TextStyle(
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
          _modoLibre
              ? 'Crea un usuario y asígnalo a cualquier sucursal'
              : (esAdmin
                    ? 'Registra un administrador para esta sucursal'
                    : 'Registra al personal de esta sucursal'),
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.7),
            fontSize: 15,
          ),
        ),
      ],
    );
  }

  Widget _buildInputs() {
    return Column(
      children: [
        EntradaTexto(
          etiqueta: 'Nombre Completo',
          icono: Icons.badge_outlined,
          controlador: _nombreCtrl,
          validador: (v) =>
              v == null || v.isEmpty ? 'Este campo es obligatorio' : null,
        ),
        EntradaTexto(
          etiqueta: 'Correo Electrónico',
          icono: Icons.email_outlined,
          tipoTeclado: TextInputType.emailAddress,
          controlador: _correoCtrl,
          validador: (v) =>
              v == null || v.isEmpty ? 'Este campo es obligatorio' : null,
        ),

        // Dropdown de rol — solo cuando no hay rolFijo (ambos modos)
        if (widget.rolFijo == null) _buildDropdownRol(),

        // Dropdown de sucursal — solo en modo libre
        if (_modoLibre) _buildDropdownSucursal(),
      ],
    );
  }

  Widget _buildDropdownRol() {
    // En modo libre usamos la whitelist restringida (sin super_admin ni cliente).
    // En modo contextualizado sin rolFijo mostramos la whitelist igualmente.
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: DropdownButtonFormField<String>(
        initialValue: _rolSeleccionado,
        style: const TextStyle(color: Colors.white, fontSize: 14),
        decoration: InputDecoration(
          labelText: 'Asignar Rol',
          labelStyle: const TextStyle(color: Colors.white70),
          prefixIcon: const Icon(
            Icons.settings_accessibility_outlined,
            color: AppColors.bottomSheetBg,
          ),
          filled: true,
          fillColor: const Color(0x8C000000),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: const BorderSide(color: AppColors.line),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: const BorderSide(color: AppColors.button, width: 2),
          ),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: const BorderSide(color: AppColors.error),
          ),
        ),
        hint: const Text(
          'Selecciona un rol',
          style: TextStyle(color: Colors.white54),
        ),
        dropdownColor: AppColors.background,
        items: _kRolesLibres
            .map(
              (r) => DropdownMenuItem(
                value: r.valor,
                child: Text(r.etiqueta),
              ),
            )
            .toList(),
        onChanged: (val) => setState(() => _rolSeleccionado = val),
        validator: (v) =>
            v == null || v.isEmpty ? 'Selecciona un rol' : null,
      ),
    );
  }

  Widget _buildDropdownSucursal() {
    return Consumer<RestauranteProvider>(
      builder: (_, prov, _) {
        if (prov.cargando && prov.restaurantes.isEmpty) {
          return const Padding(
            padding: EdgeInsets.only(bottom: 20),
            child: Center(
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  color: AppColors.button,
                  strokeWidth: 2,
                ),
              ),
            ),
          );
        }

        // Solo mostramos sucursales activas (no suspendidas).
        final sucursales = prov.restaurantes
            .where((r) => !r.estaSuspendida)
            .toList();

        return Padding(
          padding: const EdgeInsets.only(bottom: 20),
          child: DropdownButtonFormField<String>(
            initialValue: _sucursalSeleccionadaId,
            style: const TextStyle(color: Colors.white, fontSize: 14),
            decoration: InputDecoration(
              labelText: 'Sucursal',
              labelStyle: const TextStyle(color: Colors.white70),
              prefixIcon: const Icon(
                Icons.storefront_outlined,
                color: AppColors.bottomSheetBg,
              ),
              filled: true,
              fillColor: const Color(0x8C000000),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15),
                borderSide: const BorderSide(color: AppColors.line),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15),
                borderSide:
                    const BorderSide(color: AppColors.button, width: 2),
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15),
                borderSide: const BorderSide(color: AppColors.error),
              ),
            ),
            hint: const Text(
              'Selecciona una sucursal',
              style: TextStyle(color: Colors.white54),
            ),
            dropdownColor: AppColors.background,
            items: sucursales
                .map(
                  (r) => DropdownMenuItem(
                    value: r.id,
                    child: Text(r.nombre),
                  ),
                )
                .toList(),
            onChanged: (val) =>
                setState(() => _sucursalSeleccionadaId = val),
            validator: (v) =>
                v == null || v.isEmpty ? 'Selecciona una sucursal' : null,
          ),
        );
      },
    );
  }

  Widget _buildButton() {
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
        onPressed: _cargando ? null : _guardar,
        child: _cargando
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : const Text(
                'CREAR USUARIO',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                ),
              ),
      ),
    );
  }
}

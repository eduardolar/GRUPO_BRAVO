import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:frontend/components/bravo_app_bar.dart';
import 'package:frontend/core/colors_style.dart';
import 'package:frontend/providers/usuario_provider.dart';
import 'package:frontend/providers/restaurante_provider.dart';
import 'package:frontend/models/restaurante_model.dart';
import 'gestion_usuarios_screen.dart';
import 'gestion_rol_screen.dart';
import 'sucursal_detail_screen.dart';
import 'pedidos_activos_screen.dart';
import 'contabilidad_screen.dart';
import 'actividad_screen.dart';
import 'kpis_globales_screen.dart';
import 'catalogo_masivo_screen.dart';
import 'cupones_screen.dart';

class HomeScreenSuperAdmin extends StatefulWidget {
  const HomeScreenSuperAdmin({super.key});

  @override
  State<HomeScreenSuperAdmin> createState() => _HomeScreenSuperAdminState();
}

class _HomeScreenSuperAdminState extends State<HomeScreenSuperAdmin> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<RestauranteProvider>().cargar();
      context.read<UsuarioProvider>().cargar();
    });
  }

  void _ir(BuildContext context, Widget screen) =>
      Navigator.push(context, MaterialPageRoute(builder: (_) => screen));

  // ── Validación de hora ──────────────────────────────────────────
  static String? _validarHora(String? v) {
    if (v == null || v.trim().isEmpty) return null;
    final parts = v.trim().split(':');
    if (parts.length != 2) return 'Usa HH:MM';
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null || h < 0 || h > 23 || m < 0 || m > 59) {
      return 'Hora inválida';
    }
    return null;
  }

  // ── Diálogo crear/editar sucursal ───────────────────────────────
  Future<void> _mostrarFormulario({Restaurante? restaurante}) async {
    final nombreCtrl =
        TextEditingController(text: restaurante?.nombre ?? '');
    final dirCtrl =
        TextEditingController(text: restaurante?.direccion ?? '');
    final apertCtrl =
        TextEditingController(text: restaurante?.horarioApertura ?? '');
    final cierreCtrl =
        TextEditingController(text: restaurante?.horarioCierre ?? '');
    final formKey = GlobalKey<FormState>();
    final esEdicion = restaurante != null;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.background,
        shape: const RoundedRectangleBorder(),
        title: Text(esEdicion ? 'Editar sucursal' : 'Nueva sucursal',
            style: GoogleFonts.manrope(fontWeight: FontWeight.w700)),
        content: Form(
          key: formKey,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            _campo(ctrl: nombreCtrl, label: 'Nombre',
                icon: Icons.storefront_outlined,
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Obligatorio' : null),
            const SizedBox(height: 12),
            _campo(ctrl: dirCtrl, label: 'Dirección',
                icon: Icons.location_on_outlined,
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Obligatorio' : null),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: _campo(ctrl: apertCtrl,
                  label: 'Apertura (HH:MM)', hint: '09:00',
                  icon: Icons.schedule_outlined,
                  keyboard: TextInputType.datetime,
                  validator: _validarHora)),
              const SizedBox(width: 10),
              Expanded(child: _campo(ctrl: cierreCtrl,
                  label: 'Cierre (HH:MM)', hint: '23:00',
                  icon: Icons.schedule_outlined,
                  keyboard: TextInputType.datetime,
                  validator: _validarHora)),
            ]),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false),
              child: Text('Cancelar',
                  style: GoogleFonts.manrope(color: AppColors.textSecondary))),
          TextButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(ctx, true);
              }
            },
            child: Text(esEdicion ? 'GUARDAR' : 'CREAR',
                style: GoogleFonts.manrope(
                    fontWeight: FontWeight.w700,
                    color: AppColors.button)),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    final provider = context.read<RestauranteProvider>();
    final nombre = nombreCtrl.text.trim();
    final direccion = dirCtrl.text.trim();
    final apertura = apertCtrl.text.trim();
    final cierre = cierreCtrl.text.trim();

    bool exito;
    if (esEdicion) {
      exito = await provider.editar(
          id: restaurante.id, nombre: nombre, direccion: direccion,
          horarioApertura: apertura, horarioCierre: cierre);
    } else {
      exito = await provider.crear(nombre: nombre, direccion: direccion);
    }
    if (mounted) {
      _snack(exito
          ? (esEdicion ? 'Sucursal actualizada' : 'Sucursal creada')
          : 'Error al guardar');
    }
  }

  // ── Confirmar borrado ───────────────────────────────────────────
  Future<void> _confirmarBorrado(Restaurante r) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.background,
        shape: const RoundedRectangleBorder(),
        title: Text('¿Eliminar sucursal?',
            style: GoogleFonts.manrope(fontWeight: FontWeight.w700)),
        content: Text(
            'Se eliminará "${r.nombre}" permanentemente.',
            style: GoogleFonts.manrope(
                color: AppColors.textSecondary, fontSize: 13)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false),
              child: Text('Cancelar',
                  style: GoogleFonts.manrope(
                      color: AppColors.textSecondary))),
          TextButton(onPressed: () => Navigator.pop(context, true),
              child: Text('Eliminar',
                  style: GoogleFonts.manrope(
                      color: AppColors.error,
                      fontWeight: FontWeight.w700))),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final exito =
        await context.read<RestauranteProvider>().eliminar(r.id);
    if (mounted) _snack(exito ? 'Sucursal eliminada' : 'Error al eliminar');
  }

  // ── Toggle activo ───────────────────────────────────────────────
  Future<void> _toggleActivo(Restaurante r, bool nuevo) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.background,
        shape: const RoundedRectangleBorder(),
        title: Text(nuevo ? 'Activar sucursal' : 'Suspender sucursal',
            style: GoogleFonts.manrope(fontWeight: FontWeight.w700)),
        content: Text(
            nuevo
                ? '¿Activar "${r.nombre}"? Volverá a aceptar pedidos.'
                : '¿Suspender "${r.nombre}"? No se aceptarán nuevos pedidos.',
            style: GoogleFonts.manrope(
                color: AppColors.textSecondary, fontSize: 13)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false),
              child: Text('Cancelar',
                  style: GoogleFonts.manrope(
                      color: AppColors.textSecondary))),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(nuevo ? 'ACTIVAR' : 'SUSPENDER',
                style: GoogleFonts.manrope(
                    fontWeight: FontWeight.w700,
                    color: nuevo ? AppColors.button : AppColors.error)),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final exito =
        await context.read<RestauranteProvider>().toggleActivo(r.id, nuevo);
    if (mounted) {
      _snack(exito
          ? 'Sucursal ${nuevo ? "activada" : "suspendida"}'
          : 'Error al cambiar estado');
    }
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg, style: GoogleFonts.manrope()),
          backgroundColor: AppColors.button,
          behavior: SnackBarBehavior.floating),
    );
  }

  // ── Campo helper para diálogos ──────────────────────────────────
  static Widget _campo({
    required TextEditingController ctrl,
    required String label,
    IconData? icon,
    String? hint,
    TextInputType? keyboard,
    FormFieldValidator<String>? validator,
  }) {
    return TextFormField(
      controller: ctrl,
      keyboardType: keyboard,
      style: GoogleFonts.manrope(color: AppColors.textPrimary),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle:
            GoogleFonts.manrope(fontSize: 13, color: AppColors.textSecondary),
        prefixIcon: icon != null
            ? Icon(icon, color: AppColors.button, size: 20)
            : null,
        filled: true,
        fillColor: Colors.white,
        border: const OutlineInputBorder(borderRadius: BorderRadius.zero),
        enabledBorder: const OutlineInputBorder(
            borderRadius: BorderRadius.zero,
            borderSide: BorderSide(color: AppColors.line)),
        focusedBorder: const OutlineInputBorder(
            borderRadius: BorderRadius.zero,
            borderSide: BorderSide(color: AppColors.button, width: 1.5)),
      ),
      validator: validator,
    );
  }

  // ── BUILD ────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: const BravoAppBar(title: "PANEL GLOBAL"),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/images/Bravo restaurante.jpg'),
            fit: BoxFit.cover,
          ),
        ),
        child: Container(
          width: double.infinity,
          height: double.infinity,
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
          child: SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 24.0, vertical: 16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "¡Hola, Super Admin!",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Panel de administración global del Grupo Bravo.",
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 28),

                    // ── SUCURSALES ───────────────────────────────────
                    _sectionLabel('SUCURSALES'),
                    const SizedBox(height: 12),
                    Consumer2<RestauranteProvider, UsuarioProvider>(
                      builder: (_, rProv, uProv, _) {
                        if (rProv.cargando) {
                          return const Padding(
                            padding: EdgeInsets.all(32),
                            child: Center(
                              child: CircularProgressIndicator(
                                  color: AppColors.button),
                            ),
                          );
                        }
                        if (rProv.error != null) {
                          return Padding(
                            padding: const EdgeInsets.all(16),
                            child: Text(
                                'Error al cargar sucursales: ${rProv.error}',
                                style: const TextStyle(color: Colors.white70)),
                          );
                        }
                        final lista = rProv.restaurantes;
                        return Column(children: [
                          for (var i = 0; i < lista.length; i++) ...[
                            _SucursalGlassCard(
                              restaurante: lista[i],
                              numero: i + 1,
                              personalCount: uProv.usuarios.where((u) {
                                final id = (u.restauranteId ?? '')
                                    .toString().trim().toLowerCase();
                                return id ==
                                        lista[i].id.trim().toLowerCase() &&
                                    u.rolRaw != 'cliente' &&
                                    u.rolRaw != 'superadministrador';
                              }).length,
                              onTap: () => _ir(
                                  context,
                                  SucursalDetailScreen(
                                      restauranteId: lista[i].id,
                                      restauranteNombre: lista[i].nombre)),
                              onEdit: () =>
                                  _mostrarFormulario(restaurante: lista[i]),
                              onDelete: () => _confirmarBorrado(lista[i]),
                              onToggleActivo: (v) =>
                                  _toggleActivo(lista[i], v),
                            ),
                            const SizedBox(height: 12),
                          ],
                          _NuevaSucursalGlass(
                              onTap: () => _mostrarFormulario()),
                        ]);
                      },
                    ),

                    const SizedBox(height: 28),

                    // ── HERRAMIENTAS GLOBALES ────────────────────────
                    _sectionLabel('HERRAMIENTAS GLOBALES'),
                    const SizedBox(height: 12),
                    Row(children: [
                      Expanded(
                        child: _GlassCard(
                          title: 'KPIs Globales',
                          subtitle: 'Ingresos por sucursal',
                          icon: Icons.bar_chart_rounded,
                          onTap: () =>
                              _ir(context, const KpisGlobalesScreen()),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _GlassCard(
                          title: 'Pedidos',
                          subtitle: 'Activos y globales',
                          icon: Icons.receipt_long_outlined,
                          onTap: () =>
                              _ir(context, const PedidosActivosScreen()),
                        ),
                      ),
                    ]),
                    const SizedBox(height: 16),
                    Row(children: [
                      Expanded(
                        child: _GlassCard(
                          title: 'Contabilidad',
                          subtitle: 'Ingresos globales',
                          icon: Icons.euro_outlined,
                          onTap: () =>
                              _ir(context, const ContabilidadScreen()),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _GlassCard(
                          title: 'Actividad',
                          subtitle: 'Auditoría de eventos',
                          icon: Icons.history_outlined,
                          onTap: () =>
                              _ir(context, const ActividadScreen()),
                        ),
                      ),
                    ]),
                    const SizedBox(height: 16),
                    Row(children: [
                      Expanded(
                        child: _GlassCard(
                          title: 'Catálogo',
                          subtitle: 'Precios y disponibilidad',
                          icon: Icons.edit_note_rounded,
                          onTap: () =>
                              _ir(context, const CatalogoMasivoScreen()),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _GlassCard(
                          title: 'Cupones',
                          subtitle: 'Promociones',
                          icon: Icons.local_offer_rounded,
                          onTap: () =>
                              _ir(context, const CuponesScreen()),
                        ),
                      ),
                    ]),

                    const SizedBox(height: 28),

                    // ── USUARIOS GLOBALES ────────────────────────────
                    _sectionLabel('USUARIOS GLOBALES'),
                    const SizedBox(height: 12),
                    Row(children: [
                      Expanded(
                        child: _GlassCard(
                          title: 'Trabajadores',
                          subtitle: 'Empleados del grupo',
                          icon: Icons.people_outline_rounded,
                          onTap: () => _ir(
                              context,
                              const GestionUsuariosScreen(
                                  rolAFiltrar: 'trabajador')),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _GlassCard(
                          title: 'Administradores',
                          subtitle: 'Gestores de sucursal',
                          icon: Icons.admin_panel_settings_outlined,
                          onTap: () => _ir(
                              context,
                              const GestionUsuariosScreen(
                                  rolAFiltrar: 'administrador')),
                        ),
                      ),
                    ]),
                    const SizedBox(height: 16),
                    Row(children: [
                      Expanded(
                        child: _GlassCard(
                          title: 'Clientes',
                          subtitle: 'Base de clientes',
                          icon: Icons.assignment_ind_outlined,
                          onTap: () => _ir(
                              context,
                              const GestionUsuariosScreen(
                                  rolAFiltrar: 'cliente')),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _GlassCard(
                          title: 'Permisos y Roles',
                          subtitle: 'Accesos globales',
                          icon: Icons.security_outlined,
                          onTap: () =>
                              _ir(context, const GestionRolesScreen()),
                        ),
                      ),
                    ]),
                    const SizedBox(height: 30),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _sectionLabel(String label) {
    return Row(children: [
      Container(width: 3, height: 18, color: AppColors.button),
      const SizedBox(width: 10),
      Text(label,
          style: GoogleFonts.manrope(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: Colors.white70,
              letterSpacing: 2)),
    ]);
  }
}

// ── Tarjeta glass para sucursal ───────────────────────────────────────────────
class _SucursalGlassCard extends StatelessWidget {
  final Restaurante restaurante;
  final int numero, personalCount;
  final VoidCallback onTap, onEdit, onDelete;
  final ValueChanged<bool> onToggleActivo;

  const _SucursalGlassCard({
    required this.restaurante,
    required this.numero,
    required this.personalCount,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
    required this.onToggleActivo,
  });

  @override
  Widget build(BuildContext context) {
    final r = restaurante;
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.45),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.15),
              width: 1.5,
            ),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              highlightColor: AppColors.button.withValues(alpha: 0.1),
              splashColor: AppColors.button.withValues(alpha: 0.2),
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: (r.activo
                                ? AppColors.button
                                : Colors.white24)
                            .withValues(alpha: r.activo ? 0.85 : 1),
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: Colors.white.withValues(alpha: 0.25),
                            width: 1),
                      ),
                      child: Text(
                        numero.toString().padLeft(2, '0'),
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                            letterSpacing: 1),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            Expanded(
                              child: Text(
                                r.nombre,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold),
                              ),
                            ),
                            const SizedBox(width: 6),
                            r.activo
                                ? _badgeEstado(r.estaAbierto())
                                : _badgeSuspendida(),
                          ]),
                          const SizedBox(height: 6),
                          Row(children: [
                            Icon(Icons.location_on_outlined,
                                size: 13,
                                color: Colors.white.withValues(alpha: 0.6)),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                r.direccion,
                                style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.white
                                        .withValues(alpha: 0.65)),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ]),
                          const SizedBox(height: 4),
                          Row(children: [
                            if (r.horarioApertura != null &&
                                r.horarioCierre != null) ...[
                              Icon(Icons.schedule_outlined,
                                  size: 13,
                                  color:
                                      Colors.white.withValues(alpha: 0.6)),
                              const SizedBox(width: 4),
                              Text(
                                  '${r.horarioApertura} - ${r.horarioCierre}',
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.white
                                          .withValues(alpha: 0.6))),
                              const SizedBox(width: 12),
                            ],
                            Icon(Icons.badge_outlined,
                                size: 13,
                                color:
                                    Colors.white.withValues(alpha: 0.6)),
                            const SizedBox(width: 4),
                            Text('$personalCount empleados',
                                style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.white
                                        .withValues(alpha: 0.6))),
                          ]),
                          const SizedBox(height: 8),
                          Text('GESTIONAR →',
                              style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.button
                                      .withValues(alpha: 0.95),
                                  letterSpacing: 1.5)),
                        ],
                      ),
                    ),
                    Column(children: [
                      Row(mainAxisSize: MainAxisSize.min, children: [
                        IconButton(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                              minWidth: 32, minHeight: 32),
                          icon: const Icon(Icons.edit_outlined,
                              size: 18, color: Colors.white70),
                          tooltip: 'Editar',
                          onPressed: onEdit,
                        ),
                        IconButton(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                              minWidth: 32, minHeight: 32),
                          icon: Icon(Icons.delete_outline,
                              size: 18,
                              color: AppColors.error
                                  .withValues(alpha: 0.85)),
                          tooltip: 'Eliminar',
                          onPressed: onDelete,
                        ),
                      ]),
                      Tooltip(
                        message: r.activo ? 'Suspender' : 'Activar',
                        child: Transform.scale(
                          scale: 0.7,
                          child: Switch.adaptive(
                            value: r.activo,
                            activeThumbColor: AppColors.button,
                            inactiveThumbColor: AppColors.error,
                            onChanged: onToggleActivo,
                          ),
                        ),
                      ),
                    ]),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _badgeEstado(bool abierto) {
    final color =
        abierto ? const Color(0xFF66BB6A) : AppColors.error;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(abierto ? 'ABIERTO' : 'CERRADO',
          style: TextStyle(
              fontSize: 8,
              fontWeight: FontWeight.w800,
              color: color,
              letterSpacing: 1)),
    );
  }

  Widget _badgeSuspendida() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.5)),
      ),
      child: const Text('SUSPENDIDA',
          style: TextStyle(
              fontSize: 8,
              fontWeight: FontWeight.w800,
              color: AppColors.error,
              letterSpacing: 1)),
    );
  }
}

// ── Botón "Nueva sucursal" glass ─────────────────────────────────────────────
class _NuevaSucursalGlass extends StatelessWidget {
  final VoidCallback onTap;
  const _NuevaSucursalGlass({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            highlightColor: AppColors.button.withValues(alpha: 0.1),
            splashColor: AppColors.button.withValues(alpha: 0.2),
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                color: AppColors.button.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: AppColors.button.withValues(alpha: 0.55),
                  width: 1.5,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.add_rounded, color: Colors.white),
                  const SizedBox(width: 8),
                  Text('NUEVA SUCURSAL',
                      style: GoogleFonts.manrope(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.5,
                          fontSize: 13)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Tarjeta glass tipo admin ──────────────────────────────────────────────────
class _GlassCard extends StatelessWidget {
  final IconData icon;
  final String title, subtitle;
  final VoidCallback onTap;

  const _GlassCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          height: 160,
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.45),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.15),
              width: 1.5,
            ),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              highlightColor: AppColors.button.withValues(alpha: 0.1),
              splashColor: AppColors.button.withValues(alpha: 0.2),
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.button.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                        border: Border.all(
                            color:
                                AppColors.button.withValues(alpha: 0.5),
                            width: 1),
                      ),
                      child: Icon(icon,
                          color: AppColors.button, size: 28),
                    ),
                    const Spacer(),
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.6),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

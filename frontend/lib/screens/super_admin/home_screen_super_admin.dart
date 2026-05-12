import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:frontend/components/bravo_app_bar.dart';
import 'package:frontend/core/colors_style.dart';
import 'package:frontend/providers/usuario_provider.dart';
import 'package:frontend/providers/restaurante_provider.dart';
import 'package:frontend/models/restaurante_model.dart';
import 'package:frontend/services/super_admin_service.dart';
import 'gestion_usuarios_screen.dart';
import 'gestion_rol_screen.dart';
import 'sucursal_detail_screen.dart';
import 'pedidos_activos_screen.dart';
import 'contabilidad_screen.dart';
import 'actividad_screen.dart';
import 'kpis_globales_screen.dart';
import 'catalogo_masivo_screen.dart';
import 'cupones_screen.dart';
import 'super_cierres_caja_screen.dart';
import 'super_reservas_screen.dart';
import 'super_local_editar_screen.dart';

class HomeScreenSuperAdmin extends StatefulWidget {
  const HomeScreenSuperAdmin({super.key});

  @override
  State<HomeScreenSuperAdmin> createState() => _HomeScreenSuperAdminState();
}

class _HomeScreenSuperAdminState extends State<HomeScreenSuperAdmin> {
  // ── Estado KPIs globales ──────────────────────────────────────────────────
  bool _cargandoKpis = false;
  Map<String, dynamic>? _kpiTotales;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<RestauranteProvider>().cargar();
      context.read<UsuarioProvider>().cargar();
      _cargarKpis();
    });
  }

  Future<void> _cargarKpis() async {
    if (!mounted) return;
    setState(() => _cargandoKpis = true);
    try {
      final data = await SuperAdminService.kpisHoy();
      if (!mounted) return;
      setState(() {
        _kpiTotales = data['totales'] as Map<String, dynamic>?;
        _cargandoKpis = false;
      });
    } catch (e) {
      debugPrint('KPIs super_admin: $e');
      if (mounted) setState(() => _cargandoKpis = false);
    }
  }

  void _ir(BuildContext context, Widget screen) =>
      Navigator.push(context, MaterialPageRoute(builder: (_) => screen));

  // ── Diálogo crear/editar sucursal ───────────────────────────────
  Future<void> _mostrarFormulario({Restaurante? restaurante}) async {
    final nombreCtrl = TextEditingController(text: restaurante?.nombre ?? '');
    final dirCtrl = TextEditingController(text: restaurante?.direccion ?? '');
    final formKey = GlobalKey<FormState>();
    final esEdicion = restaurante != null;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.background,
        shape: const RoundedRectangleBorder(),
        title: Text(
          esEdicion ? 'Editar sucursal' : 'Nueva sucursal',
          style: GoogleFonts.manrope(fontWeight: FontWeight.w700),
        ),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _campo(
                ctrl: nombreCtrl,
                label: 'Nombre',
                icon: Icons.storefront_outlined,
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Obligatorio' : null,
              ),
              const SizedBox(height: 12),
              _campo(
                ctrl: dirCtrl,
                label: 'Dirección',
                icon: Icons.location_on_outlined,
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Obligatorio' : null,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Cancelar',
              style: GoogleFonts.manrope(color: AppColors.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(ctx, true);
              }
            },
            child: Text(
              esEdicion ? 'GUARDAR' : 'CREAR',
              style: GoogleFonts.manrope(
                fontWeight: FontWeight.w700,
                color: AppColors.button,
              ),
            ),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    final provider = context.read<RestauranteProvider>();
    final nombre = nombreCtrl.text.trim();
    final direccion = dirCtrl.text.trim();

    bool exito;
    if (esEdicion) {
      exito = await provider.editar(
        id: restaurante.id,
        nombre: nombre,
        direccion: direccion,
      );
    } else {
      exito = await provider.crear(nombre: nombre, direccion: direccion);
    }
    if (mounted) {
      _snack(
        exito
            ? (esEdicion ? 'Sucursal actualizada' : 'Sucursal creada')
            : 'Error al guardar',
      );
    }
  }

  // ── Suspender sucursal ──────────────────────────────────────────
  Future<void> _suspenderSucursal(Restaurante r) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.background,
        shape: const RoundedRectangleBorder(),
        title: Text(
          'Suspender sucursal',
          style: GoogleFonts.manrope(fontWeight: FontWeight.w700),
        ),
        content: Text(
          '¿Suspender "${r.nombre}"? No se aceptarán nuevos pedidos.',
          style: GoogleFonts.manrope(
            color: AppColors.textSecondary,
            fontSize: 13,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancelar',
              style: GoogleFonts.manrope(color: AppColors.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              'SUSPENDER',
              style: GoogleFonts.manrope(
                fontWeight: FontWeight.w700,
                color: AppColors.warningLight,
              ),
            ),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    try {
      await SuperAdminService.suspenderRestaurante(r.id);
      if (mounted) {
        _snack('Sucursal suspendida');
        context.read<RestauranteProvider>().cargar();
      }
    } catch (e) {
      if (mounted) _snack('Error al suspender: $e');
    }
  }

  // ── Reactivar sucursal ──────────────────────────────────────────
  Future<void> _reactivarSucursal(Restaurante r) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.background,
        shape: const RoundedRectangleBorder(),
        title: Text(
          'Reactivar sucursal',
          style: GoogleFonts.manrope(fontWeight: FontWeight.w700),
        ),
        content: Text(
          '¿Reactivar "${r.nombre}"? Volverá a aceptar pedidos.',
          style: GoogleFonts.manrope(
            color: AppColors.textSecondary,
            fontSize: 13,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancelar',
              style: GoogleFonts.manrope(color: AppColors.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              'REACTIVAR',
              style: GoogleFonts.manrope(
                fontWeight: FontWeight.w700,
                color: AppColors.disp,
              ),
            ),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    try {
      await SuperAdminService.reactivarRestaurante(r.id);
      if (mounted) {
        _snack('Sucursal reactivada');
        context.read<RestauranteProvider>().cargar();
      }
    } catch (e) {
      if (mounted) _snack('Error al reactivar: $e');
    }
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: GoogleFonts.manrope()),
        backgroundColor: AppColors.button,
        behavior: SnackBarBehavior.floating,
      ),
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
      style: GoogleFonts.manrope(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: GoogleFonts.manrope(
          fontSize: 13,
          color: Colors.white70,
        ),
        hintStyle: GoogleFonts.manrope(color: Colors.white60),
        prefixIcon: icon != null
            ? Icon(icon, color: AppColors.button, size: 20)
            : null,
        filled: true,
        fillColor: const Color(0x8C000000),
        border: const OutlineInputBorder(borderRadius: BorderRadius.zero),
        enabledBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.zero,
          borderSide: BorderSide(color: AppColors.line),
        ),
        focusedBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.zero,
          borderSide: BorderSide(color: AppColors.button, width: 1.5),
        ),
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
            child: RefreshIndicator(
              color: AppColors.button,
              backgroundColor: Colors.black87,
              onRefresh: () async {
                await Future.wait([
                  _cargarKpis(),
                  context.read<RestauranteProvider>().cargar(),
                  context.read<UsuarioProvider>().cargar(),
                ]);
              },
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24.0,
                    vertical: 16.0,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Cabecera ─────────────────────────────────
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Hola, Super Admin!",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 28,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                SizedBox(height: 8),
                                Text(
                                  "Panel de administración global del Grupo Bravo.",
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Semantics(
                            label: 'Recargar datos del panel',
                            button: true,
                            child: IconButton(
                              icon: _cargandoKpis
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: AppColors.button,
                                      ),
                                    )
                                  : const Icon(
                                      Icons.refresh,
                                      color: Colors.white70,
                                    ),
                              tooltip: 'Actualizar KPIs',
                              onPressed: _cargandoKpis ? null : _cargarKpis,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 24),

                      // ── CARRUSEL KPIs GLOBALES ────────────────────
                      _SeccionKpisGlobales(
                        totales: _kpiTotales,
                        cargando: _cargandoKpis,
                        onCierresTap: () =>
                            _ir(context, const SuperCierresCajaScreen()),
                        onReservasTap: () =>
                            _ir(context, const SuperReservasScreen()),
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
                                  color: AppColors.button,
                                ),
                              ),
                            );
                          }
                          if (rProv.error != null) {
                            return Padding(
                              padding: const EdgeInsets.all(16),
                              child: Text(
                                'Error al cargar sucursales: ${rProv.error}',
                                style:
                                    const TextStyle(color: Colors.white70),
                              ),
                            );
                          }
                          final lista = rProv.restaurantes;
                          return Column(
                            children: [
                              for (var i = 0; i < lista.length; i++) ...[
                                _SucursalGlassCard(
                                  restaurante: lista[i],
                                  numero: i + 1,
                                  personalCount:
                                      uProv.usuarios.where((u) {
                                    final id = (u.restauranteId ?? '')
                                        .toString()
                                        .trim()
                                        .toLowerCase();
                                    return id ==
                                            lista[i]
                                                .id
                                                .trim()
                                                .toLowerCase() &&
                                        u.rolRaw != 'cliente' &&
                                        u.rolRaw != 'superadministrador';
                                  }).length,
                                  onTap: () => _ir(
                                    context,
                                    SucursalDetailScreen(
                                      restauranteId: lista[i].id,
                                      restauranteNombre: lista[i].nombre,
                                    ),
                                  ),
                                  onEditarDetalles: () => _ir(
                                    context,
                                    SuperLocalEditarScreen(
                                      restaurante: lista[i],
                                    ),
                                  ),
                                  onSuspender: () =>
                                      _suspenderSucursal(lista[i]),
                                  onReactivar: () =>
                                      _reactivarSucursal(lista[i]),
                                ),
                                const SizedBox(height: 12),
                              ],
                              _NuevaSucursalGlass(
                                onTap: () => _mostrarFormulario(),
                              ),
                            ],
                          );
                        },
                      ),

                      const SizedBox(height: 28),

                      // ── HERRAMIENTAS GLOBALES ────────────────────────
                      _sectionLabel('HERRAMIENTAS GLOBALES'),
                      const SizedBox(height: 12),
                      Row(
                        children: [
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
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
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
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
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
                        ],
                      ),
                      const SizedBox(height: 16),
                      // ── Atajos a nuevas pantallas ───────────────────
                      Row(
                        children: [
                          Expanded(
                            child: _GlassCard(
                              title: 'Cierres de caja',
                              subtitle: 'Auditoría global',
                              icon: Icons.point_of_sale_outlined,
                              onTap: () => _ir(
                                context,
                                const SuperCierresCajaScreen(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _GlassCard(
                              title: 'Reservas',
                              subtitle: 'Multi-sucursal',
                              icon: Icons.event_available_outlined,
                              onTap: () =>
                                  _ir(context, const SuperReservasScreen()),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 28),

                      // ── USUARIOS GLOBALES ────────────────────────────
                      _sectionLabel('USUARIOS GLOBALES'),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _GlassCard(
                              title: 'Trabajadores',
                              subtitle: 'Empleados del grupo',
                              icon: Icons.people_outline_rounded,
                              onTap: () => _ir(
                                context,
                                const GestionUsuariosScreen(
                                  rolAFiltrar: 'trabajador',
                                ),
                              ),
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
                                  rolAFiltrar: 'administrador',
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: _GlassCard(
                              title: 'Clientes',
                              subtitle: 'Base de clientes',
                              icon: Icons.assignment_ind_outlined,
                              onTap: () => _ir(
                                context,
                                const GestionUsuariosScreen(
                                  rolAFiltrar: 'cliente',
                                ),
                              ),
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
                        ],
                      ),
                      const SizedBox(height: 30),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _sectionLabel(String label) {
    return Row(
      children: [
        Container(width: 3, height: 18, color: AppColors.button),
        const SizedBox(width: 10),
        Text(
          label,
          style: GoogleFonts.manrope(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: Colors.white70,
            letterSpacing: 2,
          ),
        ),
      ],
    );
  }
}

// ── Sección KPIs Globales con carrusel ────────────────────────────────────────
// Copiado de admin_home_screen para mantener independencia entre roles.

class _SeccionKpisGlobales extends StatefulWidget {
  final Map<String, dynamic>? totales;
  final bool cargando;
  final VoidCallback onCierresTap;
  final VoidCallback onReservasTap;

  const _SeccionKpisGlobales({
    required this.totales,
    required this.cargando,
    required this.onCierresTap,
    required this.onReservasTap,
  });

  @override
  State<_SeccionKpisGlobales> createState() => _SeccionKpisGlobalesState();
}

class _SeccionKpisGlobalesState extends State<_SeccionKpisGlobales> {
  static const Duration _kAutoRotate = Duration(seconds: 4);
  static const Duration _kAnim = Duration(milliseconds: 600);

  final PageController _pageCtrl = PageController();
  Timer? _timer;
  int _paginaActual = 0;
  bool _userInteracted = false;
  // Indica si la auto-rotación está pausada por long press.
  bool _pausado = false;
  // Total de páginas; se actualiza en _carrusel().
  int _totalPaginas = 1;

  @override
  void initState() {
    super.initState();
    _iniciarTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageCtrl.dispose();
    super.dispose();
  }

  void _iniciarTimer() {
    _timer?.cancel();
    _pausado = false;
    _timer = Timer.periodic(_kAutoRotate, (_) {
      if (!mounted || !_pageCtrl.hasClients) return;
      if (_totalPaginas <= 1) return;
      final sig = (_paginaActual + 1) % _totalPaginas;
      _pageCtrl.animateToPage(
        sig,
        duration: _kAnim,
        curve: Curves.easeInOut,
      );
    });
  }

  /// Tap sobre una tarjeta: avanza a la siguiente página y reinicia el timer.
  void _avanzarSiguiente() {
    if (!_pageCtrl.hasClients || _totalPaginas <= 1) return;
    final siguiente = (_paginaActual + 1) % _totalPaginas;
    _pageCtrl.animateToPage(
      siguiente,
      duration: _kAnim,
      curve: Curves.easeInOut,
    );
    _iniciarTimer();
  }

  /// Long press iniciado: pausa la auto-rotación.
  void _pausarRotacion() {
    _timer?.cancel();
    _pausado = true;
  }

  /// Long press liberado o cancelado: retoma la auto-rotación.
  void _retomarRotacion() {
    if (_pausado) _iniciarTimer();
  }

  String _euros(num? v) =>
      v != null ? '${v.toDouble().toStringAsFixed(2)} €' : '—';
  String _num(num? v) => v?.toString() ?? '—';

  @override
  Widget build(BuildContext context) {
    final t = widget.totales;

    final header = Row(
      children: [
        Container(width: 3, height: 18, color: AppColors.button),
        const SizedBox(width: 10),
        const Text(
          'PULSO GLOBAL HOY',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: Colors.white70,
            letterSpacing: 2,
          ),
        ),
        if (widget.cargando) ...[
          const SizedBox(width: 10),
          const SizedBox(
            width: 12,
            height: 12,
            child: CircularProgressIndicator(
              strokeWidth: 1.5,
              color: AppColors.button,
            ),
          ),
        ],
      ],
    );

    final sucAbiertas = t?['sucursales_abiertas'] as num?;
    final sucTotal = t?['sucursales_total'] as num? ?? 1;
    final ratioSuc =
        (sucAbiertas != null && sucTotal > 0) ? sucAbiertas / sucTotal : 0.0;
    final colorSuc = ratioSuc >= 0.75
        ? AppColors.disp
        : (ratioSuc >= 0.5 ? AppColors.warning : AppColors.error);

    final stockBajo = t?['stock_bajo_total'] as num? ?? 0;
    final cierresPend = t?['cierres_pendientes'] as num? ?? 0;
    final enCocina = t?['pedidos_en_cocina'] as num? ?? 0;
    final reservas = t?['reservas_hoy'] as num? ?? 0;
    final ingresos = t?['ingresos_hoy'] as num?;

    // Las tarjetas que antes navegaban por onTap (RESERVAS HOY, CIERRES
    // PENDIENTES) ya no lo hacen directamente: el tap avanza el carrusel.
    // El acceso se mantiene mediante el icono discreto open_in_new.
    final tarjetas = <Widget>[
      // 1. Ingresos hoy
      _SuperKpiCard(
        icon: Icons.euro_outlined,
        label: 'INGRESOS HOY',
        value: _euros(ingresos),
        sub: 'facturado hoy',
        accentColor: (ingresos ?? 0) > 0
            ? AppColors.success
            : AppColors.button,
        onTapAdvance: _avanzarSiguiente,
        onLongPressPause: _pausarRotacion,
        onLongPressResume: _retomarRotacion,
      ),
      // 2. Pedidos hoy
      _SuperKpiCard(
        icon: Icons.receipt_long_outlined,
        label: 'PEDIDOS HOY',
        value: _num(t?['pedidos_hoy']),
        sub: 'comandas del día',
        onTapAdvance: _avanzarSiguiente,
        onLongPressPause: _pausarRotacion,
        onLongPressResume: _retomarRotacion,
      ),
      // 3. Ticket medio
      _SuperKpiCard(
        icon: Icons.analytics_outlined,
        label: 'TICKET MEDIO',
        value: _euros(t?['ticket_medio']),
        sub: 'por pedido',
        onTapAdvance: _avanzarSiguiente,
        onLongPressPause: _pausarRotacion,
        onLongPressResume: _retomarRotacion,
      ),
      // 4. En cocina ahora
      _SuperKpiCard(
        icon: Icons.soup_kitchen_outlined,
        label: 'EN COCINA AHORA',
        value: _num(t?['pedidos_en_cocina']),
        sub: 'preparando/pendiente',
        accentColor: enCocina > 0 ? AppColors.warningText : null,
        onTapAdvance: _avanzarSiguiente,
        onLongPressPause: _pausarRotacion,
        onLongPressResume: _retomarRotacion,
      ),
      // 5. Reservas hoy — navegación vía icono discreto
      _SuperKpiCard(
        icon: Icons.event_available_outlined,
        label: 'RESERVAS HOY',
        value: _num(t?['reservas_hoy']),
        sub: 'para hoy',
        accentColor: reservas > 0 ? AppColors.info : Colors.white38,
        shortcutTap: widget.onReservasTap,
        onTapAdvance: _avanzarSiguiente,
        onLongPressPause: _pausarRotacion,
        onLongPressResume: _retomarRotacion,
      ),
      // 6. Stock bajo total
      _SuperKpiCard(
        icon: Icons.inventory_2_outlined,
        label: 'STOCK BAJO TOTAL',
        value: _num(t?['stock_bajo_total']),
        sub: stockBajo > 0 ? 'ingredientes críticos' : 'todo en orden',
        accentColor: stockBajo > 0 ? AppColors.error : Colors.white38,
        onTapAdvance: _avanzarSiguiente,
        onLongPressPause: _pausarRotacion,
        onLongPressResume: _retomarRotacion,
      ),
      // 7. Cierres pendientes — navegación vía icono discreto
      _SuperKpiCard(
        icon: Icons.point_of_sale_outlined,
        label: 'CIERRES PENDIENTES',
        value: _num(t?['cierres_pendientes']),
        sub: 'sin cerrar',
        accentColor: cierresPend > 0 ? AppColors.warningText : Colors.white38,
        shortcutTap: widget.onCierresTap,
        onTapAdvance: _avanzarSiguiente,
        onLongPressPause: _pausarRotacion,
        onLongPressResume: _retomarRotacion,
      ),
      // 8. Sucursales abiertas
      _SuperKpiCard(
        icon: Icons.storefront_outlined,
        label: 'SUCURSALES ABIERTAS',
        value: '${sucAbiertas ?? '—'} / ${t?['sucursales_total'] ?? '—'}',
        sub: 'en este momento',
        accentColor: colorSuc,
        onTapAdvance: _avanzarSiguiente,
        onLongPressPause: _pausarRotacion,
        onLongPressResume: _retomarRotacion,
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        header,
        const SizedBox(height: 14),
        LayoutBuilder(
          builder: (ctx, constraints) {
            final perPage = constraints.maxWidth < 600
                ? 1
                : (constraints.maxWidth < 900 ? 2 : 3);
            return _carrusel(tarjetas, perPage);
          },
        ),
      ],
    );
  }

  Widget _carrusel(List<Widget> tarjetas, int perPage) {
    final paginas = <List<Widget>>[];
    for (int i = 0; i < tarjetas.length; i += perPage) {
      paginas.add(
        tarjetas.sublist(i, (i + perPage).clamp(0, tarjetas.length)),
      );
    }

    // Actualizamos el total para que _avanzarSiguiente() sepa cuántas hay.
    _totalPaginas = paginas.length;

    return Column(
      children: [
        SizedBox(
          height: 130,
          child: PageView.builder(
            controller: _pageCtrl,
            itemCount: paginas.length,
            onPageChanged: (i) {
              setState(() => _paginaActual = i);
              // Swipe manual: reiniciamos el timer para no saltar de inmediato.
              if (_userInteracted) {
                _userInteracted = false;
                _iniciarTimer();
              }
            },
            itemBuilder: (_, idx) {
              final grupo = paginas[idx];
              return Row(
                children: [
                  for (int j = 0; j < grupo.length; j++) ...[
                    if (j > 0) const SizedBox(width: 12),
                    Expanded(child: grupo[j]),
                  ],
                  for (int k = grupo.length; k < perPage; k++) ...[
                    const SizedBox(width: 12),
                    const Expanded(child: SizedBox.shrink()),
                  ],
                ],
              );
            },
          ),
        ),
        const SizedBox(height: 10),
        _dots(paginas.length),
      ],
    );
  }

  /// Indicadores de página. El tap en un dot navega directamente sin pasar
  /// por la lógica de pausa (comportamiento independiente al long press).
  Widget _dots(int total) {
    if (total <= 1) return const SizedBox.shrink();
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (int i = 0; i < total; i++)
          Semantics(
            label: 'Ir a diapositiva ${i + 1} de $total',
            button: true,
            child: GestureDetector(
              onTap: () {
                _userInteracted = true;
                _pageCtrl.animateToPage(
                  i,
                  duration: _kAnim,
                  curve: Curves.easeInOut,
                );
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: i == _paginaActual ? 18 : 8,
                height: 8,
                decoration: BoxDecoration(
                  color: i == _paginaActual
                      ? AppColors.button
                      : Colors.white.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// ── Tarjeta KPI glass para super_admin ────────────────────────────────────────
// Copiado de admin_home_screen para mantener independencia entre roles.

/// - [onTapAdvance]: avanza el carrusel a la siguiente página (tap simple).
/// - [onLongPressPause] / [onLongPressResume]: pausa y retoma el auto-rotate.
/// - [shortcutTap]: callback opcional para el icono discreto open_in_new que
///   permite acceder a la pantalla relacionada sin interferir con el carrusel.
class _SuperKpiCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String sub;
  final Color? accentColor;
  final VoidCallback onTapAdvance;
  final VoidCallback onLongPressPause;
  final VoidCallback onLongPressResume;
  final VoidCallback? shortcutTap;

  const _SuperKpiCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.sub,
    required this.onTapAdvance,
    required this.onLongPressPause,
    required this.onLongPressResume,
    this.accentColor,
    this.shortcutTap,
  });

  @override
  Widget build(BuildContext context) {
    final iconColor = accentColor ?? AppColors.button;

    return Semantics(
      label: '$label: $value',
      child: GestureDetector(
        onTap: onTapAdvance,
        onLongPressStart: (_) => onLongPressPause(),
        onLongPressEnd: (_) => onLongPressResume(),
        onLongPressCancel: onLongPressResume,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white12, width: 1),
              ),
              child: Stack(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(icon, size: 13, color: iconColor),
                          const SizedBox(width: 5),
                          Flexible(
                            child: Text(
                              label,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: Colors.white60,
                                letterSpacing: 1.4,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        value,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          height: 1.1,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        sub,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.white54,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                  // Icono discreto para acceso directo a pantalla relacionada.
                  if (shortcutTap != null)
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Semantics(
                        label: 'Abrir pantalla de $label',
                        button: true,
                        child: GestureDetector(
                          onTap: shortcutTap,
                          behavior: HitTestBehavior.opaque,
                          child: Padding(
                            padding: const EdgeInsets.all(4),
                            child: Icon(
                              Icons.open_in_new,
                              size: 11,
                              color: Colors.white.withValues(alpha: 0.35),
                            ),
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
}

// ── Tarjeta glass para sucursal ───────────────────────────────────────────────
class _SucursalGlassCard extends StatelessWidget {
  final Restaurante restaurante;
  final int numero, personalCount;
  final VoidCallback onTap, onEditarDetalles;
  final VoidCallback onSuspender, onReactivar;

  const _SucursalGlassCard({
    required this.restaurante,
    required this.numero,
    required this.personalCount,
    required this.onTap,
    required this.onEditarDetalles,
    required this.onSuspender,
    required this.onReactivar,
  });

  /// Devuelve "HH:MM–HH:MM" del día actual si está configurado y abierto, o null.
  static String? _horarioHoy(Restaurante r) {
    final hd = r.horariosDia;
    if (hd == null) return null;
    const claves = [
      'lunes', 'martes', 'miercoles', 'jueves', 'viernes', 'sabado', 'domingo',
    ];
    final h = hd[claves[DateTime.now().weekday - 1]];
    if (h == null || !h.abierto) return null;
    return '${h.apertura}–${h.cierre}';
  }

  @override
  Widget build(BuildContext context) {
    final r = restaurante;
    final suspendida = r.estaSuspendida;

    return Opacity(
      opacity: suspendida ? 0.65 : 1.0,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: suspendida ? 0.6 : 0.45),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: suspendida
                    ? AppColors.warningLight.withValues(alpha: 0.4)
                    : Colors.white.withValues(alpha: 0.15),
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
                      // Número / avatar
                      Container(
                        width: 44,
                        height: 44,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: (r.activo && !suspendida
                                  ? AppColors.button
                                  : Colors.white24)
                              .withValues(
                                  alpha: r.activo && !suspendida ? 0.85 : 1),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.25),
                            width: 1,
                          ),
                        ),
                        child: Text(
                          numero.toString().padLeft(2, '0'),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              // mainAxisSize.min + Flexible: la Row solo
                              // ocupa lo justo para el nombre + badge,
                              // así el badge queda pegado al nombre y
                              // no se va al extremo derecho.
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Flexible(
                                  child: Text(
                                    r.nombre,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                // Badge: SUSPENDIDA > ABIERTO/CERRADO
                                suspendida
                                    ? _badgeSuspendida()
                                    : _badgeEstado(r.estaAbierto()),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Icon(
                                  Icons.location_on_outlined,
                                  size: 13,
                                  color: Colors.white.withValues(alpha: 0.6),
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    r.direccion,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color:
                                          Colors.white.withValues(alpha: 0.65),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                if (_horarioHoy(r) != null) ...[
                                  Icon(
                                    Icons.schedule_outlined,
                                    size: 13,
                                    color: Colors.white.withValues(alpha: 0.6),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Hoy: ${_horarioHoy(r)}',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color:
                                          Colors.white.withValues(alpha: 0.6),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                ],
                                Icon(
                                  Icons.badge_outlined,
                                  size: 13,
                                  color: Colors.white.withValues(alpha: 0.6),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '$personalCount empleados',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.white.withValues(alpha: 0.6),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'GESTIONAR →',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color:
                                    AppColors.button.withValues(alpha: 0.95),
                                letterSpacing: 1.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Columna derecha: los dos pills (DETALLES y
                      // SUSPENDER/REACTIVAR) apilados verticalmente.
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _AccionPill(
                            label: 'DETALLES',
                            icono: Icons.tune_rounded,
                            color: AppColors.button,
                            onTap: onEditarDetalles,
                            semantics: 'Editar detalles de la sucursal',
                          ),
                          const SizedBox(height: 6),
                          suspendida
                              ? _AccionPill(
                                  label: 'REACTIVAR',
                                  icono: Icons.play_arrow_rounded,
                                  color: AppColors.disp,
                                  onTap: onReactivar,
                                  semantics: 'Reactivar sucursal',
                                )
                              : _AccionPill(
                                  label: 'SUSPENDER',
                                  icono: Icons.pause_rounded,
                                  color: AppColors.warningLight,
                                  onTap: onSuspender,
                                  semantics: 'Suspender sucursal',
                                ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _badgeEstado(bool abierto) {
    final color = abierto ? AppColors.successLight : AppColors.error;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        abierto ? 'ABIERTO' : 'CERRADO',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: color,
          letterSpacing: 1,
        ),
      ),
    );
  }

  Widget _badgeSuspendida() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.warningBg,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.5)),
      ),
      child: const Text(
        'SUSPENDIDA',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: AppColors.warningText,
          letterSpacing: 1,
        ),
      ),
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
                  Text(
                    'NUEVA SUCURSAL',
                    style: GoogleFonts.manrope(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.5,
                      fontSize: 13,
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
}

// ── Tarjeta glass tipo herramienta ────────────────────────────────────────────
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
                          color: AppColors.button.withValues(alpha: 0.5),
                          width: 1,
                        ),
                      ),
                      child: Icon(icon, color: AppColors.button, size: 28),
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

// ── Pill de acción reutilizable para las cards de sucursal ───────────────────
//
// Usada por GESTIONAR, DETALLES, SUSPENDER y REACTIVAR. Antes cada acción era
// un GestureDetector + Container suelto con fontSize 8 (ilegible). Unificarlas
// en un widget con feedback táctil (InkWell + Material) y un tamaño legible
// arregla la accesibilidad sin desbordar el ancho de la card.
class _AccionPill extends StatelessWidget {
  /// Etiqueta usada como tooltip y para accesibilidad. El texto NO se pinta.
  final String label;
  final IconData icono;
  final Color color;
  final VoidCallback onTap;
  final String? semantics;

  const _AccionPill({
    required this.label,
    required this.icono,
    required this.color,
    required this.onTap,
    this.semantics,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semantics ?? label,
      button: true,
      child: Tooltip(
        message: label,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(10),
            child: Container(
              // Cuadrado fijo 44x44: tamaño táctil cómodo (Material guideline)
              // y mismo ancho/alto para todos los pills, queden alineados.
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: color.withValues(alpha: 0.55)),
              ),
              child: Icon(icono, size: 20, color: color),
            ),
          ),
        ),
      ),
    );
  }
}

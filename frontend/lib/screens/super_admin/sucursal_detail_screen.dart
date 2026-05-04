import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:frontend/core/colors_style.dart';
import 'package:frontend/providers/usuario_provider.dart';
import 'package:frontend/models/pedido_model.dart';
import 'package:frontend/services/pedido_service.dart';
import 'gestion_usuarios_screen.dart';
import 'gestion_rol_screen.dart';
import 'crear_usuario_screen.dart';
import 'pedidos_activos_screen.dart';
import 'contabilidad_screen.dart';

/// Pantalla de detalle de una sucursal concreta.
/// Muestra KPIs del día, gestión de personal y datos específicos de esa sucursal.
class SucursalDetailScreen extends StatelessWidget {
  final String restauranteId;
  final String restauranteNombre;

  const SucursalDetailScreen({
    super.key,
    required this.restauranteId,
    required this.restauranteNombre,
  });

  void _ir(BuildContext context, Widget screen) =>
      Navigator.push(context, MaterialPageRoute(builder: (_) => screen));

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: Colors.black,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () =>
            _ir(context, CrearUsuarioScreen(restauranteId: restauranteId)),
        backgroundColor: AppColors.button,
        elevation: 4,
        shape: const RoundedRectangleBorder(),
        icon: const Icon(Icons.person_add_outlined, color: Colors.white),
        label: Text(
          'NUEVO EMPLEADO',
          style: GoogleFonts.manrope(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.5),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/images/Bravo restaurante.jpg'),
            fit: BoxFit.cover,
          ),
        ),
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
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // ── Hero ────────────────────────────────────────────────
              SliverAppBar(
                expandedHeight: screenHeight * 0.32,
                pinned: true,
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
                iconTheme: const IconThemeData(color: Colors.white),
                flexibleSpace: FlexibleSpaceBar(
                  collapseMode: CollapseMode.parallax,
                  background: _SucursalHero(nombre: restauranteNombre),
                  centerTitle: true,
                  title: Text(
                    restauranteNombre,
                    style: const TextStyle(
                      fontFamily: 'Playfair Display',
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),

              // ── KPIs del día ─────────────────────────────────────────
              SliverToBoxAdapter(
                child: _KpiSection(restauranteId: restauranteId),
              ),

              // ── Sección: Personal ─────────────────────────────────────
              _seccionHeader('GESTIÓN DEL PERSONAL'),

              SliverPadding(
                padding: const EdgeInsets.fromLTRB(24, 4, 24, 0),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 640),
                        child: Column(children: [
                          _GlassTile(
                            icon: Icons.people_outline_rounded,
                            titulo: 'Trabajadores',
                            subtitulo:
                                'Cocineros, camareros y personal de sala',
                            onTap: () => _ir(
                                context,
                                GestionUsuariosScreen(
                                    rolAFiltrar: 'trabajador',
                                    restauranteId: restauranteId)),
                          ),
                          const SizedBox(height: 12),
                          _GlassTile(
                            icon: Icons.admin_panel_settings_outlined,
                            titulo: 'Administradores',
                            subtitulo: 'Gestores de esta sucursal',
                            onTap: () => _ir(
                                context,
                                GestionUsuariosScreen(
                                    rolAFiltrar: 'administrador',
                                    restauranteId: restauranteId)),
                          ),
                          const SizedBox(height: 12),
                          _GlassTile(
                            icon: Icons.security_outlined,
                            titulo: 'Permisos y Roles',
                            subtitulo:
                                'Configuración de accesos del personal',
                            onTap: () => _ir(
                                context,
                                GestionRolesScreen(
                                    restauranteId: restauranteId)),
                          ),
                        ]),
                      ),
                    ),
                  ]),
                ),
              ),

              // ── Sección: Datos de la sucursal ─────────────────────────
              _seccionHeader('DATOS DE ESTA SUCURSAL'),

              SliverPadding(
                padding: const EdgeInsets.fromLTRB(24, 4, 24, 120),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 640),
                        child: Column(children: [
                          _GlassTile(
                            icon: Icons.receipt_long_outlined,
                            titulo: 'Pedidos',
                            subtitulo:
                                'Activos, historial y estados de comandas',
                            onTap: () => _ir(
                                context,
                                PedidosActivosScreen(
                                    restauranteId: restauranteId,
                                    restauranteNombre: restauranteNombre)),
                          ),
                          const SizedBox(height: 12),
                          _GlassTile(
                            icon: Icons.euro_outlined,
                            titulo: 'Contabilidad',
                            subtitulo:
                                'Ingresos, métodos de pago y productos',
                            onTap: () => _ir(
                                context,
                                ContabilidadScreen(
                                    restauranteId: restauranteId,
                                    restauranteNombre: restauranteNombre)),
                          ),
                        ]),
                      ),
                    ),
                  ]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  SliverToBoxAdapter _seccionHeader(String label) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 8),
        child: Row(children: [
          Container(width: 3, height: 18, color: AppColors.button),
          const SizedBox(width: 10),
          Text(label,
              style: GoogleFonts.manrope(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: Colors.white70,
                  letterSpacing: 2)),
        ]),
      ),
    );
  }
}

// ── KPI section ────────────────────────────────────────────────────────────────
class _KpiSection extends StatefulWidget {
  final String restauranteId;
  const _KpiSection({required this.restauranteId});

  @override
  State<_KpiSection> createState() => _KpiSectionState();
}

class _KpiSectionState extends State<_KpiSection> {
  late Future<List<Pedido>> _futuro;

  @override
  void initState() {
    super.initState();
    _futuro = PedidoService.obtenerTodosLosPedidos(
        restauranteId: widget.restauranteId);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final prov = context.read<UsuarioProvider>();
      if (prov.usuarios.isEmpty && !prov.cargando) prov.cargar();
    });
  }

  bool _esHoy(String fecha) {
    final f = DateTime.tryParse(fecha);
    if (f == null) return false;
    final h = DateTime.now();
    return f.year == h.year && f.month == h.month && f.day == h.day;
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<UsuarioProvider>(builder: (_, up, _) {
      final personal = up.usuarios.where((u) {
        final idDB = (u.restauranteId ?? '').toString().trim().toLowerCase();
        return idDB == widget.restauranteId.trim().toLowerCase() &&
            u.rolRaw != 'cliente' &&
            u.rolRaw != 'superadministrador';
      }).length;

      return FutureBuilder<List<Pedido>>(
        future: _futuro,
        builder: (_, snap) {
          final cargando = snap.connectionState == ConnectionState.waiting;
          final hoy = snap.hasData
              ? snap.data!.where((p) => _esHoy(p.fecha)).toList()
              : <Pedido>[];
          final ingresos = hoy.fold(0.0, (s, p) => s + p.total);
          final ticket = hoy.isEmpty ? 0.0 : ingresos / hoy.length;

          return Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 640),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Container(
                            width: 3, height: 18, color: AppColors.button),
                        const SizedBox(width: 10),
                        Text('RESUMEN DE HOY',
                            style: GoogleFonts.manrope(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: Colors.white70,
                                letterSpacing: 2)),
                        if (cargando) ...[
                          const SizedBox(width: 10),
                          const SizedBox(
                              width: 12,
                              height: 12,
                              child: CircularProgressIndicator(
                                  strokeWidth: 1.5,
                                  color: AppColors.button)),
                        ],
                      ]),
                      const SizedBox(height: 14),
                      Row(children: [
                        Expanded(
                            child: _KpiGlassCard(
                                icon: Icons.badge_outlined,
                                label: 'PERSONAL',
                                value: personal.toString(),
                                sub: 'empleados activos')),
                        const SizedBox(width: 12),
                        Expanded(
                            child: _KpiGlassCard(
                                icon: Icons.receipt_long_outlined,
                                label: 'PEDIDOS HOY',
                                value:
                                    cargando ? '-' : hoy.length.toString(),
                                sub: 'en el día')),
                      ]),
                      const SizedBox(height: 12),
                      Row(children: [
                        Expanded(
                            child: _KpiGlassCard(
                                icon: Icons.euro_outlined,
                                label: 'INGRESOS HOY',
                                value: cargando
                                    ? '-'
                                    : ingresos.toStringAsFixed(2),
                                sub: 'euros facturados',
                                highlight: true)),
                        const SizedBox(width: 12),
                        Expanded(
                            child: _KpiGlassCard(
                                icon: Icons.show_chart_rounded,
                                label: 'TICKET MEDIO',
                                value:
                                    cargando ? '-' : ticket.toStringAsFixed(2),
                                sub: 'euros por pedido')),
                      ]),
                    ]),
              ),
            ),
          );
        },
      );
    });
  }
}

// ── Hero visual ────────────────────────────────────────────────────────────────
class _SucursalHero extends StatelessWidget {
  final String nombre;
  const _SucursalHero({required this.nombre});

  @override
  Widget build(BuildContext context) {
    return Stack(children: [
      Positioned.fill(
        child: Image.asset('assets/images/Bravo restaurante.jpg',
            fit: BoxFit.cover),
      ),
      Positioned.fill(
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              stops: const [0.0, 0.35, 0.70, 1.0],
              colors: [
                Colors.black.withValues(alpha: 0.55),
                Colors.black.withValues(alpha: 0.20),
                Colors.black.withValues(alpha: 0.70),
                Colors.black.withValues(alpha: 0.95),
              ],
            ),
          ),
        ),
      ),
      SafeArea(
        child: Center(
          child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                  decoration: BoxDecoration(
                      border: Border.all(color: Colors.white60)),
                  child: Text('SUCURSAL',
                      style: GoogleFonts.manrope(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 4)),
                ),
                const SizedBox(height: 20),
                Text(nombre.toUpperCase(),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontFamily: 'Playfair Display',
                        color: Colors.white,
                        fontSize: 30,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2,
                        shadows: [
                          Shadow(color: Colors.black54, blurRadius: 16)
                        ])),
              ]),
        ),
      ),
    ]);
  }
}

// ── Widgets reutilizables ──────────────────────────────────────────────────────
class _GlassTile extends StatelessWidget {
  final IconData icon;
  final String titulo;
  final String subtitulo;
  final VoidCallback onTap;
  const _GlassTile(
      {required this.icon,
      required this.titulo,
      required this.subtitulo,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
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
                padding: const EdgeInsets.all(20),
                child: Row(children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.button.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: AppColors.button.withValues(alpha: 0.5),
                          width: 1),
                    ),
                    child: Icon(icon, color: AppColors.button, size: 22),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        Text(titulo,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text(subtitulo,
                            style: TextStyle(
                                fontSize: 12,
                                color:
                                    Colors.white.withValues(alpha: 0.65))),
                      ])),
                  Icon(Icons.chevron_right,
                      color: Colors.white.withValues(alpha: 0.3), size: 22),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _KpiGlassCard extends StatelessWidget {
  final IconData icon;
  final String label, value, sub;
  final bool highlight;
  const _KpiGlassCard(
      {required this.icon,
      required this.label,
      required this.value,
      required this.sub,
      this.highlight = false});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: highlight
                ? AppColors.button.withValues(alpha: 0.65)
                : Colors.black.withValues(alpha: 0.45),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: highlight
                  ? AppColors.button.withValues(alpha: 0.85)
                  : Colors.white.withValues(alpha: 0.15),
              width: 1.5,
            ),
          ),
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Icon(icon,
                      size: 15,
                      color: highlight
                          ? Colors.white
                          : AppColors.button.withValues(alpha: 0.95)),
                  const SizedBox(width: 6),
                  Flexible(
                      child: Text(label,
                          style: GoogleFonts.manrope(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              color: Colors.white.withValues(alpha: 0.7),
                              letterSpacing: 1.5))),
                ]),
                const SizedBox(height: 10),
                Text(value,
                    style: GoogleFonts.manrope(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: Colors.white)),
                const SizedBox(height: 2),
                Text(sub,
                    style: GoogleFonts.manrope(
                        fontSize: 11,
                        color: Colors.white.withValues(alpha: 0.65))),
              ]),
        ),
      ),
    );
  }
}

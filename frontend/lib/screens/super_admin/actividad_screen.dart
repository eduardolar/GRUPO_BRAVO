import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/colors_style.dart';
import '../../services/auditoria_service.dart';

class ActividadScreen extends StatefulWidget {
  const ActividadScreen({super.key});

  @override
  State<ActividadScreen> createState() => _ActividadScreenState();
}

class _ActividadScreenState extends State<ActividadScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // ── Pagos ────────────────────────────────────────────────────────
  List<EventoAuditoria> _pagos = [];
  bool _cargandoPagos = true;
  String? _errorPagos;
  String _filtroPagoEstado = 'todos';

  // ── Usuarios ─────────────────────────────────────────────────────
  List<EventoGeneral> _usuarios = [];
  bool _cargandoUsuarios = true;
  String? _errorUsuarios;
  String _filtroAccion = 'todos';

  static const _accionesDisponibles = {
    'todos': 'Todos',
    'usuario.creado': 'Creación',
    'usuario.eliminado': 'Eliminación',
    'usuario.editado': 'Edición',
    'usuario.rol_cambiado': 'Rol',
    'usuario.estado_cambiado': 'Estado',
    'auth.login_ok': 'Login OK',
    'auth.login_fallido': 'Login fallido',
  };

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _cargarPagos();
    _cargarUsuarios();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _cargarPagos() async {
    setState(() { _cargandoPagos = true; _errorPagos = null; });
    try {
      final datos = await AuditoriaService.obtenerEventos(limite: 200);
      if (!mounted) return;
      setState(() { _pagos = datos; _cargandoPagos = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _cargandoPagos = false; _errorPagos = e.toString(); });
    }
  }

  Future<void> _cargarUsuarios() async {
    setState(() { _cargandoUsuarios = true; _errorUsuarios = null; });
    try {
      final datos = await AuditoriaGeneralService.obtenerEventosGenerales(limite: 200);
      if (!mounted) return;
      setState(() { _usuarios = datos; _cargandoUsuarios = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _cargandoUsuarios = false; _errorUsuarios = e.toString(); });
    }
  }

  // ── Helpers pagos ─────────────────────────────────────────────────
  List<EventoAuditoria> get _pagosFiltrados {
    if (_filtroPagoEstado == 'todos') return _pagos;
    return _pagos.where((e) => e.estado.toLowerCase() == _filtroPagoEstado).toList();
  }

  Color _colorEstadoPago(String estado) {
    switch (estado.toLowerCase()) {
      case 'ok': return Colors.greenAccent;
      case 'error': return AppColors.error;
      default: return Colors.orange;
    }
  }

  IconData _iconoProveedor(String proveedor) {
    final p = proveedor.toLowerCase();
    if (p.contains('stripe')) return Icons.credit_card_outlined;
    if (p.contains('apple')) return Icons.phone_iphone_outlined;
    if (p.contains('google')) return Icons.g_mobiledata_rounded;
    if (p.contains('paypal')) return Icons.account_balance_wallet_outlined;
    return Icons.payment_outlined;
  }

  // ── Helpers usuarios ──────────────────────────────────────────────
  List<EventoGeneral> get _usuariosFiltrados {
    if (_filtroAccion == 'todos') return _usuarios;
    return _usuarios.where((e) => e.accion == _filtroAccion).toList();
  }

  Color _colorAccion(String accion) {
    if (accion.contains('eliminado') || accion.contains('fallido')) return AppColors.error;
    if (accion.contains('creado') || accion.contains('login_ok')) return Colors.greenAccent;
    if (accion.contains('rol') || accion.contains('estado')) return Colors.orange;
    return AppColors.button;
  }

  IconData _iconoAccion(String accion) {
    if (accion.contains('creado')) return Icons.person_add_outlined;
    if (accion.contains('eliminado')) return Icons.person_remove_outlined;
    if (accion.contains('editado')) return Icons.edit_outlined;
    if (accion.contains('rol')) return Icons.manage_accounts_outlined;
    if (accion.contains('estado')) return Icons.toggle_on_outlined;
    if (accion.contains('login_ok')) return Icons.login_rounded;
    if (accion.contains('login_fallido')) return Icons.no_accounts_outlined;
    return Icons.circle_outlined;
  }

  String _etiquetaAccion(String accion) {
    return _accionesDisponibles[accion] ?? accion;
  }

  String _formatFecha(String fecha) {
    final dt = DateTime.tryParse(fecha)?.toLocal();
    if (dt == null) return fecha;
    final hoy = DateTime.now();
    final h = dt.hour.toString().padLeft(2, '0');
    final mi = dt.minute.toString().padLeft(2, '0');
    final s = dt.second.toString().padLeft(2, '0');
    if (dt.year == hoy.year && dt.month == hoy.month && dt.day == hoy.day) {
      return 'Hoy $h:$mi:$s';
    }
    return '${dt.day}/${dt.month}/${dt.year} $h:$mi';
  }

  @override
  Widget build(BuildContext context) {
    final erroresPago = _pagos.where((e) => e.estado.toLowerCase() == 'error').length;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset('assets/images/Bravo restaurante.jpg', fit: BoxFit.cover),
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(erroresPago),
                _buildTabBar(),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildTabUsuarios(),
                      _buildTabPagos(),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            top: 20,
            left: 10,
            child: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          Positioned(
            top: 20,
            right: 10,
            child: IconButton(
              icon: const Icon(Icons.refresh_rounded, color: Colors.white70, size: 22),
              onPressed: () { _cargarPagos(); _cargarUsuarios(); },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(int erroresPago) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 60, 80, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Text(
                'Actividad',
                style: TextStyle(
                  fontFamily: 'Playfair Display',
                  color: Colors.white,
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (erroresPago > 0) ...[
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  color: AppColors.error.withValues(alpha: 0.2),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.warning_amber_rounded, size: 12, color: AppColors.error),
                      const SizedBox(width: 4),
                      Text(
                        '$erroresPago error${erroresPago != 1 ? 's' : ''}',
                        style: GoogleFonts.manrope(
                          fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.error),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 6),
          Container(height: 2, width: 40, color: AppColors.button),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.white12),
        color: Colors.white.withValues(alpha: 0.05),
      ),
      child: TabBar(
        controller: _tabController,
        indicatorColor: AppColors.button,
        indicatorWeight: 2,
        labelColor: Colors.white,
        unselectedLabelColor: Colors.white38,
        labelStyle: GoogleFonts.manrope(fontSize: 12, fontWeight: FontWeight.w700),
        unselectedLabelStyle: GoogleFonts.manrope(fontSize: 12, fontWeight: FontWeight.w500),
        tabs: [
          Tab(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.manage_accounts_outlined, size: 15),
                const SizedBox(width: 6),
                const Text('USUARIOS'),
                if (_usuarios.isNotEmpty) ...[
                  const SizedBox(width: 6),
                  _Chip('${_usuarios.length}'),
                ],
              ],
            ),
          ),
          Tab(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.payment_outlined, size: 15),
                const SizedBox(width: 6),
                const Text('PAGOS'),
                if (_pagos.isNotEmpty) ...[
                  const SizedBox(width: 6),
                  _Chip('${_pagos.length}'),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Tab Usuarios ─────────────────────────────────────────────────
  Widget _buildTabUsuarios() {
    return Column(
      children: [
        const SizedBox(height: 10),
        _buildFiltroAcciones(),
        const SizedBox(height: 4),
        Expanded(child: _buildListaUsuarios()),
      ],
    );
  }

  Widget _buildFiltroAcciones() {
    final acciones = _accionesDisponibles.keys.toList();
    return SizedBox(
      height: 32,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        children: acciones.map((a) {
          final sel = _filtroAccion == a;
          return GestureDetector(
            onTap: () => setState(() => _filtroAccion = a),
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: sel ? AppColors.button : Colors.white.withValues(alpha: 0.07),
                border: Border.all(color: sel ? AppColors.button : Colors.white12),
              ),
              child: Text(
                _accionesDisponibles[a]!,
                style: GoogleFonts.manrope(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: sel ? Colors.white : Colors.white54,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildListaUsuarios() {
    if (_cargandoUsuarios) {
      return const Center(child: CircularProgressIndicator(color: AppColors.button));
    }
    if (_errorUsuarios != null) {
      return _buildError(_cargarUsuarios);
    }
    final lista = _usuariosFiltrados;
    if (lista.isEmpty) {
      return _buildVacio(
        _usuarios.isEmpty
            ? 'Aún no hay eventos registrados'
            : 'Sin eventos para este filtro',
      );
    }
    return RefreshIndicator(
      onRefresh: _cargarUsuarios,
      color: AppColors.button,
      backgroundColor: AppColors.background,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
        itemCount: lista.length,
        itemBuilder: (_, i) => Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: _EventoUsuarioTile(
              evento: lista[i],
              color: _colorAccion(lista[i].accion),
              icono: _iconoAccion(lista[i].accion),
              etiqueta: _etiquetaAccion(lista[i].accion),
              fecha: _formatFecha(lista[i].fecha),
            ),
          ),
        ),
      ),
    );
  }

  // ── Tab Pagos ────────────────────────────────────────────────────
  Widget _buildTabPagos() {
    return Column(
      children: [
        const SizedBox(height: 10),
        _buildFiltroPagoEstado(),
        const SizedBox(height: 4),
        Expanded(child: _buildListaPagos()),
      ],
    );
  }

  Widget _buildFiltroPagoEstado() {
    return SizedBox(
      height: 32,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        children: ['todos', 'ok', 'error'].map((f) {
          final sel = _filtroPagoEstado == f;
          return GestureDetector(
            onTap: () => setState(() => _filtroPagoEstado = f),
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: sel ? AppColors.button : Colors.white.withValues(alpha: 0.07),
                border: Border.all(color: sel ? AppColors.button : Colors.white12),
              ),
              child: Text(
                f == 'todos' ? 'Todos' : f == 'ok' ? '✓ OK' : '✕ Error',
                style: GoogleFonts.manrope(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: sel ? Colors.white : Colors.white54,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildListaPagos() {
    if (_cargandoPagos) {
      return const Center(child: CircularProgressIndicator(color: AppColors.button));
    }
    if (_errorPagos != null) {
      return _buildError(_cargarPagos);
    }
    final lista = _pagosFiltrados;
    if (lista.isEmpty) {
      return _buildVacio('Sin eventos de pago registrados');
    }
    return RefreshIndicator(
      onRefresh: _cargarPagos,
      color: AppColors.button,
      backgroundColor: AppColors.background,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
        itemCount: lista.length,
        itemBuilder: (_, i) => Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: _EventoPagoTile(
              evento: lista[i],
              color: _colorEstadoPago(lista[i].estado),
              icono: _iconoProveedor(lista[i].proveedor),
              fecha: _formatFecha(lista[i].fecha),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildError(VoidCallback retry) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.wifi_off_outlined, color: Colors.white24, size: 48),
          const SizedBox(height: 12),
          Text('Error al cargar datos', style: GoogleFonts.manrope(color: Colors.white38)),
          const SizedBox(height: 16),
          TextButton(
            onPressed: retry,
            child: Text('Reintentar', style: GoogleFonts.manrope(color: AppColors.button)),
          ),
        ],
      ),
    );
  }

  Widget _buildVacio(String mensaje) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.history_outlined, size: 64, color: Colors.white24),
          const SizedBox(height: 16),
          Text(mensaje, style: GoogleFonts.manrope(color: Colors.white38, fontSize: 14)),
        ],
      ),
    );
  }
}

// ── CHIP contador ────────────────────────────────────────────────────
class _Chip extends StatelessWidget {
  final String texto;
  const _Chip(this.texto);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(texto,
          style: GoogleFonts.manrope(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white70)),
    );
  }
}

// ── TILE evento de usuario ───────────────────────────────────────────
class _EventoUsuarioTile extends StatelessWidget {
  final EventoGeneral evento;
  final Color color;
  final IconData icono;
  final String etiqueta;
  final String fecha;

  const _EventoUsuarioTile({
    required this.evento,
    required this.color,
    required this.icono,
    required this.etiqueta,
    required this.fecha,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          Container(width: 4, height: 60, color: color.withValues(alpha: 0.8)),
          const SizedBox(width: 12),
          Container(
            width: 34, height: 34,
            color: color.withValues(alpha: 0.12),
            child: Icon(icono, size: 17, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        color: color.withValues(alpha: 0.12),
                        child: Text(etiqueta.toUpperCase(),
                          style: GoogleFonts.manrope(
                            fontSize: 9, fontWeight: FontWeight.w800,
                            color: color, letterSpacing: 0.8)),
                      ),
                      const Spacer(),
                      Text(fecha,
                        style: GoogleFonts.manrope(fontSize: 10, color: Colors.white24)),
                    ],
                  ),
                  if (evento.objetivo != null) ...[
                    const SizedBox(height: 4),
                    Text(evento.objetivo!,
                      style: GoogleFonts.manrope(
                        fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white),
                      overflow: TextOverflow.ellipsis),
                  ],
                  if (evento.detalle != null) ...[
                    const SizedBox(height: 2),
                    Text(evento.detalle!,
                      style: GoogleFonts.manrope(fontSize: 11, color: Colors.white38),
                      overflow: TextOverflow.ellipsis),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
        ],
      ),
    );
  }
}

// ── TILE evento de pago ──────────────────────────────────────────────
class _EventoPagoTile extends StatelessWidget {
  final EventoAuditoria evento;
  final Color color;
  final IconData icono;
  final String fecha;

  const _EventoPagoTile({
    required this.evento,
    required this.color,
    required this.icono,
    required this.fecha,
  });

  @override
  Widget build(BuildContext context) {
    final esError = evento.estado.toLowerCase() == 'error';
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        border: Border.all(
          color: esError
              ? AppColors.error.withValues(alpha: 0.3)
              : Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          Container(width: 4, height: 60, color: color.withValues(alpha: 0.8)),
          const SizedBox(width: 12),
          Container(
            width: 34, height: 34,
            color: Colors.white.withValues(alpha: 0.07),
            child: Icon(icono, size: 17, color: Colors.white54),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(evento.evento,
                          style: GoogleFonts.manrope(
                            fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white),
                          overflow: TextOverflow.ellipsis),
                      ),
                      if (evento.importe != null)
                        Text(
                          '${evento.importe!.toStringAsFixed(2)} ${evento.moneda ?? '€'}',
                          style: GoogleFonts.manrope(
                            fontSize: 13, fontWeight: FontWeight.w800,
                            color: esError ? AppColors.error : AppColors.button)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(evento.proveedor,
                        style: GoogleFonts.manrope(fontSize: 11, color: Colors.white38)),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                        color: color.withValues(alpha: 0.12),
                        child: Text(evento.estado.toUpperCase(),
                          style: GoogleFonts.manrope(
                            fontSize: 9, fontWeight: FontWeight.w800,
                            color: color, letterSpacing: 0.8)),
                      ),
                      const Spacer(),
                      Text(fecha,
                        style: GoogleFonts.manrope(fontSize: 10, color: Colors.white24)),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
        ],
      ),
    );
  }
}

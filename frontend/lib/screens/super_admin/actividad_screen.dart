import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/colors_style.dart';
import '../../services/auditoria_service.dart';
import '../../services/server_time_service.dart';

const BorderRadius _kRadius = BorderRadius.all(Radius.circular(12));
const BorderRadius _kRadiusSm = BorderRadius.all(Radius.circular(8));
const double _kMaxTileWidth = 640;
const int _kLimite = 200;

enum _FiltroEstadoPago { todos, ok, error }

extension on _FiltroEstadoPago {
  String get label => switch (this) {
        _FiltroEstadoPago.todos => 'Todos',
        _FiltroEstadoPago.ok => '✓ OK',
        _FiltroEstadoPago.error => '✕ Error',
      };

  bool aplica(String estado) => switch (this) {
        _FiltroEstadoPago.todos => true,
        _FiltroEstadoPago.ok => estado.toLowerCase() == 'ok',
        _FiltroEstadoPago.error => estado.toLowerCase() == 'error',
      };
}

const Map<String, String> _kAccionesDisponibles = {
  'todos': 'Todos',
  'usuario.creado': 'Creación',
  'usuario.eliminado': 'Eliminación',
  'usuario.editado': 'Edición',
  'usuario.rol_cambiado': 'Rol',
  'usuario.estado_cambiado': 'Estado',
  'auth.login_ok': 'Login OK',
  'auth.login_fallido': 'Login fallido',
};

// ── Helpers visuales (fuera de la clase para reusarse en tiles) ─────────

Color _colorEstadoPago(String estado) {
  switch (estado.toLowerCase()) {
    case 'ok':
      return Colors.greenAccent;
    case 'error':
      return AppColors.error;
    default:
      return Colors.orange;
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

Color _colorAccion(String accion) {
  if (accion.contains('eliminado') || accion.contains('fallido')) {
    return AppColors.error;
  }
  if (accion.contains('creado') || accion.contains('login_ok')) {
    return Colors.greenAccent;
  }
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

String _etiquetaAccion(String accion) =>
    _kAccionesDisponibles[accion] ?? accion;

/// Formatea una fecha ISO usando la hora del servidor para decidir "Hoy".
String _formatFecha(String fecha) {
  final dt = DateTime.tryParse(fecha)?.toLocal();
  if (dt == null) return fecha;
  final hoy = ServerTimeService.instance.now.toLocal();
  final h = dt.hour.toString().padLeft(2, '0');
  final mi = dt.minute.toString().padLeft(2, '0');
  final s = dt.second.toString().padLeft(2, '0');
  if (dt.year == hoy.year && dt.month == hoy.month && dt.day == hoy.day) {
    return 'Hoy $h:$mi:$s';
  }
  return '${dt.day}/${dt.month}/${dt.year} $h:$mi';
}

String _formatFechaLarga(String fecha) {
  final dt = DateTime.tryParse(fecha)?.toLocal();
  if (dt == null) return fecha;
  final h = dt.hour.toString().padLeft(2, '0');
  final mi = dt.minute.toString().padLeft(2, '0');
  final s = dt.second.toString().padLeft(2, '0');
  return '${dt.day.toString().padLeft(2, '0')}/'
      '${dt.month.toString().padLeft(2, '0')}/'
      '${dt.year}  ·  $h:$mi:$s';
}

// ── Pantalla ─────────────────────────────────────────────────────────────

class ActividadScreen extends StatefulWidget {
  const ActividadScreen({super.key});

  @override
  State<ActividadScreen> createState() => _ActividadScreenState();
}

class _ActividadScreenState extends State<ActividadScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Pagos
  List<EventoAuditoria> _pagos = [];
  bool _cargandoPagos = true;
  String? _errorPagos;
  _FiltroEstadoPago _filtroPagoEstado = _FiltroEstadoPago.todos;

  // Usuarios
  List<EventoGeneral> _usuarios = [];
  bool _cargandoUsuarios = true;
  String? _errorUsuarios;
  String _filtroAccion = 'todos';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    // Sincronizar hora del servidor para que "Hoy" sea coherente.
    ServerTimeService.instance.sincronizar().then((_) {
      if (mounted) setState(() {});
    });
    _cargarPagos();
    _cargarUsuarios();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _cargarPagos() async {
    setState(() {
      _cargandoPagos = true;
      _errorPagos = null;
    });
    try {
      final datos = await AuditoriaService.obtenerEventos(limite: _kLimite);
      if (!mounted) return;
      setState(() {
        _pagos = datos;
        _cargandoPagos = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _cargandoPagos = false;
        _errorPagos = e.toString();
      });
    }
  }

  Future<void> _cargarUsuarios() async {
    setState(() {
      _cargandoUsuarios = true;
      _errorUsuarios = null;
    });
    try {
      final datos = await AuditoriaGeneralService.obtenerEventosGenerales(
        limite: _kLimite,
      );
      if (!mounted) return;
      setState(() {
        _usuarios = datos;
        _cargandoUsuarios = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _cargandoUsuarios = false;
        _errorUsuarios = e.toString();
      });
    }
  }

  void _refrescarTodo() {
    _cargarPagos();
    _cargarUsuarios();
  }

  List<EventoAuditoria> get _pagosFiltrados =>
      _pagos.where((e) => _filtroPagoEstado.aplica(e.estado)).toList();

  List<EventoGeneral> get _usuariosFiltrados {
    if (_filtroAccion == 'todos') return _usuarios;
    return _usuarios.where((e) => e.accion == _filtroAccion).toList();
  }

  @override
  Widget build(BuildContext context) {
    final erroresPago =
        _pagos.where((e) => e.estado.toLowerCase() == 'error').length;

    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new,
            color: Colors.white,
            size: 20,
          ),
          tooltip: 'Volver',
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(
              Icons.refresh_rounded,
              color: Colors.white70,
              size: 22,
            ),
            tooltip: 'Actualizar',
            onPressed: _refrescarTodo,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Stack(
        children: [
          const _FondoConVelado(),
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Header(erroresPago: erroresPago),
                _BarraTabs(
                  controller: _tabController,
                  conteoUsuarios: _usuarios.length,
                  conteoPagos: _pagos.length,
                ),
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
        ],
      ),
    );
  }

  // ── Tab Usuarios ────────────────────────────────────────────────────────

  Widget _buildTabUsuarios() {
    return Column(
      children: [
        const SizedBox(height: 10),
        _FiltroAcciones(
          seleccionada: _filtroAccion,
          onSeleccion: (a) => setState(() => _filtroAccion = a),
        ),
        const SizedBox(height: 4),
        Expanded(child: _buildListaUsuarios()),
      ],
    );
  }

  Widget _buildListaUsuarios() {
    if (_cargandoUsuarios) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.button),
      );
    }
    if (_errorUsuarios != null) {
      return _EstadoError(onRetry: _cargarUsuarios);
    }
    final lista = _usuariosFiltrados;
    if (lista.isEmpty) {
      return _EstadoVacio(
        mensaje: _usuarios.isEmpty
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
        itemBuilder: (_, i) => _ConstrainedCenter(
          child: RepaintBoundary(
            child: _EventoUsuarioTile(
              evento: lista[i],
              onTap: () => _mostrarDetalleUsuario(lista[i]),
            ),
          ),
        ),
      ),
    );
  }

  // ── Tab Pagos ───────────────────────────────────────────────────────────

  Widget _buildTabPagos() {
    return Column(
      children: [
        const SizedBox(height: 10),
        _FiltroEstadoPagoBar(
          seleccionado: _filtroPagoEstado,
          onSeleccion: (f) => setState(() => _filtroPagoEstado = f),
        ),
        const SizedBox(height: 4),
        Expanded(child: _buildListaPagos()),
      ],
    );
  }

  Widget _buildListaPagos() {
    if (_cargandoPagos) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.button),
      );
    }
    if (_errorPagos != null) {
      return _EstadoError(onRetry: _cargarPagos);
    }
    final lista = _pagosFiltrados;
    if (lista.isEmpty) {
      return const _EstadoVacio(
        mensaje: 'Sin eventos de pago registrados',
      );
    }
    return RefreshIndicator(
      onRefresh: _cargarPagos,
      color: AppColors.button,
      backgroundColor: AppColors.background,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
        itemCount: lista.length,
        itemBuilder: (_, i) => _ConstrainedCenter(
          child: RepaintBoundary(
            child: _EventoPagoTile(
              evento: lista[i],
              onTap: () => _mostrarDetallePago(lista[i]),
            ),
          ),
        ),
      ),
    );
  }

  // ── Detalle (bottom sheet) ──────────────────────────────────────────────

  void _mostrarDetalleUsuario(EventoGeneral e) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _DetalleSheet(
        titulo: _etiquetaAccion(e.accion),
        color: _colorAccion(e.accion),
        icono: _iconoAccion(e.accion),
        fecha: _formatFechaLarga(e.fecha),
        filas: [
          ('Acción', e.accion),
          ('Realizado por', e.actor ?? '— sin identificar —'),
          if (e.objetivo != null) ('Objetivo', e.objetivo!),
          if (e.detalle != null) ('Detalle', e.detalle!),
        ],
      ),
    );
  }

  void _mostrarDetallePago(EventoAuditoria e) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _DetalleSheet(
        titulo: e.evento,
        color: _colorEstadoPago(e.estado),
        icono: _iconoProveedor(e.proveedor),
        fecha: _formatFechaLarga(e.fecha),
        filas: [
          ('Proveedor', e.proveedor),
          ('Estado', e.estado.toUpperCase()),
          if (e.importe != null)
            ('Importe', '${e.importe!.toStringAsFixed(2)} ${e.moneda ?? '€'}'),
        ],
      ),
    );
  }
}

// ── Widgets compartidos ──────────────────────────────────────────────────

class _FondoConVelado extends StatelessWidget {
  const _FondoConVelado();

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: RepaintBoundary(
        child: Stack(
          fit: StackFit.expand,
          children: [
            const Image(
              image: AssetImage('assets/images/Bravo restaurante.jpg'),
              fit: BoxFit.cover,
            ),
            DecoratedBox(
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
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final int erroresPago;
  const _Header({required this.erroresPago});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 12),
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
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _BadgeErrores(count: erroresPago),
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
}

class _BadgeErrores extends StatelessWidget {
  final int count;
  const _BadgeErrores({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.2),
        borderRadius: _kRadiusSm,
        border: Border.all(color: AppColors.error.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            size: 12,
            color: AppColors.error,
          ),
          const SizedBox(width: 4),
          Text(
            '$count error${count != 1 ? 's' : ''}',
            style: GoogleFonts.manrope(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppColors.error,
            ),
          ),
        ],
      ),
    );
  }
}

class _BarraTabs extends StatelessWidget {
  final TabController controller;
  final int conteoUsuarios;
  final int conteoPagos;
  const _BarraTabs({
    required this.controller,
    required this.conteoUsuarios,
    required this.conteoPagos,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        borderRadius: _kRadiusSm,
        border: Border.all(color: Colors.white12),
        color: Colors.white.withValues(alpha: 0.05),
      ),
      child: TabBar(
        controller: controller,
        indicator: BoxDecoration(
          color: AppColors.button.withValues(alpha: 0.15),
          borderRadius: _kRadiusSm,
          border: Border.all(color: AppColors.button.withValues(alpha: 0.6)),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        labelColor: Colors.white,
        unselectedLabelColor: Colors.white38,
        labelStyle: GoogleFonts.manrope(
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
        unselectedLabelStyle: GoogleFonts.manrope(
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
        dividerColor: Colors.transparent,
        tabs: [
          _TabItem(
            icono: Icons.manage_accounts_outlined,
            texto: 'USUARIOS',
            count: conteoUsuarios,
          ),
          _TabItem(
            icono: Icons.payment_outlined,
            texto: 'PAGOS',
            count: conteoPagos,
          ),
        ],
      ),
    );
  }
}

class _TabItem extends StatelessWidget {
  final IconData icono;
  final String texto;
  final int count;
  const _TabItem({
    required this.icono,
    required this.texto,
    required this.count,
  });

  @override
  Widget build(BuildContext context) {
    return Tab(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icono, size: 15),
          const SizedBox(width: 6),
          Text(texto),
          if (count > 0) ...[
            const SizedBox(width: 6),
            _ChipContador(texto: '$count'),
          ],
        ],
      ),
    );
  }
}

class _ChipContador extends StatelessWidget {
  final String texto;
  const _ChipContador({required this.texto});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        texto,
        style: GoogleFonts.manrope(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: Colors.white70,
        ),
      ),
    );
  }
}

// ── Filtros ──────────────────────────────────────────────────────────────

class _FiltroAcciones extends StatelessWidget {
  final String seleccionada;
  final ValueChanged<String> onSeleccion;
  const _FiltroAcciones({
    required this.seleccionada,
    required this.onSeleccion,
  });

  @override
  Widget build(BuildContext context) {
    final acciones = _kAccionesDisponibles.keys.toList();
    return SizedBox(
      height: 32,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: acciones.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (_, i) => _ChipFiltro(
          label: _kAccionesDisponibles[acciones[i]]!,
          seleccionado: seleccionada == acciones[i],
          onTap: () => onSeleccion(acciones[i]),
        ),
      ),
    );
  }
}

class _FiltroEstadoPagoBar extends StatelessWidget {
  final _FiltroEstadoPago seleccionado;
  final ValueChanged<_FiltroEstadoPago> onSeleccion;
  const _FiltroEstadoPagoBar({
    required this.seleccionado,
    required this.onSeleccion,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 32,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: _FiltroEstadoPago.values.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final f = _FiltroEstadoPago.values[i];
          return _ChipFiltro(
            label: f.label,
            seleccionado: seleccionado == f,
            onTap: () => onSeleccion(f),
          );
        },
      ),
    );
  }
}

class _ChipFiltro extends StatelessWidget {
  final String label;
  final bool seleccionado;
  final VoidCallback onTap;
  const _ChipFiltro({
    required this.label,
    required this.seleccionado,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: _kRadiusSm,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: seleccionado
                ? AppColors.button
                : Colors.white.withValues(alpha: 0.07),
            borderRadius: _kRadiusSm,
            border: Border.all(
              color: seleccionado ? AppColors.button : Colors.white12,
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: GoogleFonts.manrope(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: seleccionado ? Colors.white : Colors.white54,
            ),
          ),
        ),
      ),
    );
  }
}

// ── Estados (vacío / error) ──────────────────────────────────────────────

class _EstadoVacio extends StatelessWidget {
  final String mensaje;
  const _EstadoVacio({required this.mensaje});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.history_outlined, size: 64, color: Colors.white24),
          const SizedBox(height: 16),
          Text(
            mensaje,
            style: GoogleFonts.manrope(color: Colors.white38, fontSize: 14),
          ),
        ],
      ),
    );
  }
}

class _EstadoError extends StatelessWidget {
  final VoidCallback onRetry;
  const _EstadoError({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.wifi_off_outlined, color: Colors.white24, size: 48),
          const SizedBox(height: 12),
          Text(
            'Error al cargar datos',
            style: GoogleFonts.manrope(color: Colors.white38),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh, size: 16),
            label: const Text('REINTENTAR'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.button,
              foregroundColor: Colors.white,
              shape: const RoundedRectangleBorder(borderRadius: _kRadius),
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Layout de tile centrado ──────────────────────────────────────────────

class _ConstrainedCenter extends StatelessWidget {
  final Widget child;
  const _ConstrainedCenter({required this.child});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: _kMaxTileWidth),
        child: child,
      ),
    );
  }
}

// ── Tile evento de usuario ───────────────────────────────────────────────

class _EventoUsuarioTile extends StatelessWidget {
  final EventoGeneral evento;
  final VoidCallback onTap;
  const _EventoUsuarioTile({required this.evento, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = _colorAccion(evento.accion);
    final icono = _iconoAccion(evento.accion);
    final etiqueta = _etiquetaAccion(evento.accion);
    final fecha = _formatFecha(evento.fecha);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: _kRadius,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.06),
              borderRadius: _kRadius,
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: IntrinsicHeight(
              child: Row(
                children: [
                  Container(
                    width: 4,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.8),
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(12),
                        bottomLeft: Radius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
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
                              _TagAccion(label: etiqueta, color: color),
                              const Spacer(),
                              Text(
                                fecha,
                                style: GoogleFonts.manrope(
                                  fontSize: 10,
                                  color: Colors.white60,
                                  fontFeatures: const [
                                    FontFeature.tabularFigures(),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          if (evento.objetivo != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              evento.objetivo!,
                              style: GoogleFonts.manrope(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                          if (evento.detalle != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              evento.detalle!,
                              style: GoogleFonts.manrope(
                                fontSize: 11,
                                color: Colors.white54,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                          if (evento.actor != null) ...[
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(
                                  Icons.person_outline,
                                  size: 11,
                                  color: Colors.white.withValues(alpha: 0.45),
                                ),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    evento.actor!,
                                    style: GoogleFonts.manrope(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white.withValues(alpha: 0.55),
                                      letterSpacing: 0.2,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TagAccion extends StatelessWidget {
  final String label;
  final Color color;
  const _TagAccion({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label.toUpperCase(),
        style: GoogleFonts.manrope(
          fontSize: 9,
          fontWeight: FontWeight.w800,
          color: color,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

// ── Tile evento de pago ──────────────────────────────────────────────────

class _EventoPagoTile extends StatelessWidget {
  final EventoAuditoria evento;
  final VoidCallback onTap;
  const _EventoPagoTile({required this.evento, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = _colorEstadoPago(evento.estado);
    final icono = _iconoProveedor(evento.proveedor);
    final fecha = _formatFecha(evento.fecha);
    final esError = evento.estado.toLowerCase() == 'error';
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: _kRadius,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.06),
              borderRadius: _kRadius,
              border: Border.all(
                color: esError
                    ? AppColors.error.withValues(alpha: 0.3)
                    : Colors.white.withValues(alpha: 0.08),
              ),
            ),
            child: IntrinsicHeight(
              child: Row(
                children: [
                  Container(
                    width: 4,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.8),
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(12),
                        bottomLeft: Radius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.07),
                      borderRadius: BorderRadius.circular(8),
                    ),
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
                                child: Text(
                                  evento.evento,
                                  style: GoogleFonts.manrope(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (evento.importe != null)
                                Text(
                                  '${evento.importe!.toStringAsFixed(2)} ${evento.moneda ?? '€'}',
                                  style: GoogleFonts.manrope(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                    color: esError
                                        ? AppColors.error
                                        : AppColors.button,
                                    fontFeatures: const [
                                      FontFeature.tabularFigures(),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Text(
                                evento.proveedor,
                                style: GoogleFonts.manrope(
                                  fontSize: 11,
                                  color: Colors.white54,
                                ),
                              ),
                              const SizedBox(width: 8),
                              _TagAccion(
                                label: evento.estado,
                                color: color,
                              ),
                              const Spacer(),
                              Text(
                                fecha,
                                style: GoogleFonts.manrope(
                                  fontSize: 10,
                                  color: Colors.white60,
                                  fontFeatures: const [
                                    FontFeature.tabularFigures(),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Bottom sheet de detalle ──────────────────────────────────────────────

class _DetalleSheet extends StatelessWidget {
  final String titulo;
  final Color color;
  final IconData icono;
  final String fecha;
  final List<(String, String)> filas;

  const _DetalleSheet({
    required this.titulo,
    required this.color,
    required this.icono,
    required this.fecha,
    required this.filas,
  });

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.42,
      minChildSize: 0.25,
      maxChildSize: 0.85,
      expand: false,
      builder: (_, scrollCtrl) => Container(
        decoration: const BoxDecoration(
          color: AppColors.backgroundDark,
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
        child: ListView(
          controller: scrollCtrl,
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
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: _kRadiusSm,
                    border: Border.all(color: color.withValues(alpha: 0.5)),
                  ),
                  child: Icon(icono, color: color, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    titulo,
                    style: GoogleFonts.manrope(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              fecha,
              style: GoogleFonts.manrope(
                color: Colors.white54,
                fontSize: 12,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            const SizedBox(height: 20),
            for (final fila in filas) _FilaDetalle(label: fila.$1, valor: fila.$2),
          ],
        ),
      ),
    );
  }
}

class _FilaDetalle extends StatelessWidget {
  final String label;
  final String valor;
  const _FilaDetalle({required this.label, required this.valor});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: GoogleFonts.manrope(
              color: Colors.white38,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 4),
          SelectableText(
            valor,
            style: GoogleFonts.manrope(
              color: Colors.white,
              fontSize: 13,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:frontend/core/app_routes.dart';
import 'package:frontend/core/app_snackbar.dart';
import 'package:frontend/core/colors_style.dart';
import 'package:frontend/models/reserva_model.dart';
import 'package:frontend/screens/trabajador/Reservas/reserva_mesa_trabajador.dart';
import 'package:frontend/screens/trabajador/appbar_trabajador.dart';
import 'package:frontend/services/reserva_service.dart';
import 'package:intl/intl.dart';

// ─────────────────────────────────────────────────────────────
// RAÍZ
// ─────────────────────────────────────────────────────────────
class GestionReservas extends StatefulWidget {
  const GestionReservas({super.key});

  @override
  State<GestionReservas> createState() => _GestionReservasState();
}

class _GestionReservasState extends State<GestionReservas>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  List<Reserva> _reservas = [];
  bool _cargando = true;
  String? _error;
  Timer? _pollingTimer;

  // Historial: buscador por nombre
  String _busquedaHistorial = '';
  final TextEditingController _ctrlBusqueda = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _cargarReservas();
    _pollingTimer = Timer.periodic(
      const Duration(seconds: 60),
      (_) => _cargarReservas(),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    _pollingTimer?.cancel();
    _ctrlBusqueda.dispose();
    super.dispose();
  }

  Future<void> _cargarReservas() async {
    try {
      // Usamos `obtenerReservasAdmin` (endpoint /reservas/admin) que devuelve
      // TODAS las reservas (pasadas + futuras) y aplica aislamiento por
      // sucursal automáticamente desde el JWT. Lo necesitamos así para que
      // el tab "Historial" muestre tanto canceladas como reservas con
      // fecha anterior a hoy. /reservas/futuras se reserva para el portal
      // del cliente, que solo quiere las próximas.
      final raw = await ReservaService.obtenerReservasAdmin();
      final lista = raw.map((m) => Reserva.fromMap(m)).toList();
      if (!mounted) return;
      setState(() {
        _reservas = lista;
        _cargando = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _cargando = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _refrescar() async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    await _cargarReservas();
  }

  // ── Filtros por tab ────────────────────────────────────────

  DateTime get _hoy {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  bool _esHoy(Reserva r) {
    final f = DateTime(r.fecha.year, r.fecha.month, r.fecha.day);
    return f.isAtSameMomentAs(_hoy);
  }

  bool _esProxima(Reserva r) {
    final f = DateTime(r.fecha.year, r.fecha.month, r.fecha.day);
    return f.isAfter(_hoy);
  }

  /// Historial: reservas con fecha anterior a hoy, sumadas a cualquier
  /// reserva en estado `Cancelada` aunque sea futura. /reservas/admin
  /// devuelve también las pasadas, así que el tab refleja el historial
  /// completo de la sucursal.
  bool _esHistorial(Reserva r) {
    final f = DateTime(r.fecha.year, r.fecha.month, r.fecha.day);
    return f.isBefore(_hoy) || r.estado.toLowerCase() == 'cancelada';
  }

  List<Reserva> get _hoy_ =>
      _reservas.where((r) => _esHoy(r) && r.estado.toLowerCase() != 'cancelada').toList();

  List<Reserva> get _proximas =>
      _reservas.where((r) => _esProxima(r) && r.estado.toLowerCase() != 'cancelada').toList();

  List<Reserva> get _historial {
    final base = _reservas.where(_esHistorial).toList();
    if (_busquedaHistorial.trim().isEmpty) return base;
    final q = _busquedaHistorial.trim().toLowerCase();
    return base
        .where((r) => r.nombreCompleto.toLowerCase().contains(q))
        .toList();
  }

  // ── Acciones ──────────────────────────────────────────────

  Future<void> _cancelarReserva(Reserva reserva) async {
    final fecha = DateFormat('d/M/yyyy').format(reserva.fecha);
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.panel,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Cancelar reserva',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
            fontFamily: 'Playfair Display',
          ),
        ),
        content: Text(
          '¿Cancelar la reserva de ${reserva.nombreCompleto} '
          'para el día $fecha a las ${reserva.hora}?',
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text(
              'VOLVER',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text(
              'CANCELAR RESERVA',
              style: TextStyle(
                color: AppColors.error,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
    if (confirmado != true || !mounted) return;

    try {
      await ReservaService.cambiarEstadoReserva(reserva.id, 'Cancelada');
      if (!mounted) return;
      showAppSuccess(context, 'Reserva cancelada');
      await _cargarReservas();
    } catch (e) {
      if (!mounted) return;
      showAppError(
        context,
        'Error al cancelar: ${e.toString().replaceFirst('Exception: ', '')}',
      );
    }
  }

  /// Marca la reserva como `Llegado` — el cliente acaba de entrar.
  /// Cambia el estado y refresca la lista. La mesa ya está reservada
  /// para esa hora, así que el camarero la atiende como cualquier mesa.
  Future<void> _marcarLlego(Reserva reserva) async {
    try {
      await ReservaService.cambiarEstadoReserva(reserva.id, 'Llegado');
      if (!mounted) return;
      showAppSuccess(context, '${reserva.nombreCompleto} ha llegado');
      await _cargarReservas();
    } catch (e) {
      if (!mounted) return;
      showAppError(
        context,
        'Error: ${e.toString().replaceFirst('Exception: ', '')}',
      );
    }
  }

  /// Marca la reserva como `NoShow` — el cliente no se ha presentado.
  /// Pide confirmación porque libera el slot y queda en histórico.
  Future<void> _marcarNoShow(Reserva reserva) async {
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.panel,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          '¿Marcar como no presentado?',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
            fontFamily: 'Playfair Display',
          ),
        ),
        content: Text(
          '${reserva.nombreCompleto} no ha venido. La reserva quedará '
          'archivada como No-Show y la mesa pasa a libre.',
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text(
              'VOLVER',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text(
              'NO VINO',
              style: TextStyle(
                color: AppColors.error,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
    if (confirmado != true || !mounted) return;
    try {
      await ReservaService.cambiarEstadoReserva(reserva.id, 'NoShow');
      if (!mounted) return;
      showAppSuccess(context, 'Reserva archivada como no presentada');
      await _cargarReservas();
    } catch (e) {
      if (!mounted) return;
      showAppError(
        context,
        'Error: ${e.toString().replaceFirst('Exception: ', '')}',
      );
    }
  }

  Future<void> _editarReserva(Reserva reserva) async {
    await showDialog<void>(
      context: context,
      builder: (_) => _EditarReservaDialog(
        reserva: reserva,
        onSave: (updated) async {
          try {
            await ReservaService.actualizarReserva(updated);
            if (!mounted) return;
            showAppSuccess(context, 'Reserva actualizada');
            await _cargarReservas();
          } catch (e) {
            if (mounted) {
              showAppError(
                context,
                'Error al guardar: ${e.toString().replaceFirst('Exception: ', '')}',
              );
            }
            // Re-lanzar para que el dialog mantenga el formulario abierto y
            // el camarero pueda ajustar lo que el backend rechazó (por ej.
            // sin disponibilidad de mesa, fecha pasada, comensales fuera de
            // rango, etc.) en lugar de tener que reabrir y reescribir todo.
            rethrow;
          }
        },
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: const TrabajadorAppBar(title: 'GESTIÓN DE RESERVAS'),
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
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withValues(alpha: 0.5),
                Colors.black.withValues(alpha: 0.92),
              ],
            ),
          ),
          child: SafeArea(
            child: FadeSlideIn(
              child: Column(
                children: [
                // TabBar dentro del body (ya no en AppBar.bottom). Fondo
                // ligeramente más oscuro que la página para dar contexto.
                Container(
                  color: Colors.black.withValues(alpha: 0.35),
                  child: TabBar(
                    controller: _tabController,
                    indicatorColor: AppColors.button,
                    indicatorWeight: 3,
                    labelColor: Colors.white,
                    unselectedLabelColor: Colors.white60,
                    labelStyle: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                      letterSpacing: 0.8,
                    ),
                    unselectedLabelStyle: const TextStyle(
                      fontWeight: FontWeight.w500,
                      fontSize: 12,
                    ),
                    tabs: [
                      _TabConBadge(label: 'HOY', count: _hoy_.length),
                      _TabConBadge(label: 'PRÓXIMAS', count: _proximas.length),
                      const Tab(text: 'HISTORIAL'),
                    ],
                  ),
                ),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _TabReservas(
                        reservas: _hoy_,
                        cargando: _cargando,
                        error: _error,
                        mensajeVacio: 'Sin reservas para hoy',
                        onRefresh: _refrescar,
                        onModificar: _editarReserva,
                        onCancelar: _cancelarReserva,
                        onLlego: _marcarLlego,
                        onNoShow: _marcarNoShow,
                      ),
                      _TabReservas(
                        reservas: _proximas,
                        cargando: _cargando,
                        error: _error,
                        mensajeVacio: 'Sin reservas próximas',
                        onRefresh: _refrescar,
                        onModificar: _editarReserva,
                        onCancelar: _cancelarReserva,
                      ),
                      _TabHistorial(
                        reservas: _historial,
                        cargando: _cargando,
                        error: _error,
                        onRefresh: _refrescar,
                        busqueda: _busquedaHistorial,
                        ctrlBusqueda: _ctrlBusqueda,
                        onBusquedaCambiada: (v) =>
                            setState(() => _busquedaHistorial = v),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.push(
            context,
            AppRoute.slide(const ReservaMesaTrabajador()),
          );
          _cargarReservas();
        },
        backgroundColor: AppColors.button,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text(
          'CREAR RESERVA',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 12,
            letterSpacing: 0.8,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// WIDGET AUXILIAR — Tab con badge de conteo
// ─────────────────────────────────────────────────────────────
class _TabConBadge extends StatelessWidget {
  final String label;
  final int count;

  const _TabConBadge({required this.label, required this.count});

  @override
  Widget build(BuildContext context) {
    return Tab(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label),
          if (count > 0) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: const TextStyle(
                  color: AppColors.button,
                  fontWeight: FontWeight.w700,
                  fontSize: 11,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// WIDGET AUXILIAR — Estado vacío / error / loading uniforme
// ─────────────────────────────────────────────────────────────
class _EstadoTab extends StatelessWidget {
  final bool cargando;
  final String? error;
  final bool estaVacio;
  final String mensajeVacio;
  final VoidCallback onReintentar;

  const _EstadoTab({
    required this.cargando,
    required this.error,
    required this.estaVacio,
    required this.mensajeVacio,
    required this.onReintentar,
  });

  @override
  Widget build(BuildContext context) {
    if (cargando) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.button, strokeWidth: 2.5),
      );
    }
    if (error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: AppColors.error),
              const SizedBox(height: 12),
              Text(
                error!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: onReintentar,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.button,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  'REINTENTAR',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }
    if (estaVacio) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.event_busy_outlined,
              size: 52,
              color: AppColors.textSecondary.withValues(alpha: 0.25),
            ),
            const SizedBox(height: 14),
            Text(
              mensajeVacio,
              style: TextStyle(
                color: AppColors.textSecondary.withValues(alpha: 0.5),
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }
    return const SizedBox.shrink();
  }
}

// ─────────────────────────────────────────────────────────────
// TAB — HOY y PRÓXIMAS (acciones: Modificar + Cancelar)
// ─────────────────────────────────────────────────────────────
class _TabReservas extends StatelessWidget {
  final List<Reserva> reservas;
  final bool cargando;
  final String? error;
  final String mensajeVacio;
  final Future<void> Function() onRefresh;
  final Future<void> Function(Reserva) onModificar;
  final Future<void> Function(Reserva) onCancelar;
  // Solo aplica al tab "Hoy" — confirmar que el cliente llegó o no vino.
  final Future<void> Function(Reserva)? onLlego;
  final Future<void> Function(Reserva)? onNoShow;

  const _TabReservas({
    required this.reservas,
    required this.cargando,
    required this.error,
    required this.mensajeVacio,
    required this.onRefresh,
    required this.onModificar,
    required this.onCancelar,
    this.onLlego,
    this.onNoShow,
  });

  @override
  Widget build(BuildContext context) {
    final mostrarEstado = cargando || error != null || reservas.isEmpty;
    if (mostrarEstado) {
      return _EstadoTab(
        cargando: cargando,
        error: error,
        estaVacio: reservas.isEmpty,
        mensajeVacio: mensajeVacio,
        onReintentar: onRefresh,
      );
    }
    return RefreshIndicator(
      onRefresh: onRefresh,
      color: AppColors.button,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
        itemCount: reservas.length,
        itemBuilder: (_, i) => _ReservaTile(
          reserva: reservas[i],
          onModificar: () => onModificar(reservas[i]),
          onCancelar: () => onCancelar(reservas[i]),
          onLlego: onLlego == null ? null : () => onLlego!(reservas[i]),
          onNoShow: onNoShow == null ? null : () => onNoShow!(reservas[i]),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// TAB — HISTORIAL (solo lectura + buscador)
// ─────────────────────────────────────────────────────────────
class _TabHistorial extends StatelessWidget {
  final List<Reserva> reservas;
  final bool cargando;
  final String? error;
  final Future<void> Function() onRefresh;
  final String busqueda;
  final TextEditingController ctrlBusqueda;
  final ValueChanged<String> onBusquedaCambiada;

  const _TabHistorial({
    required this.reservas,
    required this.cargando,
    required this.error,
    required this.onRefresh,
    required this.busqueda,
    required this.ctrlBusqueda,
    required this.onBusquedaCambiada,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Barra de búsqueda
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.panel,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.line),
            ),
            child: Row(
              children: [
                const Icon(Icons.search, color: AppColors.textSecondary, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: ctrlBusqueda,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 14,
                    ),
                    decoration: const InputDecoration(
                      hintText: 'Buscar por nombre...',
                      hintStyle: TextStyle(color: AppColors.textSecondary),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(vertical: 8),
                    ),
                    onChanged: onBusquedaCambiada,
                  ),
                ),
                if (busqueda.isNotEmpty)
                  Semantics(
                    label: 'Limpiar búsqueda',
                    button: true,
                    child: GestureDetector(
                      onTap: () {
                        ctrlBusqueda.clear();
                        onBusquedaCambiada('');
                      },
                      child: const Icon(
                        Icons.close,
                        color: AppColors.textSecondary,
                        size: 18,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: Builder(
            builder: (context) {
              final mostrarEstado = cargando || error != null || reservas.isEmpty;
              if (mostrarEstado) {
                return _EstadoTab(
                  cargando: cargando,
                  error: error,
                  estaVacio: reservas.isEmpty,
                  mensajeVacio: 'Sin reservas en el historial',
                  onReintentar: onRefresh,
                );
              }
              return RefreshIndicator(
                onRefresh: onRefresh,
                color: AppColors.button,
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
                  itemCount: reservas.length,
                  itemBuilder: (_, i) => _ReservaTile(
                    reserva: reservas[i],
                    soloLectura: true,
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
// COMPONENTE — Tarjeta de reserva
// ─────────────────────────────────────────────────────────────
class _ReservaTile extends StatelessWidget {
  final Reserva reserva;
  final VoidCallback? onModificar;
  final VoidCallback? onCancelar;
  // Solo presentes en el tab "Hoy" para confirmar llegada / no presentación.
  // Se renderizan únicamente si la reserva sigue en estado activo
  // (Confirmada/Pendiente).
  final VoidCallback? onLlego;
  final VoidCallback? onNoShow;
  final bool soloLectura;

  const _ReservaTile({
    required this.reserva,
    this.onModificar,
    this.onCancelar,
    this.onLlego,
    this.onNoShow,
    this.soloLectura = false,
  });

  bool get _puedeMarcarLlegada {
    final e = reserva.estado.toLowerCase();
    return e == 'confirmada' || e == 'pendiente';
  }

  Color get _colorEstado {
    switch (reserva.estado.toLowerCase()) {
      case 'confirmada':
        return AppColors.disp;
      case 'pendiente':
        return AppColors.warningLight;
      case 'cancelada':
        return AppColors.error;
      default:
        return AppColors.info;
    }
  }

  String get _labelEstado => reserva.estado.toUpperCase();

  String get _turnoLabel => reserva.turno == 'cena' ? 'CENA' : 'COMIDA';

  @override
  Widget build(BuildContext context) {
    final colorEstado = _colorEstado;
    final contacto = reserva.telefonoCliente ?? reserva.correoCliente;

    return Semantics(
      label:
          'Reserva de ${reserva.nombreCompleto}, ${reserva.hora}, ${reserva.comensales} comensales, estado ${reserva.estado}',
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: AppColors.panel,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.line),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Fila 1: estado + turno + hora
              Row(
                children: [
                  // Chip estado
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: colorEstado.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: colorEstado.withValues(alpha: 0.35),
                      ),
                    ),
                    child: Text(
                      _labelEstado,
                      style: TextStyle(
                        color: colorEstado,
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Chip turno
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.textSecondary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      _turnoLabel,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const Spacer(),
                  // Hora destacada
                  Text(
                    reserva.hora,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Fila 2: nombre del cliente
              Text(
                reserva.nombreCompleto,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 6),
              // Fila 3: comensales + mesa
              Row(
                children: [
                  const Icon(
                    Icons.people_outline,
                    size: 14,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${reserva.comensales} pax',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                  if (reserva.numeroMesa != null) ...[
                    const SizedBox(width: 12),
                    const Icon(
                      Icons.table_bar,
                      size: 14,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Mesa ${reserva.numeroMesa}',
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ],
                  if (contacto != null) ...[
                    const SizedBox(width: 12),
                    const Icon(
                      Icons.contact_phone_outlined,
                      size: 14,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        contacto,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ],
              ),
              // Notas
              if (reserva.notas != null && reserva.notas!.isNotEmpty) ...[
                const SizedBox(height: 6),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.note_outlined,
                      size: 13,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        reserva.notas!,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
              // Botones de acción (no en historial)
              if (!soloLectura) ...[
                const SizedBox(height: 10),
                Wrap(
                  alignment: WrapAlignment.end,
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    // NO VINO — solo en tab Hoy y si la reserva sigue activa
                    if (onNoShow != null && _puedeMarcarLlegada)
                      OutlinedButton(
                        onPressed: onNoShow,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.error,
                          side: const BorderSide(
                            color: AppColors.error,
                            width: 0.8,
                          ),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 7),
                          minimumSize: const Size(0, 36),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text(
                          'NO VINO',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    // LLEGÓ — solo en tab Hoy y si la reserva sigue activa.
                    // Verde para diferenciarlo del rojo de cancelar/no vino.
                    if (onLlego != null && _puedeMarcarLlegada)
                      ElevatedButton(
                        onPressed: onLlego,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.disp,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 7),
                          minimumSize: const Size(0, 36),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text(
                          'LLEGÓ',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    // Cancelar — acción secundaria destructiva
                    OutlinedButton(
                      onPressed: onCancelar,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.error,
                        side: const BorderSide(color: AppColors.error, width: 0.8),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 7),
                        minimumSize: const Size(0, 36),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        'CANCELAR',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    // Modificar — acción principal
                    ElevatedButton(
                      onPressed: onModificar,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.button,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 7),
                        minimumSize: const Size(0, 36),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        'MODIFICAR',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// DIALOG — Editar reserva (extraído de modificar_reservas.dart)
// ─────────────────────────────────────────────────────────────
class _EditarReservaDialog extends StatefulWidget {
  final Reserva reserva;
  final Future<void> Function(Reserva) onSave;

  const _EditarReservaDialog({
    required this.reserva,
    required this.onSave,
  });

  @override
  State<_EditarReservaDialog> createState() => _EditarReservaDialogState();
}

// Horas válidas por turno (mismo set que la pantalla de creación).
const Map<String, List<String>> _horasPorTurnoEdit = {
  'comida': [
    '12:30', '13:00', '13:30', '14:00',
    '14:30', '15:00', '15:30', '16:00',
  ],
  'cena': [
    '20:00', '20:30', '21:00', '21:30',
    '22:00', '22:30', '23:00', '23:30',
  ],
};
const int _maxComensalesEdit = 20;

class _EditarReservaDialogState extends State<_EditarReservaDialog> {
  late DateTime _fecha;
  late String _hora;
  late int _comensales;
  late String _turno;
  late TextEditingController _notasController;
  bool _guardando = false;

  @override
  void initState() {
    super.initState();
    _fecha = widget.reserva.fecha;
    _turno = _horasPorTurnoEdit.containsKey(widget.reserva.turno)
        ? widget.reserva.turno
        : 'comida';
    // Si la hora actual no está en el slot del turno, caer a la primera válida.
    _hora = _horasPorTurnoEdit[_turno]!.contains(widget.reserva.hora)
        ? widget.reserva.hora
        : _horasPorTurnoEdit[_turno]!.first;
    _comensales = widget.reserva.comensales.clamp(1, _maxComensalesEdit);
    _notasController = TextEditingController(text: widget.reserva.notas ?? '');
  }

  @override
  void dispose() {
    _notasController.dispose();
    super.dispose();
  }

  /// La reserva ya pasó: combina fecha + hora y compara con ahora.
  bool get _reservaPasada {
    final partes = widget.reserva.hora.split(':');
    if (partes.length != 2) return false;
    final h = int.tryParse(partes[0]) ?? 0;
    final m = int.tryParse(partes[1]) ?? 0;
    final slot = DateTime(
      widget.reserva.fecha.year,
      widget.reserva.fecha.month,
      widget.reserva.fecha.day,
      h,
      m,
    );
    return slot.isBefore(DateTime.now());
  }

  Future<void> _selectFecha() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _fecha.isAfter(DateTime.now()) ? _fecha : DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() => _fecha = picked);
    }
  }

  void _cambiarTurno(String? nuevo) {
    if (nuevo == null) return;
    setState(() {
      _turno = nuevo;
      // Resetear hora a la primera válida del nuevo turno para que no
      // queden combinaciones imposibles (ej. turno=cena con hora=14:00).
      _hora = _horasPorTurnoEdit[nuevo]!.first;
    });
  }

  void _cambiarComensales(int delta) {
    final nuevo = _comensales + delta;
    if (nuevo < 1 || nuevo > _maxComensalesEdit) return;
    setState(() => _comensales = nuevo);
  }

  Future<void> _save() async {
    if (_guardando) return;
    setState(() => _guardando = true);

    final notas = _notasController.text.trim().isEmpty
        ? null
        : _notasController.text.trim();
    final updated = widget.reserva.copyWith(
      fecha: _fecha,
      hora: _hora,
      comensales: _comensales,
      turno: _turno,
      notas: notas,
    );

    try {
      await widget.onSave(updated);
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      // El parent (gestion_reservas) ya muestra el error con showAppError.
      // Aquí nos quedamos con el dialog abierto para que el camarero ajuste
      // los datos en lugar de perder el formulario.
      if (!mounted) return;
      setState(() => _guardando = false);
    }
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(
        color: AppColors.textSecondary,
        fontWeight: FontWeight.w500,
      ),
      filled: true,
      fillColor: AppColors.background,
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.line),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.button, width: 2),
      ),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    );
  }

  Widget _input(
    TextEditingController controller,
    String label, {
    int maxLines = 1,
    TextInputType? keyboard,
    VoidCallback? onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextField(
        controller: controller,
        readOnly: onTap != null,
        onTap: onTap,
        maxLines: maxLines,
        keyboardType: keyboard,
        style: const TextStyle(color: AppColors.textPrimary, fontSize: 15),
        decoration: _inputDecoration(label),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pasada = _reservaPasada;
    final fechaTexto = DateFormat('dd/MM/yyyy').format(_fecha);
    final horasDisponibles = _horasPorTurnoEdit[_turno]!;

    return AlertDialog(
      backgroundColor: AppColors.panel,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text(
        'Editar reserva',
        style: TextStyle(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.bold,
          fontFamily: 'Playfair Display',
        ),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Aviso si la reserva ya pasó: solo lectura, no se puede mover.
            if (pasada)
              Container(
                margin: const EdgeInsets.only(bottom: 14),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppColors.error.withValues(alpha: 0.4),
                  ),
                ),
                child: const Text(
                  'Esta reserva ya ha pasado. No se puede modificar.',
                  style: TextStyle(color: AppColors.error, fontSize: 12),
                ),
              ),

            // Fecha
            InkWell(
              onTap: pasada ? null : _selectFecha,
              child: InputDecorator(
                decoration: _inputDecoration('Fecha').copyWith(
                  suffixIcon: const Icon(
                    Icons.calendar_today_outlined,
                    size: 18,
                    color: AppColors.textSecondary,
                  ),
                ),
                child: Text(
                  fechaTexto,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 15,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Turno
            DropdownButtonFormField<String>(
              initialValue: _turno,
              dropdownColor: AppColors.panel,
              decoration: _inputDecoration('Turno'),
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 15,
              ),
              items: const [
                DropdownMenuItem(
                  value: 'comida',
                  child: Text(
                    'Comida',
                    style: TextStyle(color: AppColors.textPrimary),
                  ),
                ),
                DropdownMenuItem(
                  value: 'cena',
                  child: Text(
                    'Cena',
                    style: TextStyle(color: AppColors.textPrimary),
                  ),
                ),
              ],
              onChanged: pasada ? null : _cambiarTurno,
            ),
            const SizedBox(height: 14),

            // Hora — chips de horas válidas según turno
            const Padding(
              padding: EdgeInsets.only(bottom: 6, left: 4),
              child: Text(
                'Hora',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final h in horasDisponibles)
                  ChoiceChip(
                    label: Text(h),
                    selected: _hora == h,
                    onSelected: pasada
                        ? null
                        : (sel) {
                            if (sel) setState(() => _hora = h);
                          },
                    selectedColor: AppColors.button,
                    labelStyle: TextStyle(
                      color: _hora == h
                          ? Colors.white
                          : AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                    backgroundColor: AppColors.background,
                  ),
              ],
            ),
            const SizedBox(height: 14),

            // Comensales con +/-
            const Padding(
              padding: EdgeInsets.only(bottom: 6, left: 4),
              child: Text(
                'Comensales',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.line),
              ),
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'Reducir comensales',
                    onPressed: (pasada || _comensales <= 1)
                        ? null
                        : () => _cambiarComensales(-1),
                    icon: const Icon(Icons.remove_circle_outline),
                    color: AppColors.button,
                  ),
                  Expanded(
                    child: Text(
                      '$_comensales',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Aumentar comensales',
                    onPressed: (pasada || _comensales >= _maxComensalesEdit)
                        ? null
                        : () => _cambiarComensales(1),
                    icon: const Icon(Icons.add_circle_outline),
                    color: AppColors.button,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Notas
            _input(_notasController, 'Notas', maxLines: 3),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _guardando ? null : () => Navigator.of(context).pop(),
          child: const Text(
            'CANCELAR',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        TextButton(
          onPressed: (_guardando || _reservaPasada) ? null : _save,
          child: _guardando
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    color: AppColors.button,
                    strokeWidth: 2,
                  ),
                )
              : const Text(
                  'GUARDAR',
                  style: TextStyle(
                    color: AppColors.button,
                    fontWeight: FontWeight.bold,
                  ),
                ),
        ),
      ],
    );
  }
}

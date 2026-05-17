import 'dart:ui';
import 'package:flutter/material.dart';

import '../../core/colors_style.dart';
import '../../models/restaurante_model.dart';
import '../../services/reserva_service.dart';
import '../../services/restaurante_service.dart';

// ── Constantes ────────────────────────────────────────────────────────────────

const _kSheetBg = AppColors.bottomSheetBg;
const _kFieldFill = Color(0x8C000000);
const _kBorder = Color(0x33FFFFFF);

// ── Pantalla ──────────────────────────────────────────────────────────────────

/// Reservas multi-sucursal para super_admin.
/// Solo lectura + cancelar. No confirmar/rechazar/asignar mesa (eso es del admin).
class SuperReservasScreen extends StatefulWidget {
  const SuperReservasScreen({super.key});

  @override
  State<SuperReservasScreen> createState() => _SuperReservasScreenState();
}

class _SuperReservasScreenState extends State<SuperReservasScreen> {
  // ── Filtros ───────────────────────────────────────────────────────────────
  Restaurante? _sucursal; // null → todas
  DateTime _fecha = DateTime.now();
  String? _filtroEstado; // null → todas

  static const _estadosFiltro = [
    null,
    'Confirmada',
    'Pendiente',
    'Cancelada',
    'Llegado',
    'NoShow',
  ];
  static const _etiquetasFiltro = [
    'Todas',
    'Confirmada',
    'Pendiente',
    'Cancelada',
    'Llegado',
    'No Show',
  ];

  // ── Datos ─────────────────────────────────────────────────────────────────
  List<Restaurante> _sucursales = [];
  List<Map<String, dynamic>> _reservas = [];
  bool _cargandoSucursales = false;
  bool _cargando = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _cargarSucursales();
      _cargar();
    });
  }

  String get _fechaStr {
    final f = _fecha;
    return '${f.year.toString().padLeft(4, '0')}-'
        '${f.month.toString().padLeft(2, '0')}-'
        '${f.day.toString().padLeft(2, '0')}';
  }

  // ── Carga de sucursales ───────────────────────────────────────────────────

  Future<void> _cargarSucursales() async {
    setState(() => _cargandoSucursales = true);
    try {
      final lista = await RestauranteService().obtenerTodos();
      if (!mounted) return;
      setState(() {
        _sucursales = lista;
        _cargandoSucursales = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _cargandoSucursales = false);
    }
  }

  // ── Carga de reservas ─────────────────────────────────────────────────────

  Future<void> _cargar() async {
    if (!mounted) return;
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final lista = await ReservaService.obtenerReservasSuperAdmin(
        restauranteId: _sucursal?.id,
        fecha: _fechaStr,
        estado: _filtroEstado,
      );
      if (!mounted) return;
      setState(() {
        _reservas = lista;
        _cargando = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _cargando = false;
      });
    }
  }

  // ── Selector de fecha ─────────────────────────────────────────────────────

  Future<void> _seleccionarFecha() async {
    final elegida = await showDatePicker(
      context: context,
      initialDate: _fecha,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (ctx, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(
            primary: AppColors.primaryOnDark,
            surface: AppColors.bottomSheetBg,
          ),
        ),
        child: child!,
      ),
    );
    if (elegida == null || !mounted) return;
    setState(() => _fecha = elegida);
    _cargar();
  }

  // ── Bottom sheet selector de sucursal ────────────────────────────────────
  // Patrón copiado de super_cierres_caja_screen para mantener independencia entre roles.

  void _abrirSelectorSucursal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _SelectorSucursalSheet(
        sucursales: _sucursales,
        seleccionada: _sucursal,
        cargando: _cargandoSucursales,
        onSeleccionar: (r) {
          Navigator.pop(context);
          setState(() => _sucursal = r);
          _cargar();
        },
      ),
    );
  }

  // ── Cancelar reserva ──────────────────────────────────────────────────────

  Future<void> _cancelarReserva(String id, String nombreCliente) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.bottomSheetBg,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Cancelar reserva',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Text(
          '¿Cancelar la reserva de $nombreCliente?',
          style: const TextStyle(color: Colors.white70, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('NO',
                style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
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
    if (ok != true || !mounted) return;

    try {
      await ReservaService.cambiarEstadoReserva(id, 'Cancelada');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Reserva cancelada'),
            backgroundColor: AppColors.primary,
            behavior: SnackBarBehavior.floating,
          ),
        );
        _cargar();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  // ── BUILD ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final hoy = DateTime.now();
    final esHoy = _fecha.year == hoy.year &&
        _fecha.month == hoy.month &&
        _fecha.day == hoy.day;

    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text(
          'RESERVAS',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
            fontSize: 16,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
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
            child: Column(
              children: [
                _buildCabecera(esHoy),
                _buildChipsFiltro(),
                const SizedBox(height: 4),
                Expanded(child: _buildCuerpo()),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCabecera(bool esHoy) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Column(
        children: [
          // Selector de sucursal
          GestureDetector(
            onTap: _abrirSelectorSucursal,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: _kFieldFill,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _kBorder),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.storefront_outlined,
                          color: AppColors.detailOnDark, size: 18),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _sucursal?.nombre ?? 'Todas las sucursales',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      const Icon(Icons.expand_more,
                          color: Colors.white38, size: 20),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          // Selector de fecha + refresh
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: _seleccionarFecha,
                  borderRadius: BorderRadius.circular(12),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: _kFieldFill,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: _kBorder),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.calendar_today,
                                color: AppColors.detailOnDark, size: 18),
                            const SizedBox(width: 10),
                            Text(
                              esHoy ? 'Hoy' : _fechaStr,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
                              ),
                            ),
                            const Spacer(),
                            const Icon(Icons.expand_more,
                                color: Colors.white38, size: 20),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              // Botón actualizar
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    decoration: BoxDecoration(
                      color: _kFieldFill,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _kBorder),
                    ),
                    child: IconButton(
                      icon: _cargando
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.primaryOnDark,
                              ),
                            )
                          : const Icon(Icons.refresh, color: Colors.white70),
                      onPressed: _cargando ? null : _cargar,
                      tooltip: 'Actualizar reservas',
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

  Widget _buildChipsFiltro() {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _estadosFiltro.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final seleccionado = _filtroEstado == _estadosFiltro[i];
          return GestureDetector(
            onTap: () {
              setState(() => _filtroEstado = _estadosFiltro[i]);
              _cargar();
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: seleccionado
                    ? AppColors.primaryAccent
                    : Colors.black.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color:
                      seleccionado ? AppColors.primaryAccent : Colors.white24,
                ),
              ),
              child: Text(
                _etiquetasFiltro[i],
                style: TextStyle(
                  color: seleccionado ? Colors.white : Colors.white60,
                  fontSize: 13,
                  fontWeight: seleccionado
                      ? FontWeight.bold
                      : FontWeight.normal,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildCuerpo() {
    if (_cargando) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primaryOnDark),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.cloud_off_outlined,
                  color: Colors.white54, size: 64),
              const SizedBox(height: 16),
              Text(_error!,
                  style: const TextStyle(color: Colors.white70),
                  textAlign: TextAlign.center),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryAccent,
                  foregroundColor: Colors.white,
                ),
                onPressed: _cargar,
                icon: const Icon(Icons.refresh),
                label: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      );
    }

    if (_reservas.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.event_busy_outlined,
                color: Colors.white24, size: 64),
            const SizedBox(height: 16),
            Text(
              _filtroEstado != null
                  ? 'No hay reservas con estado "$_filtroEstado" para este día.'
                  : 'No hay reservas para los filtros seleccionados.',
              style: const TextStyle(color: Colors.white54, fontSize: 15),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: AppColors.primaryOnDark,
      backgroundColor: Colors.black87,
      onRefresh: _cargar,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        itemCount: _reservas.length,
        itemBuilder: (_, i) => _cardReserva(_reservas[i]),
      ),
    );
  }

  Widget _cardReserva(Map<String, dynamic> r) {
    final estado = r['estado'] as String? ?? 'Pendiente';
    final hora = r['hora'] as String? ?? '';
    final nombre = r['nombreCompleto'] as String? ?? '—';
    final comensales = r['comensales'] ?? 0;
    final numeroMesa = r['numeroMesa'];
    final notas = r['notas'] as String?;
    final id = r['id'] as String? ?? '';
    // El nombre de la sucursal puede venir en varios campos
    final sucursal = r['restaurante_nombre'] as String? ??
        r['nombre_sucursal'] as String? ??
        '';

    final esCancelada = estado == 'Cancelada';

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Fila superior: hora + nombre + estado
                Row(
                  children: [
                    Text(
                      hora,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            nombre,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          // Nombre de sucursal (útil en vista "todas")
                          if (sucursal.isNotEmpty)
                            Text(
                              sucursal,
                              style: const TextStyle(
                                color: Colors.white54,
                                fontSize: 11,
                              ),
                            ),
                        ],
                      ),
                    ),
                    _badgeEstado(estado),
                  ],
                ),
                const SizedBox(height: 8),

                // Comensales y mesa
                Row(
                  children: [
                    const Icon(Icons.people_outline,
                        color: Colors.white54, size: 16),
                    const SizedBox(width: 4),
                    Text(
                      '$comensales comensales',
                      style: const TextStyle(
                          color: Colors.white60, fontSize: 13),
                    ),
                    const SizedBox(width: 16),
                    const Icon(Icons.table_restaurant_outlined,
                        color: Colors.white54, size: 16),
                    const SizedBox(width: 4),
                    Text(
                      numeroMesa != null
                          ? 'Mesa $numeroMesa'
                          : 'Sin asignar',
                      style: TextStyle(
                        color: numeroMesa != null
                            ? Colors.white60
                            : AppColors.warningLight,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),

                if (notas != null && notas.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.notes,
                          color: Colors.white30, size: 14),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          notas,
                          style: const TextStyle(
                              color: Colors.white54, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ],

                // Botón cancelar (solo si no está ya cancelada)
                if (!esCancelada) ...[
                  const SizedBox(height: 12),
                  const Divider(color: Colors.white12, height: 1),
                  const SizedBox(height: 10),
                  Semantics(
                    label: 'Cancelar reserva de $nombre',
                    button: true,
                    child: GestureDetector(
                      onTap: () => _cancelarReserva(id, nombre),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 7),
                        decoration: BoxDecoration(
                          color: AppColors.error.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: AppColors.error.withValues(alpha: 0.4),
                          ),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.cancel_outlined,
                                color: AppColors.error, size: 15),
                            SizedBox(width: 5),
                            Text(
                              'CANCELAR',
                              style: TextStyle(
                                color: AppColors.error,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _badgeEstado(String estado) {
    final Color color;
    switch (estado) {
      case 'Confirmada':
        color = AppColors.success;
      case 'Cancelada':
        color = AppColors.error;
      case 'Llegado':
        color = AppColors.info;
      case 'NoShow':
        color = AppColors.lineStrong;
      case 'Pendiente':
      default:
        color = AppColors.warning;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        estado == 'NoShow' ? 'No Show' : estado,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

// ── Bottom sheet selector de sucursal ────────────────────────────────────────
// Copiado de super_cierres_caja_screen para mantener independencia entre roles.

class _SelectorSucursalSheet extends StatelessWidget {
  final List<Restaurante> sucursales;
  final Restaurante? seleccionada;
  final bool cargando;
  final ValueChanged<Restaurante?> onSeleccionar;

  const _SelectorSucursalSheet({
    required this.sucursales,
    required this.seleccionada,
    required this.cargando,
    required this.onSeleccionar,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: _kSheetBg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Icon(Icons.storefront_outlined,
                      color: AppColors.detailOnDark, size: 20),
                  SizedBox(width: 10),
                  Text(
                    'SELECCIONAR SUCURSAL',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            const Divider(color: Colors.white12),
            if (cargando)
              const Padding(
                padding: EdgeInsets.all(24),
                child: CircularProgressIndicator(color: AppColors.primaryOnDark),
              )
            else
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.5,
                ),
                child: ListView(
                  shrinkWrap: true,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 8),
                  children: [
                    _opcion(
                      context,
                      nombre: 'Todas las sucursales',
                      icono: Icons.layers_outlined,
                      seleccionado: seleccionada == null,
                      onTap: () => onSeleccionar(null),
                    ),
                    ...sucursales.map(
                      (r) => _opcion(
                        context,
                        nombre: r.nombre,
                        icono: Icons.storefront_outlined,
                        seleccionado: seleccionada?.id == r.id,
                        onTap: () => onSeleccionar(r),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _opcion(
    BuildContext context, {
    required String nombre,
    required IconData icono,
    required bool seleccionado,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(
        icono,
        color: seleccionado ? AppColors.detailOnDark : Colors.white54,
        size: 20,
      ),
      title: Text(
        nombre,
        style: TextStyle(
          color: seleccionado ? AppColors.linkOnDark : Colors.white,
          fontWeight:
              seleccionado ? FontWeight.bold : FontWeight.normal,
          fontSize: 14,
        ),
      ),
      trailing: seleccionado
          ? const Icon(Icons.check, color: AppColors.detailOnDark, size: 18)
          : null,
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      onTap: onTap,
    );
  }
}

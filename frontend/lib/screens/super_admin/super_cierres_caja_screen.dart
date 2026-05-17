import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/colors_style.dart';
import '../../models/restaurante_model.dart';
import '../../screens/Administrador/admin_cierre_detalle_screen.dart';
import '../../services/cierre_caja_service.dart';
import '../../services/restaurante_service.dart';

// ── Formateadores ─────────────────────────────────────────────────────────────
final _fmtFecha = DateFormat('dd/MM/yyyy');
final _fmtHora = DateFormat('HH:mm');
final _fmtEuros = NumberFormat('#,##0.00', 'es_ES');

// ── Pantalla principal ────────────────────────────────────────────────────────

/// Auditoría de cierres de caja multi-sucursal para super_admin.
/// Solo lectura: no muestra botón "REABRIR". Para ese flujo existe la
/// pantalla de detalle del admin (AdminCierreDetalleScreen), que sí lo tiene,
/// pero super_admin no llega a ella desde aquí (decisión 5B — solo lectura).
class SuperCierresCajaScreen extends StatefulWidget {
  const SuperCierresCajaScreen({super.key});

  @override
  State<SuperCierresCajaScreen> createState() => _SuperCierresCajaScreenState();
}

class _SuperCierresCajaScreenState extends State<SuperCierresCajaScreen> {
  // ── Filtros ───────────────────────────────────────────────────────────────
  Restaurante? _sucursal; // null → todas
  DateTime _fecha = DateTime.now();

  // ── Datos ─────────────────────────────────────────────────────────────────
  List<Restaurante> _sucursales = [];
  List<Map<String, dynamic>> _cierres = [];
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

  // ── Carga de cierres ──────────────────────────────────────────────────────

  Future<void> _cargar() async {
    if (!mounted) return;
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final lista = await CierreCajaService.listar(
        fecha: _fechaStr,
        restauranteId: _sucursal?.id,
      );
      if (!mounted) return;
      setState(() {
        _cierres = lista;
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

  String get _fechaStr {
    final f = _fecha;
    return '${f.year.toString().padLeft(4, '0')}-'
        '${f.month.toString().padLeft(2, '0')}-'
        '${f.day.toString().padLeft(2, '0')}';
  }

  // ── Selector de fecha ─────────────────────────────────────────────────────

  Future<void> _seleccionarFecha() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _fecha,
      firstDate: DateTime(2023),
      lastDate: DateTime.now(),
      helpText: 'SELECCIONAR FECHA',
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
    if (picked == null || !mounted) return;
    setState(() => _fecha = picked);
    _cargar();
  }

  // ── Bottom sheet selector de sucursal ────────────────────────────────────
  // Patrón copiado de contabilidad_screen para mantener independencia entre roles.

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

  // ── Ir al detalle (solo lectura via AdminCierreDetalleScreen) ─────────────
  // Decisión: AdminCierreDetalleScreen ya muestra el botón "REABRIR" solo cuando
  // estado == 'cerrado'. El super_admin accede a ella en modo solo lectura porque
  // no tiene permisos backend para reabrir; si lo intenta el backend lo rechazará.
  // No creamos super_cierre_detalle_screen.dart independiente porque la lógica de
  // carga es idéntica y el control de acceso lo ejerce el backend, no el frontend.

  void _irDetalle(Map<String, dynamic> cierre) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            AdminCierreDetalleScreen(cierreId: cierre['id'] as String),
      ),
    ).then((_) => _cargar());
  }

  // ── BUILD ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text(
          'CIERRES DE CAJA',
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
        actions: [
          Semantics(
            label: 'Refrescar cierres',
            button: true,
            child: IconButton(
              icon: const Icon(Icons.refresh, color: Colors.white),
              tooltip: 'Refrescar',
              onPressed: _cargando ? null : _cargar,
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/images/Bravo restaurante.jpg'),
                fit: BoxFit.cover,
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.65),
                  Colors.black.withValues(alpha: 0.92),
                ],
              ),
            ),
          ),
          SafeArea(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    return RefreshIndicator(
      color: AppColors.primaryOnDark,
      backgroundColor: Colors.black87,
      onRefresh: _cargar,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Selector de sucursal
            _buildSelectorSucursal(),
            const SizedBox(height: 12),
            // Selector de fecha
            _buildSelectorFecha(),
            const SizedBox(height: 20),

            if (_cargando)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 60),
                child: Center(
                  child: CircularProgressIndicator(color: AppColors.primaryOnDark),
                ),
              )
            else if (_error != null)
              _buildError()
            else if (_cierres.isEmpty)
              _buildVacio()
            else
              ..._cierres.map(
                (c) => Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: _CierreCard(
                    cierre: c,
                    onTap: () => _irDetalle(c),
                  ),
                ),
              ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectorSucursal() {
    final label = _sucursal?.nombre ?? 'Todas las sucursales';
    return Semantics(
      label: 'Sucursal: $label',
      button: true,
      child: GestureDetector(
        onTap: _abrirSelectorSucursal,
        child: _GlassCard(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          child: Row(
            children: [
              const Icon(Icons.storefront_outlined,
                  color: AppColors.detailOnDark, size: 18),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'SUCURSAL',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: Colors.white54,
                        letterSpacing: 1.4,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      label,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_drop_down, color: Colors.white54, size: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSelectorFecha() {
    return Semantics(
      label: 'Fecha: ${_fmtFecha.format(_fecha)}',
      button: true,
      child: GestureDetector(
        onTap: _seleccionarFecha,
        child: _GlassCard(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          child: Row(
            children: [
              const Icon(Icons.calendar_today,
                  color: AppColors.detailOnDark, size: 18),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'FECHA',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: Colors.white54,
                      letterSpacing: 1.4,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _fmtFecha.format(_fecha),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              const Icon(Icons.arrow_drop_down, color: Colors.white54, size: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildError() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Center(
        child: Column(
          children: [
            const Icon(Icons.error_outline, color: AppColors.error, size: 48),
            const SizedBox(height: 12),
            const Text(
              'No se pudieron cargar los cierres',
              style: TextStyle(color: Colors.white),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              _error!,
              style: const TextStyle(color: Colors.white54, fontSize: 12),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _cargar,
              icon: const Icon(Icons.refresh),
              label: const Text('Reintentar'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryAccent,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVacio() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 60),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.point_of_sale_outlined,
                color: Colors.white24, size: 64),
            SizedBox(height: 16),
            Text(
              'No hay cierres para los filtros seleccionados.',
              style: TextStyle(color: Colors.white54, fontSize: 15),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Card de un cierre ─────────────────────────────────────────────────────────

class _CierreCard extends StatelessWidget {
  final Map<String, dynamic> cierre;
  final VoidCallback onTap;

  const _CierreCard({required this.cierre, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final turno = cierre['turno'] as String? ?? '—';
    final estado = cierre['estado'] as String?;
    final abiertaAt = _parseFecha(cierre['abierto_at']);
    final cerradaAt = _parseFecha(cierre['cerrado_at']);
    final totales = cierre['totales'] as Map<String, dynamic>? ?? {};
    final ventasTotal =
        (totales['ventas_total'] as num?)?.toDouble() ?? 0.0;
    final descuadre = (cierre['descuadre'] as num?)?.toDouble() ?? 0.0;
    // El nombre de la sucursal puede venir en varios campos según el backend
    final sucursal = cierre['restaurante_nombre'] as String? ??
        cierre['nombre_sucursal'] as String? ??
        '';

    Color colorDescuadre;
    if (descuadre == 0) {
      colorDescuadre = AppColors.disp;
    } else if (descuadre.abs() <= 5) {
      colorDescuadre = AppColors.warning;
    } else {
      colorDescuadre = AppColors.error;
    }

    return _GlassCard(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        splashColor: AppColors.primaryOnDark.withValues(alpha: 0.12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cabecera: turno + estado + sucursal
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: AppColors.detailOnDark.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppColors.detailOnDark.withValues(alpha: 0.5),
                    ),
                  ),
                  child: Icon(_iconoTurno(turno),
                      color: AppColors.detailOnDark, size: 18),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _labelTurno(turno),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (sucursal.isNotEmpty)
                        Text(
                          sucursal,
                          style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 12,
                          ),
                        ),
                    ],
                  ),
                ),
                _chipEstado(estado),
              ],
            ),

            const SizedBox(height: 12),
            const Divider(color: Colors.white12, height: 1),
            const SizedBox(height: 12),

            // Datos: horarios + totales
            Row(
              children: [
                // Apertura
                Expanded(
                  child: _FilaDato(
                    icono: Icons.play_arrow_rounded,
                    label: 'Apertura',
                    valor: abiertaAt != null
                        ? _fmtHora.format(abiertaAt)
                        : '—',
                  ),
                ),
                // Cierre
                Expanded(
                  child: _FilaDato(
                    icono: Icons.lock_outline,
                    label: 'Cierre',
                    valor:
                        cerradaAt != null ? _fmtHora.format(cerradaAt) : '—',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _FilaDato(
                    icono: Icons.euro_outlined,
                    label: 'Ingresos',
                    valor: '${_fmtEuros.format(ventasTotal)} €',
                  ),
                ),
                Expanded(
                  child: _FilaDato(
                    icono: Icons.balance_outlined,
                    label: 'Descuadre',
                    valor: '${_fmtEuros.format(descuadre)} €',
                    valorColor: colorDescuadre,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),
            const Align(
              alignment: Alignment.centerRight,
              child: Text(
                'VER DETALLE →',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: AppColors.linkOnDark,
                  letterSpacing: 1.2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chipEstado(String? estado) {
    final Color color;
    final String label;
    if (estado == 'abierto') {
      color = AppColors.disp;
      label = 'ABIERTO';
    } else if (estado == 'cerrado') {
      color = AppColors.info;
      label = 'CERRADO';
    } else {
      color = Colors.white38;
      label = 'SIN ABRIR';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.6)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

// ── Fila de dato ──────────────────────────────────────────────────────────────

class _FilaDato extends StatelessWidget {
  final IconData icono;
  final String label;
  final String valor;
  final Color? valorColor;

  const _FilaDato({
    required this.icono,
    required this.label,
    required this.valor,
    this.valorColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icono, size: 13, color: Colors.white38),
        const SizedBox(width: 4),
        Text(
          '$label: ',
          style: const TextStyle(color: Colors.white38, fontSize: 11),
        ),
        Flexible(
          child: Text(
            valor,
            style: TextStyle(
              color: valorColor ?? Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

// ── Bottom sheet selector de sucursal ────────────────────────────────────────
// Copiado de contabilidad_screen para mantener independencia entre roles.

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
        color: AppColors.backgroundDark,
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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  children: [
                    // Opción "Todas"
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      onTap: onTap,
    );
  }
}

// ── Contenedor glass ──────────────────────────────────────────────────────────

class _GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const _GlassCard({
    required this.child,
    this.padding = const EdgeInsets.all(16),
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          width: double.infinity,
          padding: padding,
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.40),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
          ),
          child: child,
        ),
      ),
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

String _labelTurno(String t) => switch (t) {
      'desayuno' => 'Desayuno',
      'comida' => 'Comida',
      'cena' => 'Cena',
      _ => t,
    };

IconData _iconoTurno(String t) => switch (t) {
      'desayuno' => Icons.wb_sunny_outlined,
      'comida' => Icons.restaurant_outlined,
      'cena' => Icons.nights_stay_outlined,
      _ => Icons.schedule,
    };

DateTime? _parseFecha(dynamic raw) {
  if (raw == null) return null;
  try {
    return DateTime.parse(raw.toString()).toLocal();
  } catch (_) {
    return null;
  }
}

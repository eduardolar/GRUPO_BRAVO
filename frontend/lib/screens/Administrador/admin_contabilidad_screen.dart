import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../components/admin/admin_max_width.dart';
import '../../core/colors_style.dart';
import '../../providers/auth_provider.dart';
import '../../services/download_helper.dart';
import '../../services/http_client.dart';
import '../../services/pedido_service.dart';

// ─── Constantes de diseño ────────────────────────────────────────────────────

/// Color granate translúcido usado en el área bajo la línea del sparkline.
const _kGranateArea = Color(0x33800020);

/// Altura fija del gráfico de ventas diarias.
const _kChartHeight = 140.0;

// ─── Chips de rango rápido ───────────────────────────────────────────────────

enum _RangoRapido { hoy, semana, mes, ultimos30, personalizado }

extension _RangoRapidoLabel on _RangoRapido {
  String get label => switch (this) {
        _RangoRapido.hoy => 'Hoy',
        _RangoRapido.semana => 'Esta semana',
        _RangoRapido.mes => 'Mes actual',
        _RangoRapido.ultimos30 => 'Últimos 30d',
        _RangoRapido.personalizado => 'Personalizado',
      };
}

// ─── Screen ───────────────────────────────────────────────────────────────────

class AdminContabilidadScreen extends StatefulWidget {
  const AdminContabilidadScreen({super.key});

  @override
  State<AdminContabilidadScreen> createState() =>
      _AdminContabilidadScreenState();
}

class _AdminContabilidadScreenState extends State<AdminContabilidadScreen> {
  DateTime _fechaInicio = DateTime.now().subtract(const Duration(days: 30));
  DateTime _fechaFin = DateTime.now();

  _RangoRapido _rangoActivo = _RangoRapido.ultimos30;

  final DateFormat _dateFormat = DateFormat('dd/MM/yyyy');

  // Estado de la carga principal
  bool _cargando = false;
  String? _error;
  Map<String, dynamic>? _resumen;

  // Estado del export CSV
  bool _exportandoCsv = false;

  @override
  void initState() {
    super.initState();
    // Cargamos tras el primer frame para tener el contexto de Provider listo.
    WidgetsBinding.instance.addPostFrameCallback((_) => _cargarResumen());
  }

  // ── Carga principal ──────────────────────────────────────────────────────────

  Future<void> _cargarResumen() async {
    if (!mounted) return;
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final restauranteId =
          context.read<AuthProvider>().usuarioActual?.restauranteId;
      final data = await PedidoService.obtenerResumenContabilidad(
        fechaDesde: _fechaInicio,
        fechaHasta: _fechaFin,
        restauranteId: restauranteId,
      );
      if (!mounted) return;
      setState(() {
        _resumen = data;
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

  // ── Selector de rango rápido ─────────────────────────────────────────────────

  void _aplicarRangoRapido(_RangoRapido rango) {
    final ahora = DateTime.now();
    DateTime inicio;
    final DateTime fin = ahora;

    switch (rango) {
      case _RangoRapido.hoy:
        inicio = DateTime(ahora.year, ahora.month, ahora.day);
      case _RangoRapido.semana:
        // Lunes de la semana actual (weekday: 1=lunes … 7=domingo)
        inicio = ahora.subtract(Duration(days: ahora.weekday - 1));
        inicio = DateTime(inicio.year, inicio.month, inicio.day);
      case _RangoRapido.mes:
        inicio = DateTime(ahora.year, ahora.month, 1);
      case _RangoRapido.ultimos30:
        inicio = ahora.subtract(const Duration(days: 30));
      case _RangoRapido.personalizado:
        // Solo activa el chip; los date pickers conservan las fechas actuales.
        setState(() => _rangoActivo = rango);
        return;
    }

    setState(() {
      _rangoActivo = rango;
      _fechaInicio = inicio;
      _fechaFin = fin;
    });
    _cargarResumen();
  }

  // ── Date pickers ─────────────────────────────────────────────────────────────

  Future<void> _seleccionarFecha(bool esInicio) async {
    final picked = await showDatePicker(
      context: context,
      helpText: esInicio ? 'FECHA DE INICIO' : 'FECHA DE FIN',
      initialDate: esInicio ? _fechaInicio : _fechaFin,
      firstDate: DateTime(2023),
      lastDate: DateTime.now(),
      builder: (ctx, child) => _pickerTheme(ctx, child!),
    );
    if (picked == null || !mounted) return;
    setState(() {
      if (esInicio) {
        _fechaInicio = picked;
        if (_fechaInicio.isAfter(_fechaFin)) _fechaFin = _fechaInicio;
      } else {
        _fechaFin = picked;
        if (_fechaFin.isBefore(_fechaInicio)) _fechaInicio = _fechaFin;
      }
      _rangoActivo = _RangoRapido.personalizado;
    });
    _cargarResumen();
  }

  Widget _pickerTheme(BuildContext ctx, Widget child) {
    return Theme(
      data: Theme.of(ctx).copyWith(
        colorScheme: const ColorScheme.light(
          primary: AppColors.primary,
          onPrimary: Colors.white,
          onSurface: AppColors.textPrimary,
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(foregroundColor: AppColors.primary),
        ),
      ),
      child: child,
    );
  }

  // ── Export CSV ───────────────────────────────────────────────────────────────

  Future<void> _exportarCsv() async {
    // Validación cliente: más de 90 días → snackbar rojo sin llamar al backend.
    final dias = _fechaFin.difference(_fechaInicio).inDays;
    if (dias > 90) {
      _snack('Reduce el rango a 90 días para exportar', color: AppColors.error);
      return;
    }

    setState(() => _exportandoCsv = true);
    try {
      final restauranteId =
          context.read<AuthProvider>().usuarioActual?.restauranteId;
      final bytes = await PedidoService.exportarContabilidadCsv(
        fechaDesde: _fechaInicio,
        fechaHasta: _fechaFin,
        restauranteId: restauranteId,
      );

      if (!mounted) return;

      final nombre =
          'ventas_'
          '${_fechaInicio.toIso8601String().substring(0, 10)}_'
          '${_fechaFin.toIso8601String().substring(0, 10)}.csv';

      // descargarBytes está implementado de forma diferente en web (dart:html)
      // y en móvil/desktop (dart:io), gracias al conditional export.
      final ruta = await descargarBytes(bytes, nombre);
      if (!mounted) return;
      _snack('CSV guardado: $ruta', color: AppColors.disp);
    } on ApiException catch (e) {
      if (!mounted) return;
      // 400 si el backend rechaza el rango (salvaguarda adicional).
      _snack(e.message, color: AppColors.error);
    } catch (e) {
      if (!mounted) return;
      _snack('Error al exportar: $e', color: AppColors.error);
    } finally {
      if (mounted) setState(() => _exportandoCsv = false);
    }
  }

  // ── Export PDF (stub: el backend devuelve 501) ────────────────────────────────

  void _mostrarMensajePdf() {
    _snack(
      'PDF no disponible aún. Pide al equipo técnico instalar la librería reportlab.',
      color: AppColors.warningText,
    );
  }

  // ── Snackbar helper ──────────────────────────────────────────────────────────

  void _snack(String msg, {Color color = Colors.white}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(color: Colors.white)),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text(
          'CONTABILIDAD Y VENTAS',
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
            label: 'Refrescar datos',
            button: true,
            child: IconButton(
              tooltip: 'Refrescar',
              onPressed: _cargando ? null : _cargarResumen,
              icon: const Icon(Icons.refresh, color: Colors.white),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          // Fondo: foto del restaurante
          Container(
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/images/Bravo restaurante.jpg'),
                fit: BoxFit.cover,
              ),
            ),
          ),
          // Capa oscura degradada
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.7),
                  Colors.black.withValues(alpha: 0.92),
                ],
              ),
            ),
          ),
          SafeArea(child: AdminMaxWidth(child: _buildContenido())),
        ],
      ),
    );
  }

  Widget _buildContenido() {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Selector de fechas
          _buildFilterCard(),
          const SizedBox(height: 10),

          // 2. Chips de rango rápido
          _buildChipsRango(),
          const SizedBox(height: 16),

          // Estados: cargando / error / datos
          if (_cargando) _buildLoading(),
          if (!_cargando && _error != null) _buildError(),
          if (!_cargando && _error == null && _resumen != null) ...[
            // 3. KPIs
            _buildKpis(_resumen!),
            const SizedBox(height: 20),

            // 4. Gráfico de ventas diarias
            _buildGraficoVentas(_resumen!),
            const SizedBox(height: 20),

            // 5. Top productos
            _buildTopProductos(_resumen!),
            const SizedBox(height: 20),

            // 6. Método de pago
            _buildMetodoPago(_resumen!),
            const SizedBox(height: 20),

            // 7. Tipo de entrega
            _buildTipoEntrega(_resumen!),
            const SizedBox(height: 24),
          ],

          // 8. Botones de export (siempre visibles)
          _buildBotonesExport(),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  // ── Estado: cargando ──────────────────────────────────────────────────────────

  Widget _buildLoading() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 60),
      child: Center(
        child: CircularProgressIndicator(color: AppColors.primaryOnDark),
      ),
    );
  }

  // ── Estado: error ─────────────────────────────────────────────────────────────

  Widget _buildError() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Center(
        child: Column(
          children: [
            const Icon(Icons.error_outline, color: AppColors.error, size: 48),
            const SizedBox(height: 12),
            const Text(
              'No se pudo cargar el resumen',
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
              onPressed: _cargarResumen,
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

  // ── 1. Filter card ────────────────────────────────────────────────────────────

  Widget _buildFilterCard() {
    return _GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'FILTRAR POR FECHAS',
            style: TextStyle(
              fontSize: 12,
              color: Colors.white54,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildDateButton('Desde', _fechaInicio, true),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 10),
                child: Icon(
                  Icons.arrow_forward_ios,
                  color: Colors.white38,
                  size: 14,
                ),
              ),
              Expanded(
                child: _buildDateButton('Hasta', _fechaFin, false),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDateButton(String label, DateTime fecha, bool esInicio) {
    // Los date pickers solo son interactivos en modo "Personalizado".
    final activo = _rangoActivo == _RangoRapido.personalizado;
    return Semantics(
      label: '$label: ${_dateFormat.format(fecha)}',
      button: true,
      child: GestureDetector(
        onTap: activo ? () => _seleccionarFecha(esInicio) : null,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
          decoration: BoxDecoration(
            // Negro translúcido en vez de blanco: sobre la imagen Bravo
            // (papel beige) el blanco se diluía y dejaba el texto invisible.
            color: Colors.black.withValues(alpha: activo ? 0.55 : 0.4),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: activo
                  ? AppColors.detailOnDark.withValues(alpha: 0.6)
                  : Colors.white24,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: activo ? Colors.white70 : Colors.white38,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(
                    Icons.calendar_today,
                    size: 13,
                    color: activo ? AppColors.detailOnDark : Colors.white38,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _dateFormat.format(fecha),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: activo ? Colors.white : Colors.white54,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── 2. Chips de rango rápido ──────────────────────────────────────────────────

  Widget _buildChipsRango() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: _RangoRapido.values.map((r) {
          final activo = _rangoActivo == r;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Semantics(
              label: r.label,
              button: true,
              selected: activo,
              child: FilterChip(
                label: Text(
                  r.label,
                  style: TextStyle(
                    fontSize: 12,
                    color: activo ? Colors.white : Colors.white70,
                    fontWeight:
                        activo ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                selected: activo,
                onSelected: (_) => _aplicarRangoRapido(r),
                // Fondo oscuro para que el chip se distinga sobre la imagen
                // Bravo de fondo y el texto blanco quede legible.
                backgroundColor: Colors.black.withValues(alpha: 0.55),
                selectedColor: AppColors.primaryAccent,
                checkmarkColor: Colors.white,
                side: BorderSide(
                  color: activo
                      ? AppColors.primaryAccent
                      : Colors.white.withValues(alpha: 0.25),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ── 3. KPIs ───────────────────────────────────────────────────────────────────

  Widget _buildKpis(Map<String, dynamic> resumen) {
    final t = resumen['totales'] as Map<String, dynamic>? ?? {};
    final ingresos = (t['ingresos'] as num?)?.toDouble() ?? 0.0;
    final pedidos = (t['pedidos'] as num?)?.toInt() ?? 0;
    final ticket = (t['ticket_medio'] as num?)?.toDouble() ?? 0.0;
    final items = (t['items_vendidos'] as num?)?.toInt() ?? 0;

    final fmt = NumberFormat('#,##0.00', 'es_ES');

    final tarjetas = [
      _KpiDato(
        icon: Icons.euro_outlined,
        label: 'INGRESOS',
        value: '${fmt.format(ingresos)} €',
        accent: AppColors.disp,
      ),
      _KpiDato(
        icon: Icons.receipt_long_outlined,
        label: 'PEDIDOS',
        value: '$pedidos',
        accent: AppColors.info,
      ),
      _KpiDato(
        icon: Icons.analytics_outlined,
        label: 'TICKET MEDIO',
        value: '${fmt.format(ticket)} €',
        accent: AppColors.warningLight,
      ),
      _KpiDato(
        icon: Icons.shopping_bag_outlined,
        label: 'ITEMS VENDIDOS',
        value: '$items',
        accent: AppColors.primaryAccent,
      ),
    ];

    return LayoutBuilder(
      builder: (ctx, constraints) {
        if (constraints.maxWidth < 600) {
          // Móvil: grid 2 columnas
          return GridView.count(
            crossAxisCount: 2,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 1.6,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: tarjetas.map(_buildKpiCard).toList(),
          );
        }
        // Tablet / desktop: fila horizontal
        return Row(
          children: tarjetas.map((d) {
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.only(right: 10),
                child: _buildKpiCard(d),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildKpiCard(_KpiDato d) {
    return Semantics(
      label: '${d.label}: ${d.value}',
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(d.icon, size: 13, color: d.accent),
                    const SizedBox(width: 5),
                    Flexible(
                      child: Text(
                        d.label,
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
                  d.value,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    height: 1.1,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── 4. Gráfico de ventas diarias ──────────────────────────────────────────────

  Widget _buildGraficoVentas(Map<String, dynamic> resumen) {
    final porDia = (resumen['por_dia'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>();

    return _buildSeccion(
      titulo: 'VENTAS DIARIAS',
      child: porDia.length <= 1
          ? const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Text(
                  'Datos insuficientes para el gráfico',
                  style: TextStyle(color: Colors.white54),
                ),
              ),
            )
          : _GlassCard(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
              child: SizedBox(
                height: _kChartHeight,
                child: _SparklineChart(datos: porDia),
              ),
            ),
    );
  }

  // ── 5. Top productos ──────────────────────────────────────────────────────────

  Widget _buildTopProductos(Map<String, dynamic> resumen) {
    final top = (resumen['top_productos'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>();

    if (top.isEmpty) return const SizedBox.shrink();

    final maxUnidades = top
        .map((p) => (p['unidades'] as num?)?.toInt() ?? 0)
        .fold(0, (a, b) => a > b ? a : b);

    return _buildSeccion(
      titulo: 'TOP PRODUCTOS',
      child: _GlassCard(
        child: Column(
          children: top.map((p) {
            final nombre = p['nombre'] as String? ?? '—';
            final unidades = (p['unidades'] as num?)?.toInt() ?? 0;
            final ratio =
                maxUnidades > 0 ? unidades / maxUnidades : 0.0;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          nombre,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '$unidades uds',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: ratio,
                      minHeight: 5,
                      backgroundColor: Colors.white12,
                      color: AppColors.primaryOnDark,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  // ── 6. Método de pago ─────────────────────────────────────────────────────────

  Widget _buildMetodoPago(Map<String, dynamic> resumen) {
    final metodos = (resumen['por_metodo_pago'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>();

    if (metodos.isEmpty) return const SizedBox.shrink();

    final fmt = NumberFormat('#,##0.00', 'es_ES');

    return _buildSeccion(
      titulo: 'MÉTODO DE PAGO',
      child: LayoutBuilder(
        builder: (ctx, constraints) {
          // Ancho de cada mini-card: máximo 3 por fila en pantallas anchas.
          final cardWidth = constraints.maxWidth < 400
              ? (constraints.maxWidth - 10) / 2
              : (constraints.maxWidth - 20) / 3;

          return Wrap(
            spacing: 10,
            runSpacing: 10,
            children: metodos.map((m) {
              final metodo = m['metodo'] as String? ?? '—';
              final pct = (m['porcentaje'] as num?)?.toDouble() ?? 0.0;
              final ing = (m['ingresos'] as num?)?.toDouble() ?? 0.0;
              final color = _colorMetodo(metodo);
              return SizedBox(
                width: cardWidth.clamp(80.0, 220.0),
                child: _GlassCard(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(_iconoMetodo(metodo), color: color, size: 15),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              metodo,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${pct.toStringAsFixed(1)} %',
                        style: TextStyle(
                          color: color,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        '${fmt.format(ing)} €',
                        style: const TextStyle(
                          color: Colors.white60,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          );
        },
      ),
    );
  }

  Color _colorMetodo(String metodo) {
    final m = metodo.toLowerCase();
    if (m.contains('tarjeta') || m.contains('card')) {
      return AppColors.info;
    }
    if (m.contains('paypal')) return AppColors.paypal;
    if (m.contains('efectivo') || m.contains('cash')) return AppColors.disp;
    return AppColors.warningLight;
  }

  IconData _iconoMetodo(String metodo) {
    final m = metodo.toLowerCase();
    if (m.contains('tarjeta') || m.contains('card')) return Icons.credit_card;
    if (m.contains('paypal')) return Icons.account_balance_wallet;
    if (m.contains('efectivo') || m.contains('cash')) return Icons.payments;
    return Icons.payment;
  }

  // ── 7. Tipo de entrega ────────────────────────────────────────────────────────

  Widget _buildTipoEntrega(Map<String, dynamic> resumen) {
    final tipos = (resumen['por_tipo_entrega'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>();

    if (tipos.isEmpty) return const SizedBox.shrink();

    return _buildSeccion(
      titulo: 'TIPO DE ENTREGA',
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: tipos.map((t) {
          final tipo = t['tipo'] as String? ?? '—';
          final peds = (t['pedidos'] as num?)?.toInt() ?? 0;
          return Chip(
            avatar: Icon(_iconoEntrega(tipo), size: 14, color: Colors.white),
            label: Text(
              '$tipo · $peds',
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
            // Fondo oscuro: el blanco translúcido se confundía con la
            // imagen Bravo (papel claro) y dejaba el chip invisible.
            backgroundColor: Colors.black.withValues(alpha: 0.55),
            side: BorderSide(color: Colors.white.withValues(alpha: 0.25)),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
          );
        }).toList(),
      ),
    );
  }

  IconData _iconoEntrega(String tipo) {
    final t = tipo.toLowerCase();
    if (t.contains('mesa') || t.contains('local')) {
      return Icons.table_restaurant;
    }
    if (t.contains('domicilio') || t.contains('delivery')) {
      return Icons.delivery_dining;
    }
    if (t.contains('recog') || t.contains('takeaway')) {
      return Icons.shopping_bag;
    }
    return Icons.fastfood;
  }

  // ── 8. Botones de export ──────────────────────────────────────────────────────

  Widget _buildBotonesExport() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // CSV: botón granate sólido
        Semantics(
          label: 'Exportar ventas en formato CSV',
          button: true,
          child: ElevatedButton.icon(
            onPressed: _exportandoCsv ? null : _exportarCsv,
            icon: _exportandoCsv
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.download_outlined, size: 18),
            label: Text(
              _exportandoCsv ? 'EXPORTANDO...' : 'EXPORTAR CSV',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryAccent,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        // PDF: outline gris, no llama al backend (stub local)
        Semantics(
          label: 'Exportar PDF (no disponible)',
          button: true,
          child: OutlinedButton.icon(
            onPressed: _mostrarMensajePdf,
            icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
            label: const Text(
              'EXPORTAR PDF',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white54,
              minimumSize: const Size(double.infinity, 48),
              side: const BorderSide(color: Colors.white24),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── Helper: encabezado de sección ─────────────────────────────────────────────

  Widget _buildSeccion({required String titulo, required Widget child}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(width: 3, height: 14, color: AppColors.detailOnDark),
            const SizedBox(width: 8),
            Text(
              titulo,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: Colors.white70,
                letterSpacing: 1.8,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        child,
      ],
    );
  }
}

// ─── _GlassCard ───────────────────────────────────────────────────────────────

/// Tarjeta glass coherente con admin_home_screen y admin_stock_screen.
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

// ─── _KpiDato ─────────────────────────────────────────────────────────────────

class _KpiDato {
  final IconData icon;
  final String label;
  final String value;
  final Color accent;

  const _KpiDato({
    required this.icon,
    required this.label,
    required this.value,
    required this.accent,
  });
}

// ─── _SparklineChart ──────────────────────────────────────────────────────────

/// Sparkline de línea + área degradada sin dependencias externas.
/// Recibe [datos] de la forma [{fecha, ingresos, pedidos}, ...].
class _SparklineChart extends StatelessWidget {
  final List<Map<String, dynamic>> datos;

  const _SparklineChart({required this.datos});

  @override
  Widget build(BuildContext context) {
    final values = datos
        .map((d) => (d['ingresos'] as num?)?.toDouble() ?? 0.0)
        .toList();

    // Etiqueta abreviada: "MM/DD" a partir de "YYYY-MM-DD"
    final labels = datos.map((d) {
      final f = d['fecha'] as String? ?? '';
      if (f.length >= 10) return f.substring(5).replaceFirst('-', '/');
      return f;
    }).toList();

    return CustomPaint(
      painter: _SparklinePainter(values: values, labels: labels),
      child: const SizedBox.expand(),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  final List<double> values;
  final List<String> labels;

  const _SparklinePainter({required this.values, required this.labels});

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;

    const labelH = 18.0;
    const padH = 8.0;
    final chartH = size.height - labelH;
    final chartW = size.width - padH * 2;
    final n = values.length;

    final maxVal = values.fold(0.0, (a, b) => a > b ? a : b);
    // Evita división por cero cuando todos los ingresos son 0.
    final scale = maxVal > 0 ? chartH * 0.85 / maxVal : 1.0;

    // Coordenadas de cada punto
    final puntos = List<Offset>.generate(n, (i) {
      final x = padH + (n == 1 ? chartW / 2 : chartW * i / (n - 1));
      final y = chartH - (values[i] * scale);
      return Offset(x, y);
    });

    // Área bajo la línea: degradado granate translúcido
    final pathArea = Path()..moveTo(puntos.first.dx, chartH);
    for (final p in puntos) {
      pathArea.lineTo(p.dx, p.dy);
    }
    pathArea
      ..lineTo(puntos.last.dx, chartH)
      ..close();

    canvas.drawPath(
      pathArea,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [_kGranateArea, Color(0x00800020)],
        ).createShader(Rect.fromLTWH(0, 0, size.width, chartH)),
    );

    // Línea principal granate
    final pathLine = Path()..moveTo(puntos.first.dx, puntos.first.dy);
    for (int i = 1; i < n; i++) {
      pathLine.lineTo(puntos[i].dx, puntos[i].dy);
    }
    canvas.drawPath(
      pathLine,
      Paint()
        ..color = AppColors.primaryOnDark
        ..strokeWidth = 2.0
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    // Punto blanco en el último valor
    canvas.drawCircle(
      puntos.last,
      3.5,
      Paint()..color = Colors.white,
    );
    canvas.drawCircle(
      puntos.last,
      3.5,
      Paint()
        ..color = AppColors.primaryOnDark
        ..strokeWidth = 1.5
        ..style = PaintingStyle.stroke,
    );

    // Etiquetas en eje X cada ~n/5 puntos para no saturar
    final step = ((n / 5).ceil()).clamp(1, n);
    const labelStyle = TextStyle(color: Colors.white54, fontSize: 9);

    void pintarLabel(int i) {
      if (i >= labels.length) return;
      final tp = TextPainter(
        text: TextSpan(text: labels[i], style: labelStyle),
        textDirection: ui.TextDirection.ltr,
      )..layout(maxWidth: 50);
      final x = (puntos[i].dx - tp.width / 2).clamp(0.0, size.width - tp.width);
      tp.paint(canvas, Offset(x, chartH + 2));
    }

    for (int i = 0; i < n; i += step) {
      pintarLabel(i);
    }
    // Siempre muestra la etiqueta del último punto
    if ((n - 1) % step != 0) pintarLabel(n - 1);
  }

  @override
  bool shouldRepaint(_SparklinePainter old) =>
      old.values != values || old.labels != labels;
}

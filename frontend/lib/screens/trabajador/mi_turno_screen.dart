import 'package:flutter/material.dart';
import 'package:frontend/core/app_routes.dart';
import 'package:frontend/core/colors_style.dart';
import 'package:frontend/screens/trabajador/appbar_trabajador.dart';
import 'package:frontend/services/pedido_service.dart';

class MiTurnoScreen extends StatefulWidget {
  const MiTurnoScreen({super.key});

  @override
  State<MiTurnoScreen> createState() => _MiTurnoScreenState();
}

class _MiTurnoScreenState extends State<MiTurnoScreen> {
  Map<String, dynamic>? _stats;
  bool _cargando = true;
  String? _error;
  // Rango en horario local del dispositivo. Al consultar al backend se
  // envían convertidos a UTC (ver _cargar). Por defecto: hoy 00:00 local
  // hasta el momento actual.
  late DateTime _desde;
  late DateTime _hasta;
  // Indica si el rango es el "modo turno actual" (hasta = ahora) — en ese
  // caso refrescamos `_hasta` automáticamente en cada `_cargar` para que
  // las cifras incluyan los pedidos recientes sin reabrir la pantalla.
  bool _modoTurnoActual = true;

  @override
  void initState() {
    super.initState();
    final ahora = DateTime.now();
    _desde = DateTime(ahora.year, ahora.month, ahora.day);
    _hasta = ahora;
    _cargar();
  }

  Future<void> _cargar() async {
    if (_modoTurnoActual) {
      _hasta = DateTime.now();
    }
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final data = await PedidoService.obtenerMiTurno(
        desde: _desde,
        hasta: _hasta,
      );
      if (!mounted) return;
      setState(() {
        _stats = data;
        _cargando = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _cargando = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  /// Selector de fecha para cambiar el inicio del turno.
  /// Útil para revisar KPIs de días pasados (cierre, ajustes contables).
  Future<void> _seleccionarRango() async {
    final ahora = DateTime.now();
    final rango = await showDateRangePicker(
      context: context,
      firstDate: DateTime(ahora.year - 1),
      lastDate: ahora,
      initialDateRange: DateTimeRange(
        start: _desde,
        end: DateTime(_hasta.year, _hasta.month, _hasta.day),
      ),
      helpText: 'Rango del turno',
      saveText: 'APLICAR',
    );
    if (rango == null || !mounted) return;
    setState(() {
      _desde = DateTime(rango.start.year, rango.start.month, rango.start.day);
      // El fin del día seleccionado: 23:59:59.999. Si el usuario escoge
      // hoy como `end`, mantenemos el modo "turno actual" para que el
      // refresh siga avanzando hasta DateTime.now().
      final hoyMidnight = DateTime(ahora.year, ahora.month, ahora.day);
      final endMidnight = DateTime(rango.end.year, rango.end.month, rango.end.day);
      if (endMidnight.isAtSameMomentAs(hoyMidnight)) {
        _modoTurnoActual = true;
        _hasta = ahora;
      } else {
        _modoTurnoActual = false;
        _hasta = DateTime(
          rango.end.year, rango.end.month, rango.end.day, 23, 59, 59, 999,
        );
      }
    });
    _cargar();
  }

  String _formatoEuros(num? v) {
    if (v == null) return '0,00 €';
    return '${v.toStringAsFixed(2).replaceAll('.', ',')} €';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: const TrabajadorAppBar(title: 'MI TURNO'),
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
                Colors.black.withValues(alpha: 0.85),
              ],
            ),
          ),
          child: SafeArea(
            child: FadeSlideIn(
              child: _cargando
                  ? const Center(
                      child: CircularProgressIndicator(color: AppColors.button),
                    )
                  : _error != null
                  ? _buildError()
                  : RefreshIndicator(
                      onRefresh: _cargar,
                      color: AppColors.button,
                      backgroundColor: Colors.black87,
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(
                          16,
                          kToolbarHeight + 12,
                          16,
                          32,
                        ),
                  children: [
                    _buildRangoFechas(),
                    const SizedBox(height: 16),
                    _buildKpiPrincipal(
                      label: 'Total cobrado',
                      valor: _formatoEuros(_stats?['totalCobrado']),
                      icono: Icons.euro,
                      colorFondo: AppColors.button,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildKpiCard(
                            label: 'Pedidos\ncobrados',
                            valor: '${_stats?['pedidosCobrados'] ?? 0}',
                            icono: Icons.receipt_long_outlined,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildKpiCard(
                            label: 'Mesas\natendidas',
                            valor: '${_stats?['mesasAtendidas'] ?? 0}',
                            icono: Icons.table_restaurant_outlined,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildKpiCard(
                            label: 'Propinas',
                            valor: _formatoEuros(_stats?['totalPropinas']),
                            icono: Icons.savings_outlined,
                            color: AppColors.disp,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildKpiCard(
                            label: 'Descuentos',
                            valor: _formatoEuros(_stats?['totalDescuentos']),
                            icono: Icons.percent,
                            color: AppColors.error,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildKpiCard(
                      label: 'Pedidos cancelados',
                      valor: '${_stats?['pedidosCancelados'] ?? 0}',
                      icono: Icons.cancel_outlined,
                      color: AppColors.error,
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

  Widget _buildRangoFechas() {
    String fmt(DateTime d) =>
        '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')} '
        '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    return Semantics(
      label: 'Cambiar rango del turno',
      button: true,
      child: InkWell(
        onTap: _seleccionarRango,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.panel,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.line),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.access_time,
                color: AppColors.textSecondary,
                size: 16,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Desde ${fmt(_desde)} · Hasta ${fmt(_hasta)}',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ),
              const Icon(
                Icons.calendar_today_outlined,
                color: AppColors.textSecondary,
                size: 14,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildKpiPrincipal({
    required String label,
    required String valor,
    required IconData icono,
    required Color colorFondo,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colorFondo,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: colorFondo.withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(icono, color: Colors.white, size: 36),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label.toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                    letterSpacing: 1.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  valor,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKpiCard({
    required String label,
    required String valor,
    required IconData icono,
    Color? color,
  }) {
    final c = color ?? AppColors.button;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.panel,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icono, color: c, size: 18),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                    height: 1.2,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            valor,
            style: TextStyle(
              color: c,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline,
              size: 48,
              color: AppColors.error,
            ),
            const SizedBox(height: 14),
            Text(
              _error ?? 'Error',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textPrimary),
            ),
            const SizedBox(height: 18),
            ElevatedButton.icon(
              onPressed: _cargar,
              icon: const Icon(Icons.refresh),
              label: const Text('REINTENTAR'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.button,
                foregroundColor: Colors.white,
                shape: const RoundedRectangleBorder(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
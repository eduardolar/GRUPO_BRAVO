import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:frontend/components/bravo_app_bar.dart';
import '../../core/colors_style.dart';
import '../../models/pedido_model.dart';
import '../../models/restaurante_model.dart';
import '../../providers/restaurante_provider.dart';
import '../../providers/usuario_provider.dart';
import '../../services/pedido_service.dart';

class KpisGlobalesScreen extends StatefulWidget {
  const KpisGlobalesScreen({super.key});

  @override
  State<KpisGlobalesScreen> createState() => _KpisGlobalesScreenState();
}

class _KpisGlobalesScreenState extends State<KpisGlobalesScreen> {
  List<Pedido> _pedidos = [];
  bool _cargando = true;
  String? _error;
  String _periodo = 'hoy';
  String _ordenarPor = 'ingresos'; // ingresos | pedidos | ticket

  static const _periodos = ['hoy', 'semana', 'mes', 'todo'];
  static const _etiquetasPeriodo = {
    'hoy': 'Hoy',
    'semana': 'Semana',
    'mes': 'Mes',
    'todo': 'Total',
  };

  @override
  void initState() {
    super.initState();
    _cargar();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final rp = context.read<RestauranteProvider>();
      final up = context.read<UsuarioProvider>();
      if (rp.restaurantes.isEmpty) rp.cargar();
      if (up.usuarios.isEmpty && !up.cargando) up.cargar();
    });
  }

  Future<void> _cargar() async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      // Sin restauranteId → todos los pedidos del sistema
      final datos = await PedidoService.obtenerTodosLosPedidos();
      if (!mounted) return;
      setState(() {
        _pedidos = datos;
        _cargando = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _cargando = false;
        _error = e.toString();
      });
    }
  }

  // ── Filtro por período ────────────────────────────────────────────
  List<Pedido> _filtrarPeriodo(List<Pedido> todos) {
    final ahora = DateTime.now();
    return todos.where((p) {
      final f = DateTime.tryParse(p.fecha);
      if (f == null) return false;
      switch (_periodo) {
        case 'hoy':
          return f.year == ahora.year &&
              f.month == ahora.month &&
              f.day == ahora.day;
        case 'semana':
          final ini = DateTime(
            ahora.year,
            ahora.month,
            ahora.day,
          ).subtract(Duration(days: ahora.weekday - 1));
          return !f.isBefore(ini);
        case 'mes':
          return f.year == ahora.year && f.month == ahora.month;
        default:
          return true;
      }
    }).toList();
  }

  // ── Métricas por sucursal ─────────────────────────────────────────
  List<_SucursalKpi> _calcularKpis(
    List<Restaurante> restaurantes,
    List<Pedido> pedidosFiltrados,
    List usuarios,
  ) {
    final kpis = restaurantes.map((r) {
      final idR = r.id.trim().toLowerCase();
      final pedidosSucursal = pedidosFiltrados.where((p) {
        final pid = (p.restauranteId ?? '').trim().toLowerCase();
        return pid == idR && p.estado.toLowerCase() != 'cancelado';
      }).toList();
      final cancelados = pedidosFiltrados.where((p) {
        final pid = (p.restauranteId ?? '').trim().toLowerCase();
        return pid == idR && p.estado.toLowerCase() == 'cancelado';
      }).length;
      final ingresos = pedidosSucursal.fold(0.0, (s, p) => s + p.total);
      final ticket = pedidosSucursal.isEmpty
          ? 0.0
          : ingresos / pedidosSucursal.length;
      final personal = usuarios.where((u) {
        final uid = (u.restauranteId ?? '').toString().trim().toLowerCase();
        return uid == idR &&
            u.rolRaw != 'cliente' &&
            u.rolRaw != 'superadministrador';
      }).length;
      return _SucursalKpi(
        restaurante: r,
        ingresos: ingresos,
        pedidos: pedidosSucursal.length,
        cancelados: cancelados,
        ticketMedio: ticket,
        personal: personal,
      );
    }).toList();

    kpis.sort((a, b) {
      switch (_ordenarPor) {
        case 'pedidos':
          return b.pedidos.compareTo(a.pedidos);
        case 'ticket':
          return b.ticketMedio.compareTo(a.ticketMedio);
        default:
          return b.ingresos.compareTo(a.ingresos);
      }
    });
    return kpis;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: BravoAppBar(
        title: 'KPIS GLOBALES',
        // El BravoAppBar no acepta acciones extra; mantenemos refresh dentro del cuerpo.
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
            child: Consumer2<RestauranteProvider, UsuarioProvider>(
              builder: (context, rp, up, _) {
                final pedidosFiltrados = _filtrarPeriodo(_pedidos);
                final kpis = _calcularKpis(
                  rp.restaurantes,
                  pedidosFiltrados,
                  up.usuarios,
                );
                final totalIngresos = kpis.fold(0.0, (s, k) => s + k.ingresos);
                final totalPedidos = kpis.fold(0, (s, k) => s + k.pedidos);

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(),
                    _buildSelectorPeriodo(),
                    const SizedBox(height: 12),
                    _buildGlobalKpis(
                      totalIngresos,
                      totalPedidos,
                      rp.restaurantes.length,
                      up.usuarios
                          .where(
                            (u) =>
                                u.rolRaw != 'cliente' &&
                                u.rolRaw != 'superadministrador',
                          )
                          .length,
                    ),
                    const SizedBox(height: 16),
                    _buildOrdenSelector(),
                    const SizedBox(height: 8),
                    Expanded(child: _buildCuerpo(kpis, totalIngresos)),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: const Text(
                  'KPIs Globales',
                  style: TextStyle(
                    fontFamily: 'Playfair Display',
                    color: Colors.white,
                    fontSize: 30,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              IconButton(
                icon: _cargando
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 1.8,
                          color: AppColors.button,
                        ),
                      )
                    : Icon(
                        Icons.refresh_rounded,
                        color: Colors.white.withValues(alpha: 0.7),
                        size: 22,
                      ),
                onPressed: _cargando ? null : _cargar,
              ),
            ],
          ),
          const SizedBox(height: 6),
          Container(height: 2, width: 40, color: AppColors.button),
          const SizedBox(height: 8),
          Text(
            'Comparativa entre sucursales',
            style: GoogleFonts.manrope(
              color: Colors.white.withValues(alpha: 0.65),
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectorPeriodo() {
    return SizedBox(
      height: 34,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        children: _periodos.map((p) {
          final sel = _periodo == p;
          return GestureDetector(
            onTap: () => setState(() => _periodo = p),
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
              decoration: BoxDecoration(
                color: sel
                    ? AppColors.button
                    : Colors.white.withValues(alpha: 0.07),
                border: Border.all(
                  color: sel ? AppColors.button : Colors.white24,
                ),
              ),
              child: Text(
                _etiquetasPeriodo[p]!,
                style: GoogleFonts.manrope(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: sel ? Colors.white : Colors.white70,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildGlobalKpis(
    double ingresos,
    int pedidos,
    int sucursales,
    int personal,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Row(
            children: [
              Expanded(
                child: _MiniKpi(
                  label: 'INGRESOS',
                  value: '${ingresos.toStringAsFixed(0)} €',
                  highlight: true,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _MiniKpi(label: 'PEDIDOS', value: '$pedidos'),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _MiniKpi(label: 'SUCURSALES', value: '$sucursales'),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _MiniKpi(label: 'PERSONAL', value: '$personal'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOrdenSelector() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Row(
            children: [
              Text(
                'Ordenar:',
                style: GoogleFonts.manrope(
                  fontSize: 11,
                  color: Colors.white.withValues(alpha: 0.65),
                ),
              ),
              const SizedBox(width: 10),
              ...[
                ('ingresos', 'Ingresos'),
                ('pedidos', 'Pedidos'),
                ('ticket', 'Ticket medio'),
              ].map((item) {
                final sel = _ordenarPor == item.$1;
                return GestureDetector(
                  onTap: () => setState(() => _ordenarPor = item.$1),
                  child: Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: sel ? AppColors.button : Colors.white24,
                      ),
                      color: sel
                          ? AppColors.button.withValues(alpha: 0.15)
                          : Colors.transparent,
                    ),
                    child: Text(
                      item.$2,
                      style: GoogleFonts.manrope(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: sel ? AppColors.button : Colors.white70,
                      ),
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCuerpo(List<_SucursalKpi> kpis, double totalIngresos) {
    if (_cargando) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.button),
      );
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.wifi_off_outlined,
              color: Colors.white.withValues(alpha: 0.4),
              size: 48,
            ),
            const SizedBox(height: 12),
            Text(
              'Error al cargar datos',
              style: GoogleFonts.manrope(color: Colors.white70),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: _cargar,
              child: Text(
                'Reintentar',
                style: GoogleFonts.manrope(color: AppColors.button),
              ),
            ),
          ],
        ),
      );
    }
    if (kpis.isEmpty) {
      return Center(
        child: Text(
          'No hay sucursales',
          style: GoogleFonts.manrope(color: Colors.white70),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _cargar,
      color: AppColors.button,
      backgroundColor: Colors.black,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 60),
        itemCount: kpis.length,
        itemBuilder: (_, i) => Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: _SucursalCard(
              kpi: kpis[i],
              posicion: i + 1,
              totalIngresos: totalIngresos,
              esLider: i == 0,
            ),
          ),
        ),
      ),
    );
  }
}

// ── Mini KPI global ──────────────────────────────────────────────────
class _MiniKpi extends StatelessWidget {
  final String label;
  final String value;
  final bool highlight;

  const _MiniKpi({
    required this.label,
    required this.value,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          decoration: BoxDecoration(
            color: highlight
                ? AppColors.button.withValues(alpha: 0.65)
                : Colors.black.withValues(alpha: 0.45),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: highlight
                  ? AppColors.button.withValues(alpha: 0.85)
                  : Colors.white.withValues(alpha: 0.15),
              width: 1.2,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.manrope(
                  fontSize: 8,
                  fontWeight: FontWeight.w800,
                  color: Colors.white.withValues(alpha: 0.7),
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: GoogleFonts.manrope(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Card por sucursal ────────────────────────────────────────────────
class _SucursalCard extends StatelessWidget {
  final _SucursalKpi kpi;
  final int posicion;
  final double totalIngresos;
  final bool esLider;

  const _SucursalCard({
    required this.kpi,
    required this.posicion,
    required this.totalIngresos,
    required this.esLider,
  });

  @override
  Widget build(BuildContext context) {
    final pct = totalIngresos > 0 ? kpi.ingresos / totalIngresos : 0.0;
    final abierto = kpi.restaurante.estaAbierto();

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.45),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: esLider
                    ? AppColors.button.withValues(alpha: 0.6)
                    : Colors.white.withValues(alpha: 0.15),
                width: esLider ? 1.8 : 1.5,
              ),
            ),
            child: Column(
              children: [
                // Cabecera
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
                  child: Row(
                    children: [
                      // Número de posición
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: esLider
                              ? AppColors.button
                              : Colors.white.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.25),
                            width: 1,
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          '$posicion',
                          style: GoogleFonts.manrope(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              kpi.restaurante.nombre,
                              style: GoogleFonts.manrope(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              kpi.restaurante.direccion,
                              style: GoogleFonts.manrope(
                                fontSize: 11,
                                color: Colors.white.withValues(alpha: 0.65),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Badge abierto/cerrado
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: abierto
                              ? Colors.greenAccent.withValues(alpha: 0.15)
                              : Colors.redAccent.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: abierto
                                ? Colors.greenAccent.withValues(alpha: 0.5)
                                : Colors.redAccent.withValues(alpha: 0.5),
                          ),
                        ),
                        child: Text(
                          abierto ? 'ABIERTO' : 'CERRADO',
                          style: GoogleFonts.manrope(
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            color: abierto
                                ? Colors.greenAccent
                                : Colors.redAccent,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Barra de ingresos proporcional
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: LayoutBuilder(
                    builder: (_, c) => Stack(
                      children: [
                        Container(
                          height: 4,
                          width: c.maxWidth,
                          color: Colors.white.withValues(alpha: 0.10),
                        ),
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 700),
                          curve: Curves.easeOut,
                          height: 4,
                          width: c.maxWidth * pct,
                          color: esLider
                              ? AppColors.button
                              : AppColors.button.withValues(alpha: 0.5),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 10),
                // Métricas
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
                  child: Row(
                    children: [
                      _MetricaItem(
                        icono: Icons.euro_rounded,
                        label: 'Ingresos',
                        valor: '${kpi.ingresos.toStringAsFixed(2)} €',
                        destacado: true,
                      ),
                      const SizedBox(width: 16),
                      _MetricaItem(
                        icono: Icons.receipt_long_outlined,
                        label: 'Pedidos',
                        valor: '${kpi.pedidos}',
                      ),
                      const SizedBox(width: 16),
                      _MetricaItem(
                        icono: Icons.show_chart_rounded,
                        label: 'Ticket',
                        valor: '${kpi.ticketMedio.toStringAsFixed(2)} €',
                      ),
                      const SizedBox(width: 16),
                      _MetricaItem(
                        icono: Icons.badge_outlined,
                        label: 'Personal',
                        valor: '${kpi.personal}',
                      ),
                      if (kpi.cancelados > 0) ...[
                        const SizedBox(width: 16),
                        _MetricaItem(
                          icono: Icons.cancel_outlined,
                          label: 'Cancel.',
                          valor: '${kpi.cancelados}',
                          color: AppColors.error,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MetricaItem extends StatelessWidget {
  final IconData icono;
  final String label;
  final String valor;
  final bool destacado;
  final Color? color;

  const _MetricaItem({
    required this.icono,
    required this.label,
    required this.valor,
    this.destacado = false,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? (destacado ? AppColors.button : Colors.white70);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icono, size: 11, color: c),
            const SizedBox(width: 4),
            Text(
              label,
              style: GoogleFonts.manrope(
                fontSize: 9,
                fontWeight: FontWeight.w700,
                color: c,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
        const SizedBox(height: 3),
        Text(
          valor,
          style: GoogleFonts.manrope(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: color ?? Colors.white,
          ),
        ),
      ],
    );
  }
}

// ── Modelo local ─────────────────────────────────────────────────────
class _SucursalKpi {
  final Restaurante restaurante;
  final double ingresos;
  final int pedidos;
  final int cancelados;
  final double ticketMedio;
  final int personal;

  const _SucursalKpi({
    required this.restaurante,
    required this.ingresos,
    required this.pedidos,
    required this.cancelados,
    required this.ticketMedio,
    required this.personal,
  });
}

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/colors_style.dart';
import '../../models/pedido_model.dart';
import '../../services/pedido_service.dart';

class ContabilidadScreen extends StatefulWidget {
  final String? restauranteId;
  final String restauranteNombre;

  const ContabilidadScreen({
    super.key,
    this.restauranteId,
    this.restauranteNombre = 'Todas las sucursales',
  });

  @override
  State<ContabilidadScreen> createState() => _ContabilidadScreenState();
}

class _ContabilidadScreenState extends State<ContabilidadScreen> {
  List<Pedido> _pedidos = [];
  bool _cargando = true;
  String? _error;
  String _periodo = 'hoy'; // hoy | semana | mes | todo

  static const _periodos = ['hoy', 'semana', 'mes', 'todo'];
  static const _etiquetasPeriodo = {
    'hoy': 'Hoy',
    'semana': 'Esta semana',
    'mes': 'Este mes',
    'todo': 'Todo',
  };

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final datos = await PedidoService.obtenerTodosLosPedidos(
        restauranteId: (widget.restauranteId?.isEmpty ?? true)
            ? null
            : widget.restauranteId,
      );
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
  List<Pedido> get _pedidosFiltrados {
    final ahora = DateTime.now();
    return _pedidos.where((p) {
      final f = DateTime.tryParse(p.fecha);
      if (f == null) return false;
      switch (_periodo) {
        case 'hoy':
          return f.year == ahora.year &&
              f.month == ahora.month &&
              f.day == ahora.day;
        case 'semana':
          final inicio = ahora.subtract(Duration(days: ahora.weekday - 1));
          final inicioSemana = DateTime(inicio.year, inicio.month, inicio.day);
          return f.isAfter(inicioSemana.subtract(const Duration(seconds: 1)));
        case 'mes':
          return f.year == ahora.year && f.month == ahora.month;
        default:
          return true;
      }
    }).toList();
  }

  // ── Métricas calculadas ───────────────────────────────────────────
  double get _ingresos {
    return _pedidosFiltrados
        .where((p) => p.estado.toLowerCase() != 'cancelado')
        .fold(0.0, (s, p) => s + p.total);
  }

  int get _totalPedidos => _pedidosFiltrados.length;

  int get _pedidosCompletados => _pedidosFiltrados
      .where((p) => p.estado.toLowerCase() == 'entregado')
      .length;

  int get _pedidosCancelados => _pedidosFiltrados
      .where((p) => p.estado.toLowerCase() == 'cancelado')
      .length;

  double get _ticketMedio {
    final completados = _pedidosFiltrados
        .where((p) => p.estado.toLowerCase() != 'cancelado')
        .toList();
    if (completados.isEmpty) return 0;
    return completados.fold(0.0, (s, p) => s + p.total) / completados.length;
  }

  // Ingresos por método de pago
  Map<String, double> get _porMetodoPago {
    final mapa = <String, double>{};
    for (final p in _pedidosFiltrados.where(
      (p) => p.estado.toLowerCase() != 'cancelado',
    )) {
      final metodo = p.metodoPago.isEmpty ? 'Sin especificar' : p.metodoPago;
      mapa[metodo] = (mapa[metodo] ?? 0) + p.total;
    }
    final sorted = Map.fromEntries(
      mapa.entries.toList()..sort((a, b) => b.value.compareTo(a.value)),
    );
    return sorted;
  }

  // Ingresos por tipo de entrega
  Map<String, double> get _porTipoEntrega {
    final mapa = <String, double>{};
    for (final p in _pedidosFiltrados.where(
      (p) => p.estado.toLowerCase() != 'cancelado',
    )) {
      final tipo = _normalizarTipo(p.tipoEntrega);
      mapa[tipo] = (mapa[tipo] ?? 0) + p.total;
    }
    final sorted = Map.fromEntries(
      mapa.entries.toList()..sort((a, b) => b.value.compareTo(a.value)),
    );
    return sorted;
  }

  String _normalizarTipo(String tipo) {
    final t = tipo.toLowerCase();
    if (t.contains('mesa') || t.contains('local') || t.contains('comer')) {
      return 'Local / Mesa';
    }
    if (t.contains('domicilio') || t.contains('delivery')) return 'Domicilio';
    if (t.contains('recog') || t.contains('pickup')) return 'Recogida';
    return tipo.isEmpty ? 'Sin especificar' : tipo;
  }

  // Top 5 productos más vendidos (por cantidad)
  List<MapEntry<String, int>> get _topProductos {
    final mapa = <String, int>{};
    for (final p in _pedidosFiltrados.where(
      (p) => p.estado.toLowerCase() != 'cancelado',
    )) {
      for (final prod in p.productos) {
        mapa[prod.nombre] = (mapa[prod.nombre] ?? 0) + prod.cantidad;
      }
    }
    final sorted = mapa.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sorted.take(5).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/images/Bravo restaurante.jpg',
              fit: BoxFit.cover,
            ),
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
                _buildHeader(),
                _buildSelectorPeriodo(),
                Expanded(child: _buildCuerpo()),
              ],
            ),
          ),
          Positioned(
            top: 20,
            left: 10,
            child: IconButton(
              icon: const Icon(
                Icons.arrow_back_ios_new,
                color: Colors.white,
                size: 20,
              ),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          Positioned(
            top: 20,
            right: 10,
            child: IconButton(
              icon: _cargando
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 1.8,
                        color: AppColors.button,
                      ),
                    )
                  : const Icon(
                      Icons.refresh_rounded,
                      color: Colors.white70,
                      size: 22,
                    ),
              onPressed: _cargando ? null : _cargar,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 60, 80, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Contabilidad',
            style: TextStyle(
              fontFamily: 'Playfair Display',
              color: Colors.white,
              fontSize: 36,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Container(height: 2, width: 40, color: AppColors.button),
          const SizedBox(height: 8),
          Text(
            widget.restauranteNombre,
            style: GoogleFonts.manrope(
              color: Colors.white.withValues(alpha: 0.55),
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectorPeriodo() {
    return SizedBox(
      height: 38,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        children: _periodos.map((p) {
          final selected = _periodo == p;
          return GestureDetector(
            onTap: () => setState(() => _periodo = p),
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: selected
                    ? AppColors.button
                    : Colors.white.withValues(alpha: 0.07),
                border: Border.all(
                  color: selected ? AppColors.button : Colors.white12,
                ),
              ),
              child: Text(
                _etiquetasPeriodo[p]!,
                style: GoogleFonts.manrope(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: selected ? Colors.white : Colors.white54,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildCuerpo() {
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
            const Icon(
              Icons.wifi_off_outlined,
              color: Colors.white24,
              size: 48,
            ),
            const SizedBox(height: 12),
            Text(
              'Error al cargar datos',
              style: GoogleFonts.manrope(color: Colors.white38),
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

    final lista = _pedidosFiltrados;

    return RefreshIndicator(
      onRefresh: _cargar,
      color: AppColors.button,
      backgroundColor: AppColors.background,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 60),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // KPI grid 2x2
                  Row(
                    children: [
                      Expanded(
                        child: _KpiCard(
                          icon: Icons.euro_rounded,
                          label: 'INGRESOS',
                          value: '${_ingresos.toStringAsFixed(2)} €',
                          sub: lista.isEmpty
                              ? 'Sin pedidos'
                              : '$_totalPedidos pedido${_totalPedidos != 1 ? 's' : ''}',
                          highlight: true,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _KpiCard(
                          icon: Icons.show_chart_rounded,
                          label: 'TICKET MEDIO',
                          value: '${_ticketMedio.toStringAsFixed(2)} €',
                          sub: 'por pedido',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _KpiCard(
                          icon: Icons.check_circle_outline,
                          label: 'COMPLETADOS',
                          value: '$_pedidosCompletados',
                          sub: 'entregados',
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _KpiCard(
                          icon: Icons.cancel_outlined,
                          label: 'CANCELADOS',
                          value: '$_pedidosCancelados',
                          sub: 'no facturados',
                          danger: _pedidosCancelados > 0,
                        ),
                      ),
                    ],
                  ),

                  if (lista.isNotEmpty) ...[
                    const SizedBox(height: 28),
                    _buildSeccionHeader(
                      'MÉTODO DE PAGO',
                      Icons.payment_outlined,
                    ),
                    const SizedBox(height: 12),
                    ..._buildBarras(_porMetodoPago, _ingresos),

                    const SizedBox(height: 28),
                    _buildSeccionHeader(
                      'TIPO DE ENTREGA',
                      Icons.delivery_dining_outlined,
                    ),
                    const SizedBox(height: 12),
                    ..._buildBarras(_porTipoEntrega, _ingresos),

                    if (_topProductos.isNotEmpty) ...[
                      const SizedBox(height: 28),
                      _buildSeccionHeader(
                        'TOP PRODUCTOS',
                        Icons.restaurant_menu_outlined,
                      ),
                      const SizedBox(height: 12),
                      ..._buildTopProductos(),
                    ],
                  ] else ...[
                    const SizedBox(height: 60),
                    Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.bar_chart_outlined,
                            size: 64,
                            color: Colors.white24,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Sin datos para este período',
                            style: GoogleFonts.manrope(
                              color: Colors.white38,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSeccionHeader(String titulo, IconData icono) {
    return Row(
      children: [
        Icon(icono, size: 14, color: AppColors.button),
        const SizedBox(width: 8),
        Text(
          titulo,
          style: GoogleFonts.manrope(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: AppColors.button,
            letterSpacing: 2,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(child: Container(height: 1, color: Colors.white12)),
      ],
    );
  }

  List<Widget> _buildBarras(Map<String, double> mapa, double total) {
    return mapa.entries.map((e) {
      final pct = total > 0 ? e.value / total : 0.0;
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Text(
                    e.key,
                    style: GoogleFonts.manrope(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  '${e.value.toStringAsFixed(2)} € · ${(pct * 100).toStringAsFixed(0)}%',
                  style: GoogleFonts.manrope(
                    fontSize: 12,
                    color: Colors.white54,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            LayoutBuilder(
              builder: (_, constraints) {
                return Stack(
                  children: [
                    Container(
                      height: 6,
                      width: constraints.maxWidth,
                      color: Colors.white.withValues(alpha: 0.08),
                    ),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 600),
                      curve: Curves.easeOut,
                      height: 6,
                      width: constraints.maxWidth * pct,
                      color: AppColors.button,
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      );
    }).toList();
  }

  List<Widget> _buildTopProductos() {
    final maxVal = _topProductos.isEmpty ? 1 : _topProductos.first.value;
    return _topProductos.asMap().entries.map((entry) {
      final i = entry.key;
      final prod = entry.value;
      final pct = prod.value / maxVal;
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(
          children: [
            Container(
              width: 22,
              height: 22,
              color: i == 0
                  ? AppColors.button
                  : AppColors.button.withValues(alpha: 0.2 + (0.15 * (4 - i))),
              alignment: Alignment.center,
              child: Text(
                '${i + 1}',
                style: GoogleFonts.manrope(
                  fontSize: 11,
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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Text(
                          prod.key,
                          style: GoogleFonts.manrope(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        '${prod.value} ud.',
                        style: GoogleFonts.manrope(
                          fontSize: 12,
                          color: Colors.white54,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  LayoutBuilder(
                    builder: (_, constraints) {
                      return Stack(
                        children: [
                          Container(
                            height: 4,
                            width: constraints.maxWidth,
                            color: Colors.white.withValues(alpha: 0.08),
                          ),
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 600),
                            curve: Curves.easeOut,
                            height: 4,
                            width: constraints.maxWidth * pct,
                            color: i == 0
                                ? AppColors.button
                                : AppColors.button.withValues(alpha: 0.5),
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }).toList();
  }
}

// ── KPI CARD ─────────────────────────────────────────────────────────
class _KpiCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String sub;
  final bool highlight;
  final bool danger;

  const _KpiCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.sub,
    this.highlight = false,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) {
    final bg = highlight
        ? AppColors.button
        : Colors.white.withValues(alpha: 0.07);
    final borderColor = highlight
        ? AppColors.button
        : danger
        ? AppColors.error.withValues(alpha: 0.4)
        : Colors.white12;
    final colorP = Colors.white;
    final colorS = highlight ? Colors.white60 : Colors.white38;
    final colorI = highlight
        ? Colors.white70
        : (danger ? AppColors.error : AppColors.button);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bg,
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: colorI),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  style: GoogleFonts.manrope(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    color: colorS,
                    letterSpacing: 1.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: GoogleFonts.manrope(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: colorP,
            ),
          ),
          const SizedBox(height: 2),
          Text(sub, style: GoogleFonts.manrope(fontSize: 11, color: colorS)),
        ],
      ),
    );
  }
}

import 'dart:async';
import 'dart:convert';
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
import '../../services/download_helper.dart';
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

  // Estado del export de KPIs
  bool _exportandoKpis = false;

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

  /// Calcula el rango de fechas para el período seleccionado.
  /// Devuelve `(fechaDesde, fechaHasta)` donde `null` significa sin límite.
  (DateTime?, DateTime?) _rangoDelPeriodo() {
    final ahora = DateTime.now();
    switch (_periodo) {
      case 'hoy':
        final inicio = DateTime(ahora.year, ahora.month, ahora.day);
        final fin = DateTime(ahora.year, ahora.month, ahora.day, 23, 59, 59);
        return (inicio, fin);
      case 'semana':
        final inicioSemana = ahora.subtract(Duration(days: ahora.weekday - 1));
        return (
          DateTime(inicioSemana.year, inicioSemana.month, inicioSemana.day),
          ahora,
        );
      case 'mes':
        return (DateTime(ahora.year, ahora.month, 1), ahora);
      default:
        // 'todo': sin filtro de fecha; el limit actúa como salvaguarda.
        return (null, null);
    }
  }

  Future<void> _cargar() async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      // Sin restauranteId → todos los pedidos del sistema.
      final (fechaDesde, fechaHasta) = _rangoDelPeriodo();
      final datos = await PedidoService.obtenerTodosLosPedidos(
        fechaDesde: fechaDesde,
        fechaHasta: fechaHasta,
        limit: 1000,
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

  // ── Métricas por sucursal ─────────────────────────────────────────────────

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
      final items = pedidosSucursal.fold(
        0,
        (s, p) => s + p.productos.fold(0, (si, pr) => si + pr.cantidad),
      );
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
        itemsVendidos: items,
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

  // ── Export CSV de KPIs por sucursal ──────────────────────────────────────

  Future<void> _exportarKpisCsv(List<_SucursalKpi> kpis) async {
    setState(() => _exportandoKpis = true);
    try {
      // CSV en convención es-ES (Excel español):
      //   • Delimitador `;` (coma se reserva al decimal)
      //   • Decimal con coma en importes
      //   • BOM UTF-8 para tildes/eñes
      // RFC 4180: si un campo contiene `;`, `"` o salto de línea se escapa
      // entre comillas dobles.
      String escapar(String s) {
        if (s.contains(';') || s.contains('"') || s.contains('\n')) {
          return '"${s.replaceAll('"', '""')}"';
        }
        return s;
      }

      String num2(double v) => v.toStringAsFixed(2).replaceAll('.', ',');

      final lines = <String>[
        // Cabecera
        [
          'nombre_sucursal',
          'ingresos_periodo',
          'pedidos_periodo',
          'ticket_medio',
          'items_vendidos',
        ].map(escapar).join(';'),
        // Filas
        ...kpis.map(
          (k) => [
            k.restaurante.nombre,
            num2(k.ingresos),
            k.pedidos.toString(),
            num2(k.ticketMedio),
            k.itemsVendidos.toString(),
          ].map(escapar).join(';'),
        ),
      ];

      // Prepende BOM UTF-8 (﻿) para que Excel detecte la codificación.
      final csv = '﻿${lines.join('\r\n')}';
      final bytes = utf8.encode(csv);

      final ahora = DateTime.now();
      final nombre =
          'kpis_sucursales_${ahora.toIso8601String().substring(0, 10)}_$_periodo.csv';

      final ruta = await descargarBytes(bytes, nombre);
      if (!mounted) return;
      _snack('CSV guardado: $ruta', color: AppColors.disp);
    } catch (e) {
      if (!mounted) return;
      _snack('Error al exportar: $e', color: AppColors.error);
    } finally {
      if (mounted) setState(() => _exportandoKpis = false);
    }
  }

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: BravoAppBar(title: 'KPIS GLOBALES'),
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
            // Más oscuro que antes (0.55→0.78) para que los textos rojos no
            // se confundan con la imagen Bravo de fondo (papel beige + bigote
            // rojizo) que filtraba colores cálidos a través.
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withValues(alpha: 0.78),
                Colors.black.withValues(alpha: 0.94),
              ],
            ),
          ),
          child: SafeArea(
            child: Consumer2<RestauranteProvider, UsuarioProvider>(
              builder: (context, rp, up, _) {
                final kpis = _calcularKpis(
                  rp.restaurantes,
                  _pedidos,
                  up.usuarios,
                );
                final totalIngresos = kpis.fold(0.0, (s, k) => s + k.ingresos);
                final totalPedidos = kpis.fold(0, (s, k) => s + k.pedidos);

                // En pantallas anchas (desktop) limitamos el ancho del
                // contenido a 1100 px y lo centramos para que todo quede
                // alineado y legible. En móvil/tablet llena el viewport.
                return Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1100),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildHeader(kpis),
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
                        // Carrusel KPI por sucursal (top 6 como tarjetas)
                        if (!_cargando && _error == null && kpis.isNotEmpty)
                          _buildCarruselKpis(kpis),
                        const SizedBox(height: 8),
                        _buildOrdenSelector(),
                        const SizedBox(height: 8),
                        Expanded(child: _buildCuerpo(kpis, totalIngresos)),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(List<_SucursalKpi> kpis) {
    return Padding(
      // Mismo padding lateral (20) que el resto del contenido para que todo
      // quede alineado en la misma línea vertical.
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      child: Row(
        children: [
          // El título "KPIS GLOBALES" ya lo da BravoAppBar arriba; aquí solo
          // dejamos el subtítulo + barra granate para no duplicar.
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(height: 2, width: 32, color: AppColors.detailOnDark),
                const SizedBox(height: 6),
                Text(
                  'Comparativa entre sucursales',
                  style: GoogleFonts.manrope(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 12,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),
          // Botón export CSV de KPIs
          Semantics(
            label: 'Exportar KPIs por sucursal en CSV',
            button: true,
            child: TextButton.icon(
              onPressed: (_exportandoKpis || kpis.isEmpty)
                  ? null
                  : () => _exportarKpisCsv(kpis),
              icon: _exportandoKpis
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 1.8,
                        color: AppColors.detailOnDark,
                      ),
                    )
                  : const Icon(
                      Icons.download_outlined,
                      size: 16,
                      color: AppColors.detailOnDark,
                    ),
              label: Text(
                _exportandoKpis ? 'EXPORTANDO…' : 'EXPORTAR CSV',
                style: GoogleFonts.manrope(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.linkOnDark,
                ),
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
                      color: AppColors.primaryOnDark,
                    ),
                  )
                : Icon(
                    Icons.refresh_rounded,
                    color: Colors.white.withValues(alpha: 0.7),
                    size: 22,
                  ),
            tooltip: 'Recargar',
            onPressed: _cargando ? null : _cargar,
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
            onTap: () {
              setState(() => _periodo = p);
              _cargar();
            },
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
              decoration: BoxDecoration(
                color: sel
                    ? AppColors.primaryAccent
                    : Colors.white.withValues(alpha: 0.07),
                border: Border.all(
                  color: sel ? AppColors.primaryAccent : Colors.white24,
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
      // Padding lateral 20 = mismo que header y resto, para alineación
      // vertical perfecta. Antes estaba centrado con maxWidth=640 que en
      // pantallas anchas dejaba el bloque "flotando" en el medio.
      padding: const EdgeInsets.symmetric(horizontal: 20),
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
    );
  }

  // ── Carrusel de tarjetas KPI por sucursal ─────────────────────────────────
  // Copiado del patrón _SeccionKpis de admin_home_screen para mantener independencia entre roles.

  Widget _buildCarruselKpis(List<_SucursalKpi> kpis) {
    // Tomamos las 6 mejores sucursales (según el orden activo) para el carrusel.
    final top = kpis.take(6).toList();

    final tarjetas = top.map((k) {
      final abierto = k.restaurante.estaAbierto();
      return _SuperAdminKpiCard(
        nombre: k.restaurante.nombre,
        ingresos: k.ingresos,
        pedidos: k.pedidos,
        ticket: k.ticketMedio,
        abierto: abierto,
        esLider: kpis.indexOf(k) == 0,
      );
    }).toList();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(width: 3, height: 14, color: AppColors.detailOnDark),
              const SizedBox(width: 8),
              Text(
                'SUCURSALES DESTACADAS',
                style: GoogleFonts.manrope(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: Colors.white70,
                  letterSpacing: 2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          LayoutBuilder(
            builder: (context, constraints) {
              final perPage = constraints.maxWidth < 600
                  ? 1
                  : (constraints.maxWidth < 900 ? 2 : 3);
              return _CarruselWidget(
                tarjetas: tarjetas,
                perPage: perPage,
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildOrdenSelector() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
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
                    color: sel ? AppColors.detailOnDark : Colors.white24,
                  ),
                  color: sel
                      ? AppColors.detailOnDark.withValues(alpha: 0.15)
                      : Colors.transparent,
                ),
                child: Text(
                  item.$2,
                  style: GoogleFonts.manrope(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: sel ? AppColors.linkOnDark : Colors.white70,
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildCuerpo(List<_SucursalKpi> kpis, double totalIngresos) {
    if (_cargando) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primaryOnDark),
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
                style: GoogleFonts.manrope(color: AppColors.linkOnDark),
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
      color: AppColors.primaryOnDark,
      backgroundColor: Colors.black,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 60),
        itemCount: kpis.length,
        // Sin Center+ConstrainedBox por item: el max-width global de 1100
        // ya está aplicado al Column padre, así las cards llenan el ancho
        // disponible y todo queda alineado en una sola columna.
        itemBuilder: (_, i) => _SucursalCard(
          kpi: kpis[i],
          posicion: i + 1,
          totalIngresos: totalIngresos,
          esLider: i == 0,
        ),
      ),
    );
  }
}

// ─── Carrusel reutilizable ────────────────────────────────────────────────────
// Copiado del patrón _SeccionKpis/_carrusel de admin_home_screen para mantener independencia entre roles.

class _CarruselWidget extends StatefulWidget {
  final List<Widget> tarjetas;
  final int perPage;

  const _CarruselWidget({
    required this.tarjetas,
    required this.perPage,
  });

  @override
  State<_CarruselWidget> createState() => _CarruselWidgetState();
}

class _CarruselWidgetState extends State<_CarruselWidget> {
  static const Duration _kAutoRotateInterval = Duration(seconds: 4);
  static const Duration _kAutoRotateAnim = Duration(milliseconds: 600);

  final PageController _pageCtrl = PageController();
  Timer? _autoRotateTimer;
  int _paginaActual = 0;
  bool _userInteracted = false;
  // Mientras el usuario mantiene pulsada una tarjeta, el auto-rotate se pausa.
  bool _pausado = false;

  @override
  void initState() {
    super.initState();
    _iniciarAutoRotacion();
  }

  @override
  void dispose() {
    _autoRotateTimer?.cancel();
    _pageCtrl.dispose();
    super.dispose();
  }

  void _iniciarAutoRotacion() {
    _autoRotateTimer?.cancel();
    if (_pausado) return;
    _autoRotateTimer = Timer.periodic(_kAutoRotateInterval, (_) {
      if (!mounted || !_pageCtrl.hasClients) return;
      final totalPaginas =
          (widget.tarjetas.length / widget.perPage).ceil().clamp(1, 999);
      if (totalPaginas <= 1) return;
      final siguiente = (_paginaActual + 1) % totalPaginas;
      _pageCtrl.animateToPage(
        siguiente,
        duration: _kAutoRotateAnim,
        curve: Curves.easeInOut,
      );
    });
  }

  void _avanzarSiguiente() {
    if (!_pageCtrl.hasClients) return;
    final totalPaginas =
        (widget.tarjetas.length / widget.perPage).ceil().clamp(1, 999);
    if (totalPaginas <= 1) return;
    final siguiente = (_paginaActual + 1) % totalPaginas;
    _userInteracted = true;
    _pageCtrl.animateToPage(
      siguiente,
      duration: _kAutoRotateAnim,
      curve: Curves.easeInOut,
    );
  }

  void _pausarRotacion() {
    _pausado = true;
    _autoRotateTimer?.cancel();
  }

  void _retomarRotacion() {
    if (!_pausado) return;
    _pausado = false;
    _iniciarAutoRotacion();
  }

  @override
  Widget build(BuildContext context) {
    final tarjetas = widget.tarjetas;
    final perPage = widget.perPage;

    // Agrupamos las tarjetas en páginas.
    final paginas = <List<Widget>>[];
    for (int i = 0; i < tarjetas.length; i += perPage) {
      paginas.add(
        tarjetas.sublist(
          i,
          (i + perPage).clamp(0, tarjetas.length),
        ),
      );
    }

    if (paginas.isEmpty) return const SizedBox.shrink();

    return Column(
      children: [
        SizedBox(
          height: 130,
          child: PageView.builder(
            controller: _pageCtrl,
            itemCount: paginas.length,
            onPageChanged: (i) {
              setState(() => _paginaActual = i);
              if (_userInteracted) {
                _userInteracted = false;
                _iniciarAutoRotacion();
              }
            },
            itemBuilder: (_, idxPagina) {
              final grupo = paginas[idxPagina];
              return Row(
                children: [
                  for (int j = 0; j < grupo.length; j++) ...[
                    if (j > 0) const SizedBox(width: 12),
                    // Tap simple → avanza al siguiente. Long-press → pausa
                    // mientras se mantenga; al soltar retoma el auto-rotate.
                    Expanded(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: _avanzarSiguiente,
                        onLongPressStart: (_) => _pausarRotacion(),
                        onLongPressEnd: (_) => _retomarRotacion(),
                        onLongPressCancel: _retomarRotacion,
                        child: grupo[j],
                      ),
                    ),
                  ],
                  // Huecos vacíos si la última página no llena perPage.
                  for (int k = grupo.length; k < perPage; k++) ...[
                    const SizedBox(width: 12),
                    const Expanded(child: SizedBox.shrink()),
                  ],
                ],
              );
            },
          ),
        ),
        const SizedBox(height: 10),
        if (paginas.length > 1) _dots(paginas.length),
      ],
    );
  }

  Widget _dots(int total) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (int i = 0; i < total; i++)
          Semantics(
            label: 'Ir a diapositiva ${i + 1} de $total',
            button: true,
            child: GestureDetector(
              onTap: () {
                _userInteracted = true;
                _pageCtrl.animateToPage(
                  i,
                  duration: _kAutoRotateAnim,
                  curve: Curves.easeInOut,
                );
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: i == _paginaActual ? 18 : 8,
                height: 8,
                decoration: BoxDecoration(
                  color: i == _paginaActual
                      ? AppColors.detailOnDark
                      : Colors.white.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// ─── Tarjeta KPI por sucursal (para el carrusel) ──────────────────────────────
// Copiado del patrón _AdminKpiCard de admin_home_screen para mantener independencia entre roles.

class _SuperAdminKpiCard extends StatelessWidget {
  final String nombre;
  final double ingresos;
  final int pedidos;
  final double ticket;
  final bool abierto;
  final bool esLider;

  const _SuperAdminKpiCard({
    required this.nombre,
    required this.ingresos,
    required this.pedidos,
    required this.ticket,
    required this.abierto,
    required this.esLider,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$nombre: ${ingresos.toStringAsFixed(2)} €, $pedidos pedidos',
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.45),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: esLider
                    ? AppColors.detailOnDark.withValues(alpha: 0.6)
                    : Colors.white12,
                width: esLider ? 1.5 : 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Nombre + estado
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        nombre,
                        style: GoogleFonts.manrope(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: abierto
                            ? AppColors.successVibrant.withValues(alpha: 0.15)
                            : AppColors.error.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(3),
                        border: Border.all(
                          color: abierto
                              ? AppColors.successVibrant.withValues(alpha: 0.5)
                              : AppColors.error.withValues(alpha: 0.5),
                        ),
                      ),
                      child: Text(
                        abierto ? 'AB' : 'CE',
                        style: GoogleFonts.manrope(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: abierto ? AppColors.successVibrant : AppColors.error,
                        ),
                      ),
                    ),
                  ],
                ),
                // Ingresos
                Text(
                  '${ingresos.toStringAsFixed(0)} €',
                  style: GoogleFonts.manrope(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: esLider ? AppColors.linkOnDark : Colors.white,
                    height: 1.1,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                // Pedidos y ticket medio
                Text(
                  '$pedidos ped · ${ticket.toStringAsFixed(2)} €/ud',
                  style: GoogleFonts.manrope(
                    fontSize: 12,
                    color: Colors.white54,
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
}

// ── Mini KPI global ──────────────────────────────────────────────────────────

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
                ? AppColors.primaryAccent.withValues(alpha: 0.65)
                : Colors.black.withValues(alpha: 0.45),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: highlight
                  ? AppColors.primaryAccent.withValues(alpha: 0.85)
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
                  fontSize: 11,
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

// ── Card por sucursal ─────────────────────────────────────────────────────────

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
                    ? AppColors.detailOnDark.withValues(alpha: 0.6)
                    : Colors.white.withValues(alpha: 0.15),
                width: esLider ? 1.8 : 1.5,
              ),
            ),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
                  child: Row(
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: esLider
                              ? AppColors.primaryAccent
                              : Colors.white.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.25),
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
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: abierto
                              ? AppColors.successVibrant.withValues(alpha: 0.15)
                              : AppColors.error.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: abierto
                                ? AppColors.successVibrant.withValues(alpha: 0.5)
                                : AppColors.error.withValues(alpha: 0.5),
                          ),
                        ),
                        child: Text(
                          abierto ? 'ABIERTO' : 'CERRADO',
                          style: GoogleFonts.manrope(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color:
                                abierto ? AppColors.successVibrant : AppColors.error,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
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
                              ? AppColors.primaryOnDark
                              : AppColors.primaryOnDark.withValues(alpha: 0.5),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),
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
    final c = color ?? (destacado ? AppColors.detailOnDark : Colors.white70);
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
                fontSize: 11,
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

// ── Modelo local ──────────────────────────────────────────────────────────────

class _SucursalKpi {
  final Restaurante restaurante;
  final double ingresos;
  final int pedidos;
  final int cancelados;
  final double ticketMedio;
  final int itemsVendidos;
  final int personal;

  const _SucursalKpi({
    required this.restaurante,
    required this.ingresos,
    required this.pedidos,
    required this.cancelados,
    required this.ticketMedio,
    required this.itemsVendidos,
    required this.personal,
  });
}

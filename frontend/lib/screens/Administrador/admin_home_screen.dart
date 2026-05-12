import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:frontend/components/bravo_app_bar.dart';
import 'package:frontend/core/colors_style.dart';
import 'package:frontend/models/mesa_model.dart';
import 'package:frontend/models/pedido_model.dart';
import 'package:frontend/providers/auth_provider.dart';
import 'package:frontend/screens/Administrador/admin_cierre_caja_screen.dart';
import 'package:frontend/screens/Administrador/admin_contabilidad_screen.dart';
import 'package:frontend/screens/Administrador/admin_cupones_screen.dart';
import 'package:frontend/screens/Administrador/admin_local_screen.dart';
import 'package:frontend/screens/Administrador/admin_menu_screen.dart';
import 'package:frontend/screens/Administrador/admin_mesas_screen.dart';
import 'package:frontend/screens/Administrador/admin_reservas_screen.dart';
import 'package:frontend/screens/Administrador/admin_stock_screen.dart';
import 'package:frontend/screens/Administrador/admin_usuarios_screen.dart';
import 'package:frontend/screens/Administrador/admin_avisos_falta_screen.dart';
import 'package:frontend/services/api_service.dart';
import 'package:frontend/services/aviso_falta_service.dart';
import 'package:frontend/services/cierre_caja_service.dart';
import 'package:frontend/services/mesa_service.dart';
import 'package:frontend/services/pedido_service.dart';
import 'package:frontend/services/reserva_service.dart';
import 'package:provider/provider.dart';

class MenuAdministrador extends StatefulWidget {
  const MenuAdministrador({super.key});

  @override
  State<MenuAdministrador> createState() => _MenuAdministradorState();
}

class _MenuAdministradorState extends State<MenuAdministrador> {
  // ── Estado de KPIs ────────────────────────────────────────────
  bool _cargandoKpis = false;

  /// null = fallo de red; el widget mostrará "—"
  double? _ventasHoy;
  int? _pedidosHoy;
  int? _pedidosAbiertos;
  int? _mesasOcupadas;
  int? _mesasTotal;
  // Lista de nombres de ingredientes con stock bajo. La tarjeta KPI muestra
  // los primeros 3 + "+N más" si hay más, en lugar de solo el conteo.
  List<String> _stockBajoNombres = const [];
  int? _reservasHoy;

  // Avisos de falta de stock pendientes (trabajadores → admin).
  int _avisosPendientes = 0;

  // Aviso de cierre de caja: si el admin no ha abierto el turno actual
  // (comida o cena), guardamos aquí el nombre del turno para mostrar banner.
  String? _turnoSinAbrir;

  // Cierre que ya debería haberse cerrado: rango horario terminado hace >15min
  // y aún en estado "abierto". Mostramos banner con CTA a cerrarlo.
  Map<String, dynamic>? _cierrePendienteCerrar;

  @override
  void initState() {
    super.initState();
    // Cargamos tras el primer frame para tener el contexto de Provider listo.
    WidgetsBinding.instance.addPostFrameCallback((_) => _cargarTodo());
  }

  // ── Carga completa (KPIs + stock + reservas + turno actual) ──
  Future<void> _cargarTodo() async {
    await Future.wait([
      _cargarKpis(),
      _cargarStockBajo(),
      _cargarReservasHoy(),
      _verificarTurnoAbierto(),
      _verificarCierresPendientes(),
      _cargarAvisosPendientes(),
    ]);
  }

  Future<void> _cargarAvisosPendientes() async {
    try {
      final lista = await AvisoFaltaService.listar(estado: 'pendiente');
      if (!mounted) return;
      setState(() => _avisosPendientes = lista.length);
    } catch (_) {
      if (!mounted) return;
      setState(() => _avisosPendientes = 0);
    }
  }

  /// Devuelve la hora de fin del turno indicado, dado YYYY-MM-DD.
  /// Cena cruza medianoche → fin = día siguiente 04:59.
  DateTime _finTurno(String fecha, String turno) {
    final base = DateTime.parse(fecha);
    if (turno == 'comida') {
      return DateTime(base.year, base.month, base.day, 16, 59);
    }
    final manana = base.add(const Duration(days: 1));
    return DateTime(manana.year, manana.month, manana.day, 4, 59);
  }

  /// Lista cierres en estado abierto y se queda con el primero cuyo rango
  /// ya terminó hace más de 15 min. El backend filtra por sucursal del JWT,
  /// así que solo recibimos los nuestros.
  Future<void> _verificarCierresPendientes() async {
    try {
      final lista = await CierreCajaService.listar(estado: 'abierto');
      final ahora = DateTime.now();
      final pendiente = lista.firstWhere(
        (doc) {
          final fecha = doc['fecha'] as String?;
          final turno = doc['turno'] as String?;
          if (fecha == null || turno == null) return false;
          final fin = _finTurno(fecha, turno);
          return ahora.isAfter(fin.add(const Duration(minutes: 15)));
        },
        orElse: () => <String, dynamic>{},
      );
      if (!mounted) return;
      setState(() {
        _cierrePendienteCerrar = pendiente.isEmpty ? null : pendiente;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _cierrePendienteCerrar = null);
    }
  }

  /// Calcula el turno que cubre la hora actual según los rangos del backend
  /// (`comida` 05:00–16:59, `cena` 17:00–04:59). Siempre estamos en uno.
  String _turnoActual() {
    final now = DateTime.now();
    final mins = now.hour * 60 + now.minute;
    // comida: 05:00 (300) → 16:59 (1019). Resto cae en cena.
    if (mins >= 5 * 60 && mins < 17 * 60) return 'comida';
    return 'cena';
  }

  /// Comprueba si hay un cierre abierto para el turno actual. Si el endpoint
  /// devuelve null (404), guardamos el turno para mostrar el banner. Cualquier
  /// otro error se ignora (no queremos saturar al admin con errores de red).
  Future<void> _verificarTurnoAbierto() async {
    final turno = _turnoActual();
    try {
      final doc = await CierreCajaService.abiertoActual(turno);
      if (!mounted) return;
      setState(() => _turnoSinAbrir = doc == null ? turno : null);
    } catch (_) {
      if (!mounted) return;
      setState(() => _turnoSinAbrir = null);
    }
  }

  /// Tres llamadas en paralelo. Si alguna falla, las otras continúan;
  /// el KPI afectado queda en null y muestra "—".
  Future<void> _cargarKpis() async {
    if (!mounted) return;
    setState(() => _cargandoKpis = true);

    final restauranteId =
        context.read<AuthProvider>().usuarioActual?.restauranteId;
    final ahora = DateTime.now();
    final inicioDia = DateTime(ahora.year, ahora.month, ahora.day);

    // Lanzamos los tres futures en paralelo pero con tipos independientes
    // para no mezclarlos en una List<Object?> que rompería el cast.
    final futureHoy = _fetchPedidos(
      restauranteId: restauranteId,
      fechaDesde: inicioDia,
      fechaHasta: ahora,
      tag: 'pedidosHoy',
    );
    final futureAbiertos = _fetchPedidos(
      restauranteId: restauranteId,
      estados: const ['pendiente', 'preparando', 'listo'],
      tag: 'pedidosAbiertos',
    );
    final futureMesas = _fetchMesas(restauranteId: restauranteId);

    // Esperamos los tres a la vez; cada uno ya captura sus propias excepciones.
    final pedidosHoy = await futureHoy;
    final pedidosAbiertos = await futureAbiertos;
    final mesas = await futureMesas;

    if (!mounted) return;
    setState(() {
      _cargandoKpis = false;

      if (pedidosHoy != null) {
        _pedidosHoy = pedidosHoy.length;
        // Acumula el campo total de cada Pedido (tipo double en el modelo).
        _ventasHoy = pedidosHoy.fold<double>(0.0, (s, p) => s + p.total);
      } else {
        _pedidosHoy = null;
        _ventasHoy = null;
      }

      _pedidosAbiertos = pedidosAbiertos?.length;

      if (mesas != null) {
        _mesasTotal = mesas.length;
        _mesasOcupadas = mesas.where((m) => !m.disponible).length;
      } else {
        _mesasTotal = null;
        _mesasOcupadas = null;
      }
    });
  }

  // ── Helpers de fetch aislados (capturan su propia excepción) ──────────────

  Future<List<Pedido>?> _fetchPedidos({
    String? restauranteId,
    DateTime? fechaDesde,
    DateTime? fechaHasta,
    List<String>? estados,
    required String tag,
  }) async {
    try {
      return await PedidoService.obtenerTodosLosPedidos(
        restauranteId: restauranteId,
        fechaDesde: fechaDesde,
        fechaHasta: fechaHasta,
        estados: estados,
        limit: 1000,
      );
    } catch (e) {
      debugPrint('KPI $tag: $e');
      return null;
    }
  }

  Future<List<Mesa>?> _fetchMesas({String? restauranteId}) async {
    try {
      return await MesaService.obtenerMesas(restauranteId: restauranteId);
    } catch (e) {
      debugPrint('KPI mesas: $e');
      return null;
    }
  }

  Future<void> _cargarStockBajo() async {
    if (!mounted) return;
    try {
      final restauranteId =
          context.read<AuthProvider>().usuarioActual?.restauranteId;
      final lista = await ApiService.obtenerIngredientesStockBajo(
        restauranteId: restauranteId,
      );
      if (mounted) {
        setState(
          () => _stockBajoNombres = lista.map((i) => i.nombre).toList(),
        );
      }
    } catch (e) {
      debugPrint('KPI stockBajo: $e');
    }
  }

  Future<void> _cargarReservasHoy() async {
    if (!mounted) return;
    try {
      final ahora = DateTime.now();
      final fechaStr =
          '${ahora.year.toString().padLeft(4, '0')}-'
          '${ahora.month.toString().padLeft(2, '0')}-'
          '${ahora.day.toString().padLeft(2, '0')}';
      final lista = await ReservaService.obtenerReservasAdmin(fecha: fechaStr);
      if (mounted) setState(() => _reservasHoy = lista.length);
    } catch (e) {
      debugPrint('KPI reservasHoy: $e');
    }
  }

  // ── Build ─────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: const BravoAppBar(title: "PANEL DE CONTROL"),
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
                Colors.black.withValues(alpha: 0.5),
                Colors.black.withValues(alpha: 0.85),
              ],
            ),
          ),
          child: SafeArea(
            child: RefreshIndicator(
              color: AppColors.button,
              backgroundColor: Colors.black87,
              onRefresh: _cargarTodo,
              child: SingleChildScrollView(
                // AlwaysScrollable es necesario para que RefreshIndicator
                // funcione aunque el contenido no desborde la pantalla.
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24.0,
                    vertical: 16.0,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Cabecera con refresh manual ────────────
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  "¡Hola, Administrador!",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 28,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  "¿Qué te gustaría gestionar hoy?",
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Botón de recarga manual de KPIs
                          Semantics(
                            label: 'Recargar datos del dashboard',
                            button: true,
                            child: IconButton(
                              icon: _cargandoKpis
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: AppColors.button,
                                      ),
                                    )
                                  : const Icon(
                                      Icons.refresh,
                                      color: Colors.white70,
                                    ),
                              tooltip: 'Actualizar KPIs',
                              onPressed:
                                  _cargandoKpis ? null : _cargarTodo,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 24),

                      // ── Aviso de turno sin abrir ──────────────
                      if (_turnoSinAbrir != null) ...[
                        _BannerTurnoSinAbrir(
                          turno: _turnoSinAbrir!,
                          onAbrir: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const AdminCierreCajaScreen(),
                              ),
                            );
                            // Al volver, refrescamos por si lo abrió.
                            _verificarTurnoAbierto();
                          },
                        ),
                        const SizedBox(height: 16),
                      ],

                      // ── Aviso de turno por cerrar ─────────────
                      if (_cierrePendienteCerrar != null) ...[
                        _BannerCierrePendiente(
                          turno:
                              _cierrePendienteCerrar!['turno'] as String? ??
                              '',
                          fecha:
                              _cierrePendienteCerrar!['fecha'] as String? ??
                              '',
                          onCerrar: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const AdminCierreCajaScreen(),
                              ),
                            );
                            _verificarCierresPendientes();
                          },
                        ),
                        const SizedBox(height: 16),
                      ],

                      // ── Avisos de falta de stock ───────────────
                      if (_avisosPendientes > 0) ...[
                        _BannerAvisosFalta(
                          cantidad: _avisosPendientes,
                          onTap: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    const AdminAvisosFaltaScreen(),
                              ),
                            );
                            _cargarAvisosPendientes();
                          },
                        ),
                        const SizedBox(height: 16),
                      ],

                      // ── Sección de KPIs ────────────────────────
                      _SeccionKpis(
                        ventasHoy: _ventasHoy,
                        pedidosHoy: _pedidosHoy,
                        pedidosAbiertos: _pedidosAbiertos,
                        mesasOcupadas: _mesasOcupadas,
                        mesasTotal: _mesasTotal,
                        stockBajoNombres: _stockBajoNombres,
                        reservasHoy: _reservasHoy,
                        cargando: _cargandoKpis,
                        onStockTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const AdminStockScreen(),
                          ),
                        ).then((_) => _cargarTodo()),
                        onReservasTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const AdminReservasScreen(),
                          ),
                        ).then((_) => _cargarTodo()),
                      ),

                      const SizedBox(height: 32),

                      // ── Grid de atajos ──────────────────────────
                      Row(
                        children: [
                          Expanded(
                            child: _buildAdminCard(
                              context: context,
                              title: "La Carta",
                              subtitle: "Editar platos",
                              icon: Icons.restaurant_menu,
                              destination: const AdminMenuScreen(),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildAdminCard(
                              context: context,
                              title: "Mesas",
                              subtitle: "Plano interactivo",
                              icon: Icons.table_restaurant_outlined,
                              destination: const AdminMesasScreen(),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: _buildAdminCard(
                              context: context,
                              title: "Inventario",
                              subtitle: "Control de stock",
                              icon: Icons.inventory_2_outlined,
                              destination: const AdminStockScreen(),
                              badge: _stockBajoNombres.length,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildAdminCard(
                              context: context,
                              title: "Usuarios",
                              subtitle: "Cuentas y roles",
                              icon: Icons.people_outline,
                              destination: const AdminUsuariosScreen(),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: _buildAdminCard(
                              context: context,
                              title: "Reservas",
                              subtitle: "Gestión del día",
                              icon: Icons.event_available,
                              destination: const AdminReservasScreen(),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildAdminCard(
                              context: context,
                              title: "Cupones",
                              subtitle: "Descuentos y ofertas",
                              icon: Icons.local_offer_outlined,
                              destination: const AdminCuponesScreen(),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _buildAdminCard(
                        context: context,
                        title: "Mi local",
                        subtitle: "Información del restaurante",
                        icon: Icons.storefront_outlined,
                        destination: const AdminLocalScreen(),
                        isFullWidth: true,
                      ),
                      const SizedBox(height: 16),
                      _buildAdminCard(
                        context: context,
                        title: "Cierre de caja",
                        subtitle: "Apertura, cierre y descuadre por turno",
                        icon: Icons.point_of_sale_outlined,
                        destination: const AdminCierreCajaScreen(),
                        isFullWidth: true,
                      ),
                      const SizedBox(height: 16),
                      _buildAdminCard(
                        context: context,
                        title: "Contabilidad",
                        subtitle: "Informes y finanzas",
                        icon: Icons.account_balance_wallet_outlined,
                        destination: const AdminContabilidadScreen(),
                        isFullWidth: true,
                      ),
                      const SizedBox(height: 30),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAdminCard({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required Widget destination,
    bool isFullWidth = false,
    int badge = 0,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          height: isFullWidth ? 120 : 160,
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.45),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.15),
              width: 1.5,
            ),
          ),
          child: Stack(
            children: [
              Positioned.fill(
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(20),
                    highlightColor: AppColors.button.withValues(alpha: 0.1),
                    splashColor: AppColors.button.withValues(alpha: 0.2),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => destination),
                    ).then((_) => _cargarTodo()),
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: isFullWidth
                          ? Row(
                              children: [
                                _buildIconContainer(icon),
                                const SizedBox(width: 20),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisAlignment:
                                        MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        title,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 22,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        subtitle,
                                        style: TextStyle(
                                          color: Colors.white.withValues(
                                            alpha: 0.6,
                                          ),
                                          fontSize: 14,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Icon(
                                  Icons.arrow_forward_ios,
                                  color:
                                      Colors.white.withValues(alpha: 0.3),
                                  size: 20,
                                ),
                              ],
                            )
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildIconContainer(icon),
                                const Spacer(),
                                Text(
                                  title,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  subtitle,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.6),
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                ),
              ),
              if (badge > 0)
                Positioned(
                  top: 10,
                  right: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.error,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.3),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      '$badge',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIconContainer(IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.button.withValues(alpha: 0.2),
        shape: BoxShape.circle,
        border: Border.all(
          color: AppColors.button.withValues(alpha: 0.5),
          width: 1,
        ),
      ),
      child: Icon(icon, color: AppColors.button, size: 30),
    );
  }
}

// ── Sección de KPIs ────────────────────────────────────────────────────────────

/// Muestra los 5 KPIs del día. Es un widget separado para mantener
/// el árbol del build limpio y facilitar los tests de widget.
class _SeccionKpis extends StatefulWidget {
  final double? ventasHoy;
  final int? pedidosHoy;
  final int? pedidosAbiertos;
  final int? mesasOcupadas;
  final int? mesasTotal;
  /// Nombres de ingredientes con stock bajo (no solo el conteo) para que la
  /// tarjeta STOCK BAJO muestre cuáles son críticos, no solo cuántos.
  final List<String> stockBajoNombres;
  final int? reservasHoy;
  final bool cargando;
  final VoidCallback onStockTap;
  final VoidCallback onReservasTap;

  const _SeccionKpis({
    required this.ventasHoy,
    required this.pedidosHoy,
    required this.pedidosAbiertos,
    required this.mesasOcupadas,
    required this.mesasTotal,
    required this.stockBajoNombres,
    required this.reservasHoy,
    required this.cargando,
    required this.onStockTap,
    required this.onReservasTap,
  });

  @override
  State<_SeccionKpis> createState() => _SeccionKpisState();
}

class _SeccionKpisState extends State<_SeccionKpis> {
  // Carrusel rotativo: una tarjeta a la vez en móvil, 2 en tablet/desktop.
  // Auto-rotación cada 4 s. El usuario puede pausarla con long press.
  static const Duration _kAutoRotateInterval = Duration(seconds: 4);
  static const Duration _kAutoRotateAnim = Duration(milliseconds: 600);

  final PageController _pageCtrl = PageController();
  Timer? _autoRotateTimer;
  int _paginaActual = 0;
  bool _userInteracted = false;
  // Indica si la auto-rotación está pausada por long press.
  bool _pausado = false;

  // Número total de páginas; se actualiza en _carrusel().
  int _totalPaginas = 1;

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

  /// Arranca el timer que avanza una página cada [_kAutoRotateInterval].
  /// Se reinicia tras una interacción manual (no se queda parado).
  void _iniciarAutoRotacion() {
    _autoRotateTimer?.cancel();
    _pausado = false;
    _autoRotateTimer = Timer.periodic(_kAutoRotateInterval, (_) {
      if (!mounted || !_pageCtrl.hasClients) return;
      if (_totalPaginas <= 1) return;
      final siguiente = (_paginaActual + 1) % _totalPaginas;
      _pageCtrl.animateToPage(
        siguiente,
        duration: _kAutoRotateAnim,
        curve: Curves.easeInOut,
      );
    });
  }

  /// Tap sobre una tarjeta: avanza a la siguiente página y reinicia el timer
  /// para que el usuario no sufra un salto inmediato tras su gesto.
  void _avanzarSiguiente() {
    if (!_pageCtrl.hasClients || _totalPaginas <= 1) return;
    final siguiente = (_paginaActual + 1) % _totalPaginas;
    _pageCtrl.animateToPage(
      siguiente,
      duration: _kAutoRotateAnim,
      curve: Curves.easeInOut,
    );
    _iniciarAutoRotacion();
  }

  /// Long press iniciado: pausa la auto-rotación.
  void _pausarRotacion() {
    _autoRotateTimer?.cancel();
    _pausado = true;
  }

  /// Long press liberado o cancelado: retoma la auto-rotación.
  void _retomarRotacion() {
    if (_pausado) _iniciarAutoRotacion();
  }

  // Formatea un double como euros con 2 decimales, o "—" si es null.
  String _euros(double? v) =>
      v != null ? '${v.toStringAsFixed(2)} €' : '—';

  // Formatea un int, o "—" si es null.
  String _num(int? v) => v?.toString() ?? '—';

  // Fracción de mesas ocupadas como "X / Y", o "—" si alguno es null.
  String _mesas() {
    if (widget.mesasOcupadas == null || widget.mesasTotal == null) return '—';
    return '${widget.mesasOcupadas} / ${widget.mesasTotal}';
  }

  // El color de la tarjeta de mesas vira a ámbar/rojo si supera el 75%.
  Color _colorMesas() {
    final ocupadas = widget.mesasOcupadas;
    final total = widget.mesasTotal;
    if (ocupadas == null || total == null || total == 0) {
      return Colors.transparent;
    }
    final ratio = ocupadas / total;
    if (ratio > 0.75) return AppColors.error.withValues(alpha: 0.55);
    if (ratio > 0.5) return AppColors.warning.withValues(alpha: 0.45);
    return Colors.transparent;
  }

  /// Resume la lista de ingredientes con stock bajo en una sola línea:
  /// hasta 3 nombres separados por · y "+N más" si quedan más. Si la lista
  /// está vacía, devuelve "todo en orden".
  String _resumenStockBajo(List<String> nombres) {
    if (nombres.isEmpty) return 'todo en orden';
    const maxMostrar = 3;
    if (nombres.length <= maxMostrar) return nombres.join(' · ');
    final visibles = nombres.take(maxMostrar).join(' · ');
    final extra = nombres.length - maxMostrar;
    return '$visibles · +$extra más';
  }

  @override
  Widget build(BuildContext context) {
    // Cabecera de sección
    final header = Row(
      children: [
        Container(width: 3, height: 18, color: AppColors.button),
        const SizedBox(width: 10),
        const Text(
          'PULSO DE TU SUCURSAL HOY',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: Colors.white70,
            letterSpacing: 2,
          ),
        ),
        if (widget.cargando) ...[
          const SizedBox(width: 10),
          const SizedBox(
            width: 12,
            height: 12,
            child: CircularProgressIndicator(
              strokeWidth: 1.5,
              color: AppColors.button,
            ),
          ),
        ],
      ],
    );

    // Las 6 tarjetas KPI.
    // Las que antes navegaban directamente por onTap (STOCK BAJO, RESERVAS HOY)
    // ya no lo hacen: el tap avanza el carrusel. El acceso a la pantalla se
    // mantiene a través del icono discreto open_in_new en la esquina.
    final tarjetas = [
      _AdminKpiCard(
        icon: Icons.euro_outlined,
        label: 'VENTAS HOY',
        value: _euros(widget.ventasHoy),
        sub: 'facturado hoy',
        accentColor: (widget.ventasHoy ?? 0) > 0
            ? AppColors.success
            : AppColors.button,
        onTapAdvance: _avanzarSiguiente,
        onLongPressPause: _pausarRotacion,
        onLongPressResume: _retomarRotacion,
      ),
      _AdminKpiCard(
        icon: Icons.receipt_long_outlined,
        label: 'PEDIDOS HOY',
        value: _num(widget.pedidosHoy),
        sub: 'comandas del día',
        onTapAdvance: _avanzarSiguiente,
        onLongPressPause: _pausarRotacion,
        onLongPressResume: _retomarRotacion,
      ),
      _AdminKpiCard(
        icon: Icons.soup_kitchen_outlined,
        label: 'EN COCINA',
        value: _num(widget.pedidosAbiertos),
        sub: 'pendiente/preparando/listo',
        accentColor: (widget.pedidosAbiertos ?? 0) > 0
            ? AppColors.warningText
            : null,
        onTapAdvance: _avanzarSiguiente,
        onLongPressPause: _pausarRotacion,
        onLongPressResume: _retomarRotacion,
      ),
      _AdminKpiCard(
        icon: Icons.table_restaurant_outlined,
        label: 'MESAS OCUPADAS',
        value: _mesas(),
        sub: 'sobre el total',
        overrideBackground: _colorMesas(),
        onTapAdvance: _avanzarSiguiente,
        onLongPressPause: _pausarRotacion,
        onLongPressResume: _retomarRotacion,
      ),
      _AdminKpiCard(
        icon: Icons.inventory_2_outlined,
        label: 'STOCK BAJO',
        value: widget.stockBajoNombres.length.toString(),
        // Mostramos los primeros nombres y "+N más" si hay más de 3, en vez
        // del genérico "ingredientes críticos". Así el admin sabe cuáles son
        // sin entrar al inventario.
        sub: _resumenStockBajo(widget.stockBajoNombres),
        accentColor:
            widget.stockBajoNombres.isNotEmpty ? AppColors.error : Colors.white38,
        shortcutTap:
            widget.stockBajoNombres.isNotEmpty ? widget.onStockTap : null,
        onTapAdvance: _avanzarSiguiente,
        onLongPressPause: _pausarRotacion,
        onLongPressResume: _retomarRotacion,
      ),
      _AdminKpiCard(
        icon: Icons.event_available_outlined,
        label: 'RESERVAS HOY',
        value: widget.reservasHoy?.toString() ?? '—',
        sub: 'para hoy',
        accentColor: (widget.reservasHoy ?? 0) > 0
            ? AppColors.info
            : Colors.white38,
        // Navegación directa sustituida por icono discreto; tap avanza carrusel.
        shortcutTap: widget.onReservasTap,
        onTapAdvance: _avanzarSiguiente,
        onLongPressPause: _pausarRotacion,
        onLongPressResume: _retomarRotacion,
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        header,
        const SizedBox(height: 14),
        LayoutBuilder(
          builder: (context, constraints) {
            // 1 tarjeta por página en móvil, 2 en tablet, 3 en desktop.
            final perPage = constraints.maxWidth < 600
                ? 1
                : (constraints.maxWidth < 900 ? 2 : 3);
            return _carrusel(tarjetas, perPage);
          },
        ),
      ],
    );
  }

  /// Carrusel rotativo con [perPage] tarjetas visibles a la vez.
  /// Auto-rotación + swipe manual + tap para avanzar + long press para pausar.
  Widget _carrusel(List<Widget> tarjetas, int perPage) {
    // Agrupamos las tarjetas en páginas según [perPage].
    final paginas = <List<Widget>>[];
    for (int i = 0; i < tarjetas.length; i += perPage) {
      paginas.add(
        tarjetas.sublist(
          i,
          (i + perPage).clamp(0, tarjetas.length),
        ),
      );
    }

    // Actualizamos el total para que _avanzarSiguiente() sepa cuántas hay.
    _totalPaginas = paginas.length;

    return Column(
      children: [
        SizedBox(
          height: 130,
          child: PageView.builder(
            controller: _pageCtrl,
            itemCount: paginas.length,
            onPageChanged: (i) {
              setState(() => _paginaActual = i);
              // Swipe manual: reiniciamos el timer para no saltar de inmediato.
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
                    Expanded(child: grupo[j]),
                  ],
                  // Si la última página no llena `perPage`, completar con
                  // huecos vacíos para que las tarjetas no se ensanchen feo.
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
        _dots(paginas.length),
      ],
    );
  }

  /// Indicadores de página. El tap en un dot navega directamente sin pasar
  /// por la lógica de pausa (comportamiento independiente al long press).
  Widget _dots(int total) {
    if (total <= 1) return const SizedBox.shrink();
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
                      ? AppColors.button
                      : Colors.white.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// ── Tarjeta KPI glass (copia local del patrón de sucursal_detail_screen) ──────

/// Tarjeta glass con icono granate, label en CAPS, valor grande y sub-label.
///
/// - [onTapAdvance]: avanza el carrusel a la siguiente página (tap simple).
/// - [onLongPressPause] / [onLongPressResume]: pausa y retoma el auto-rotate.
/// - [shortcutTap]: callback opcional para el icono discreto open_in_new que
///   aparece en la esquina inferior derecha. Permite acceder a la pantalla
///   relacionada sin interferir con el gesto de avance del carrusel.
class _AdminKpiCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String sub;
  final Color? accentColor;
  final Color? overrideBackground;
  final VoidCallback onTapAdvance;
  final VoidCallback onLongPressPause;
  final VoidCallback onLongPressResume;
  // Navegación opcional a pantalla relacionada (reemplaza el onTap directo).
  final VoidCallback? shortcutTap;

  const _AdminKpiCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.sub,
    required this.onTapAdvance,
    required this.onLongPressPause,
    required this.onLongPressResume,
    this.accentColor,
    this.overrideBackground,
    this.shortcutTap,
  });

  @override
  Widget build(BuildContext context) {
    final iconColor = accentColor ?? AppColors.button;
    final bg = overrideBackground != null && overrideBackground != Colors.transparent
        ? overrideBackground!
        : Colors.black.withValues(alpha: 0.4);

    return Semantics(
      label: '$label: $value',
      child: GestureDetector(
        onTap: onTapAdvance,
        onLongPressStart: (_) => onLongPressPause(),
        onLongPressEnd: (_) => onLongPressResume(),
        onLongPressCancel: onLongPressResume,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white12, width: 1),
              ),
              child: Stack(
                children: [
                  // Contenido principal de la tarjeta
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Icono + label en una fila compacta
                      Row(
                        children: [
                          Icon(icon, size: 13, color: iconColor),
                          const SizedBox(width: 5),
                          Flexible(
                            child: Text(
                              label,
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

                      // Valor principal
                      Text(
                        value,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          height: 1.1,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),

                      // Sub-label. Permitimos 2 líneas porque la tarjeta
                      // STOCK BAJO ahora muestra varios nombres y se truncaba
                      // feo en una sola línea.
                      Text(
                        sub,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.white54,
                          height: 1.2,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),

                  // Icono discreto para acceso directo a pantalla relacionada.
                  // Solo visible cuando hay un shortcutTap definido.
                  if (shortcutTap != null)
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Semantics(
                        label: 'Abrir pantalla de $label',
                        button: true,
                        child: GestureDetector(
                          // Consumimos el tap para no propagar al GestureDetector padre.
                          onTap: shortcutTap,
                          behavior: HitTestBehavior.opaque,
                          child: Padding(
                            padding: const EdgeInsets.all(4),
                            child: Icon(
                              Icons.open_in_new,
                              size: 11,
                              color: Colors.white.withValues(alpha: 0.35),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Banner que avisa al admin de que el turno actual de caja no está abierto.
/// Tap → navega a la pantalla de cierres para que pueda abrirlo.
class _BannerTurnoSinAbrir extends StatelessWidget {
  final String turno;
  final VoidCallback onAbrir;

  const _BannerTurnoSinAbrir({required this.turno, required this.onAbrir});

  @override
  Widget build(BuildContext context) {
    final etiqueta = turno == 'comida' ? 'comida' : 'cena';
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onAbrir,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: AppColors.warning.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: AppColors.warning.withValues(alpha: 0.55),
              width: 1.2,
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.warning_amber_rounded,
                color: AppColors.warning,
                size: 26,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Turno de $etiqueta sin abrir',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Toca para abrir el cierre de caja correspondiente',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.white54),
            ],
          ),
        ),
      ),
    );
  }
}

/// Banner informativo (azul) que avisa al admin de avisos de falta de stock
/// pendientes enviados por los trabajadores.
class _BannerAvisosFalta extends StatelessWidget {
  final int cantidad;
  final VoidCallback onTap;

  const _BannerAvisosFalta({required this.cantidad, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: AppColors.info.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: AppColors.info.withValues(alpha: 0.55),
              width: 1.2,
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.inventory_2_outlined,
                color: AppColors.info,
                size: 26,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$cantidad ${cantidad == 1 ? 'aviso' : 'avisos'} de falta de stock pendiente${cantidad == 1 ? '' : 's'}.',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Toca para revisarlos.',
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.white54),
            ],
          ),
        ),
      ),
    );
  }
}

/// Banner que avisa de un cierre cuyo rango horario ya terminó y sigue abierto.
/// Usa el color "error" del DS para diferenciarlo del banner de "sin abrir".
class _BannerCierrePendiente extends StatelessWidget {
  final String turno;
  final String fecha;
  final VoidCallback onCerrar;

  const _BannerCierrePendiente({
    required this.turno,
    required this.fecha,
    required this.onCerrar,
  });

  @override
  Widget build(BuildContext context) {
    final etiqueta = turno == 'comida' ? 'comida' : 'cena';
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onCerrar,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: AppColors.error.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: AppColors.error.withValues(alpha: 0.55),
              width: 1.2,
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.lock_clock_outlined,
                color: AppColors.error,
                size: 26,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Turno de $etiqueta pendiente de cerrar',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Abierto el $fecha. Toca para cerrarlo y cuadrar caja',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.white54),
            ],
          ),
        ),
      ),
    );
  }
}

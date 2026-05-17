import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/app_snackbar.dart';
import '../../models/reserva_model.dart';
import '../../models/restaurante_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/cart_provider.dart';
import '../../providers/restaurante_provider.dart';
import '../../services/api_service.dart';
import '../../components/Cliente/reservar_mesa/confirmacion_sheet.dart';
import '../../components/Cliente/reservar_mesa/skeleton_reservas.dart';
import '../../components/Cliente/reservar_mesa/utils.dart' as ru;
import '../../core/colors_style.dart';

import 'reservar_mesa/components/reserva_app_bar.dart';
import 'reservar_mesa/components/selector_sucursal_pill.dart';
import 'reservar_mesa/components/reserva_tab_bar.dart';
import 'reservar_mesa/components/fecha_strip.dart';
import 'reservar_mesa/components/turno_toggle.dart';
import 'reservar_mesa/components/seccion_label.dart';
import 'reservar_mesa/components/slots_hora.dart';
import 'reservar_mesa/components/contador_comensales.dart';
import 'reservar_mesa/components/campo_texto_reserva.dart';
import 'reservar_mesa/components/barra_confirmar.dart';
import 'reservar_mesa/components/encabezado_grupo.dart';
import 'reservar_mesa/components/tarjeta_dismissible.dart';
import 'reservar_mesa/components/estado_vacio_reservas.dart';
import 'reservar_mesa/components/boton_dialogo.dart';

class ReservarMesaScreen extends StatefulWidget {
  const ReservarMesaScreen({super.key});

  @override
  State<ReservarMesaScreen> createState() => _ReservarMesaScreenState();
}

class _ReservarMesaScreenState extends State<ReservarMesaScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _formKey = GlobalKey<FormState>();
  final _dateScrollController = ScrollController();

  // ── Fechas disponibles (hoy + 60 días) ──
  final List<DateTime> _fechas = List.generate(
    61,
    (i) => DateTime(
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day,
    ).add(Duration(days: i)),
  );

  late DateTime _fechaSeleccionada;
  TimeOfDay _horaSeleccionada = const TimeOfDay(hour: 14, minute: 0);
  int _numComensales = 2;
  int _maxComensales = 12;
  final TextEditingController _nombreController = TextEditingController();
  final TextEditingController _notasController = TextEditingController();
  bool _isLoading = false;
  bool _cargandoDisponibilidad = false;
  Timer? _debounce;

  Map<String, bool> _disponibilidadHoras = {};
  String _turnoSeleccionado = 'comida';

  final Map<String, List<TimeOfDay>> _horasPorTurno = {
    'comida': [
      const TimeOfDay(hour: 12, minute: 30),
      const TimeOfDay(hour: 13, minute: 0),
      const TimeOfDay(hour: 13, minute: 30),
      const TimeOfDay(hour: 14, minute: 0),
      const TimeOfDay(hour: 14, minute: 30),
      const TimeOfDay(hour: 15, minute: 0),
      const TimeOfDay(hour: 15, minute: 30),
      const TimeOfDay(hour: 16, minute: 0),
    ],
    'cena': [
      const TimeOfDay(hour: 20, minute: 0),
      const TimeOfDay(hour: 20, minute: 30),
      const TimeOfDay(hour: 21, minute: 0),
      const TimeOfDay(hour: 21, minute: 30),
      const TimeOfDay(hour: 22, minute: 0),
      const TimeOfDay(hour: 22, minute: 30),
      const TimeOfDay(hour: 23, minute: 0),
      const TimeOfDay(hour: 23, minute: 30),
    ],
  };

  List<Reserva> _misReservas = [];
  bool _cargandoReservas = false;

  Restaurante? _restaurante;

  static const double _kMaxContentWidth = 720.0;

  @override
  void initState() {
    super.initState();
    _fechaSeleccionada = _fechas.first;
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (_tabController.index == 1 && _misReservas.isEmpty) _cargarReservas();
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      if ((auth.usuarioActual?.nombre ?? '').isNotEmpty) {
        _nombreController.text = auth.usuarioActual!.nombre;
      }
      _scrollToFechaSeleccionada(animate: false);
    });

    _cargarDisponibilidad();
    _cargarMaxComensales();
    _cargarReservas();
    _loadRestaurante();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _tabController.dispose();
    _dateScrollController.dispose();
    _nombreController.dispose();
    _notasController.dispose();
    super.dispose();
  }

  // ── Selección de sucursal ─────────────────────────────────────────────────

  Future<void> _loadRestaurante() async {
    try {
      final prov = context.read<RestauranteProvider>();
      if (prov.restaurantes.isEmpty) await prov.cargar();
      if (!mounted) return;

      final cartRid = context.read<CartProvider>().restauranteId;
      final activas = prov.restaurantes.where((r) => r.activo).toList();
      if (activas.isEmpty) return;

      Restaurante? elegida;
      if (cartRid != null) {
        final matches = activas.where((r) => r.id == cartRid);
        if (matches.isNotEmpty) elegida = matches.first;
      }
      elegida ??= activas.first;

      setState(() => _restaurante = elegida);
      _cargarMaxComensales();
      _cargarDisponibilidad();
    } catch (e) {
      if (mounted) handleApiError(context, e, prefix: 'Error al cargar sucursales');
    }
  }

  Future<void> _cambiarSucursal(Restaurante nueva) async {
    if (_restaurante?.id == nueva.id) return;
    final cart = context.read<CartProvider>();
    final cartRid = cart.restauranteId;
    if (cartRid != null && cartRid != nueva.id && cart.itemCount > 0) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          backgroundColor: AppColors.panel,
          title: const Text(
            'Cambiar de restaurante',
            style: TextStyle(color: Colors.white),
          ),
          content: Text(
            'Tu pedido en curso es de otro restaurante. '
            'Si reservas en "${nueva.nombre}", tu pedido seguirá en su sitio '
            '(no se borrará). ¿Continuar?',
            style: const TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text(
                'Cancelar',
                style: TextStyle(color: Colors.white60),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text(
                'Cambiar',
                style: TextStyle(color: AppColors.primary),
              ),
            ),
          ],
        ),
      );
      if (ok != true || !mounted) return;
    }
    setState(() => _restaurante = nueva);
    _cargarMaxComensales();
    _cargarDisponibilidad();
  }

  // Con horariosDia los slots ya están definidos por turno (comida/cena),
  // no hay filtrado adicional por rango: todos los slots del turno son válidos.
  bool _horaEnRango(TimeOfDay t) => true;

  List<TimeOfDay> _horasFiltradas(String turno) =>
      _horasPorTurno[turno]!.where(_horaEnRango).toList();

  String _hora(TimeOfDay t) => ru.formateoHora(t);
  String _fechaLarga(DateTime d) => ru.fechaLarga(d);

  void _scrollToFechaSeleccionada({bool animate = true}) {
    final index = _fechas.indexWhere(
      (d) => ru.mismaFecha(d, _fechaSeleccionada),
    );
    if (index < 0 || !_dateScrollController.hasClients) return;
    final offset = (index * FechaStrip.kItemWidth).clamp(
      0.0,
      _dateScrollController.position.maxScrollExtent,
    );
    if (animate) {
      _dateScrollController.animateTo(
        offset,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOut,
      );
    } else {
      _dateScrollController.jumpTo(offset);
    }
  }

  // ── Lógica ──────────────────────────────────────────────────────

  Future<void> _cargarMaxComensales() async {
    try {
      final rid = _restaurante?.id;
      if (rid == null) return;
      final mesas = await ApiService.obtenerMesas(restauranteId: rid);
      if (mesas.isNotEmpty && mounted) {
        setState(
          () => _maxComensales = mesas
              .map((m) => m.capacidad)
              .reduce((a, b) => a > b ? a : b),
        );
      }
    } catch (e) {
      if (mounted) handleApiError(context, e, prefix: 'Error al cargar aforo');
    }
  }

  Future<void> _cargarDisponibilidad() async {
    setState(() => _cargandoDisponibilidad = true);
    final horas = _horasFiltradas(_turnoSeleccionado);
    final resultado = <String, bool>{};
    final rid = _restaurante?.id;
    for (final h in horas) {
      resultado[_hora(h)] = await ApiService.hayDisponibilidad(
        fecha: _fechaSeleccionada,
        hora: _hora(h),
        comensales: _numComensales,
        restauranteId: rid,
      );
    }
    if (!mounted) return;
    setState(() {
      _disponibilidadHoras = resultado;
      _cargandoDisponibilidad = false;
      _autoSeleccionarHoraLibre();
    });
  }

  void _autoSeleccionarHoraLibre() {
    final horas = _horasFiltradas(_turnoSeleccionado);
    if (horas.isEmpty) return;
    if (!horas.contains(_horaSeleccionada) ||
        !(_disponibilidadHoras[_hora(_horaSeleccionada)] ?? true)) {
      for (final h in horas) {
        if (_disponibilidadHoras[_hora(h)] ?? true) {
          _horaSeleccionada = h;
          return;
        }
      }
    }
  }

  void _seleccionarFecha(DateTime fecha) {
    HapticFeedback.selectionClick();
    setState(() => _fechaSeleccionada = fecha);
    _cargarDisponibilidad();
    _scrollToFechaSeleccionada();
  }

  void _cambiarTurno(String turno) {
    if (_turnoSeleccionado == turno) return;
    setState(() {
      _turnoSeleccionado = turno;
      final filtradas = _horasFiltradas(turno);
      _horaSeleccionada = filtradas.isNotEmpty
          ? filtradas.first
          : _horasPorTurno[turno]!.first;
    });
    _cargarDisponibilidad();
  }

  void _cambiarComensales(int delta) {
    final nuevo = _numComensales + delta;
    if (nuevo < 1 || nuevo > _maxComensales) return;
    HapticFeedback.selectionClick();
    setState(() => _numComensales = nuevo);
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 600), _cargarDisponibilidad);
  }

  Future<void> _confirmarReserva() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final restauranteId = context.read<CartProvider>().restauranteId;
      final resultado = await ApiService.crearReserva(
        userId: auth.usuarioActual?.id ?? '',
        nombreCompleto: _nombreController.text.trim(),
        fecha: _fechaSeleccionada,
        hora: _hora(_horaSeleccionada),
        comensales: _numComensales,
        turno: _turnoSeleccionado,
        notas: _notasController.text.trim().isNotEmpty
            ? _notasController.text.trim()
            : null,
        restauranteId: restauranteId,
      );
      if (!mounted) return;
      _mostrarConfirmacion(resultado);
    } catch (e) {
      if (!mounted) return;
      _snack(e.toString().replaceAll('Exception: ', ''), error: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _cargarReservas() async {
    setState(() => _cargandoReservas = true);
    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final r = await ApiService.obtenerReservas(
        userId: auth.usuarioActual?.id ?? '',
      );
      if (!mounted) return;
      setState(() => _misReservas = r);
    } catch (e) {
      if (!mounted) return;
      _snack(e.toString().replaceAll('Exception: ', ''), error: true);
    } finally {
      if (mounted) setState(() => _cargandoReservas = false);
    }
  }

  Future<bool> _confirmarEliminar(Reserva reserva) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.panel,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          '¿Cancelar reserva?',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          '${_fechaLarga(reserva.fecha)} · ${reserva.hora}',
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text(
              'MANTENER',
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
    if (ok != true) return false;
    try {
      await ApiService.eliminarReserva(reservaId: reserva.id);
      if (!mounted) return false;
      setState(() => _misReservas.remove(reserva));
      _snack('Reserva cancelada');
      return true;
    } catch (e) {
      if (!mounted) return false;
      _snack(e.toString().replaceAll('Exception: ', ''), error: true);
      return false;
    }
  }

  bool _puedeEditar(DateTime fecha) {
    final hoy = DateTime(
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day,
    );
    return fecha.difference(hoy).inDays > 1;
  }

  bool _puedeEliminar(DateTime fecha) {
    final hoy = DateTime(
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day,
    );
    return !fecha.isBefore(hoy);
  }

  Future<void> _editarComensales(Reserva reserva) async {
    int editados = reserva.comensales;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          backgroundColor: AppColors.panel,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            'Editar comensales',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.bold,
              fontFamily: 'Playfair Display',
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _fechaLarga(reserva.fecha),
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  BotonDialogo(
                    icono: Icons.remove,
                    onTap: () => setDlg(() => editados--),
                    activo: editados > 1,
                  ),
                  const SizedBox(width: 24),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 180),
                    transitionBuilder: (child, anim) =>
                        ScaleTransition(scale: anim, child: child),
                    child: Column(
                      key: ValueKey(editados),
                      children: [
                        Text(
                          '$editados',
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 36,
                            fontWeight: FontWeight.bold,
                            height: 1,
                          ),
                        ),
                        Text(
                          editados == 1 ? 'persona' : 'personas',
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 24),
                  BotonDialogo(
                    icono: Icons.add,
                    onTap: () => setDlg(() => editados++),
                    activo: editados < _maxComensales,
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text(
                'CANCELAR',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text(
                'GUARDAR',
                style: TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );

    if (ok != true || editados == reserva.comensales) return;

    try {
      final exito = await ApiService.actualizarComensales(
        reservaId: reserva.id,
        comensales: editados,
      );
      if (exito && mounted) {
        setState(() {
          final i = _misReservas.indexOf(reserva);
          if (i >= 0) _misReservas[i] = reserva.copyWith(comensales: editados);
        });
        _snack('Reserva actualizada');
      }
    } catch (e) {
      if (mounted) {
        _snack(e.toString().replaceAll('Exception: ', ''), error: true);
      }
    }
  }

  void _mostrarConfirmacion(Reserva r) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => ConfirmacionSheet(
        reserva: r,
        turno: _turnoSeleccionado,
        fechaLarga: ru.fechaLarga(_fechaSeleccionada),
        onVerReservas: () {
          Navigator.pop(context);
          _tabController.animateTo(1);
          _cargarReservas();
        },
      ),
    );
  }

  void _snack(String msg, {bool error = false}) {
    if (error) {
      showAppError(context, msg);
    } else {
      showAppSuccess(context, msg);
    }
  }

  // ═══════════════════════════════════════════════════════════════
  //  BUILD
  // ═══════════════════════════════════════════════════════════════

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
              color: AppColors.shadow.withValues(alpha: 0.88),
            ),
          ),
          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: _kMaxContentWidth),
                child: Column(
                  children: [
                    const ReservaAppBar(),
                    SelectorSucursalPill(
                      restauranteSeleccionado: _restaurante,
                      onCambiarSucursal: _cambiarSucursal,
                      maxContentWidth: _kMaxContentWidth,
                    ),
                    ReservaTabBar(tabController: _tabController),
                    Expanded(
                      child: TabBarView(
                        controller: _tabController,
                        children: [
                          _buildTabNuevaReserva(),
                          _buildTabMisReservas(),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── TAB 1: Nueva reserva ─────────────────────────────────────────

  Widget _buildTabNuevaReserva() {
    return Stack(
      children: [
        Form(
          key: _formKey,
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.only(bottom: 150),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 22),
                FechaStrip(
                  fechas: _fechas,
                  fechaSeleccionada: _fechaSeleccionada,
                  scrollController: _dateScrollController,
                  onFechaSeleccionada: _seleccionarFecha,
                ),
                const SizedBox(height: 28),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TurnoToggle(
                        turnoSeleccionado: _turnoSeleccionado,
                        onCambiarTurno: _cambiarTurno,
                      ),
                      const SizedBox(height: 28),
                      const SeccionLabel('HORA'),
                      SlotsHora(
                        cargandoDisponibilidad: _cargandoDisponibilidad,
                        slotsFiltrados: _horasFiltradas(_turnoSeleccionado),
                        disponibilidadHoras: _disponibilidadHoras,
                        horaSeleccionada: _horaSeleccionada,
                        onHoraSeleccionada: (h) =>
                            setState(() => _horaSeleccionada = h),
                      ),
                      const SizedBox(height: 28),
                      const SeccionLabel('COMENSALES'),
                      ContadorComensales(
                        numComensales: _numComensales,
                        maxComensales: _maxComensales,
                        onCambiar: _cambiarComensales,
                      ),
                      const SizedBox(height: 28),
                      const SeccionLabel('NOMBRE'),
                      CampoTextoReserva(
                        controller: _nombreController,
                        hint: 'Nombre completo',
                        icono: Icons.person_outline,
                        capitalizacion: TextCapitalization.words,
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'El nombre es obligatorio'
                            : null,
                      ),
                      const SizedBox(height: 20),
                      const SeccionLabel('NOTAS ESPECIALES'),
                      CampoTextoReserva(
                        controller: _notasController,
                        hint:
                            'Alergias, celebración, silla para niños… (opcional)',
                        icono: Icons.note_outlined,
                        maxLines: 3,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: BarraConfirmar(
            fechaSeleccionada: _fechaSeleccionada,
            horaSeleccionada: _horaSeleccionada,
            numComensales: _numComensales,
            isLoading: _isLoading,
            onConfirmar: _confirmarReserva,
          ),
        ),
      ],
    );
  }

  // ── TAB 2: Mis reservas ──────────────────────────────────────────

  Widget _buildTabMisReservas() {
    if (_cargandoReservas) return const SkeletonReservas();

    final ahora = DateTime.now();
    final hoy = DateTime(ahora.year, ahora.month, ahora.day);

    final proximas = _misReservas
        .where((r) => !r.fecha.isBefore(hoy))
        .toList()
      ..sort((a, b) => a.fecha.compareTo(b.fecha));
    final pasadas = _misReservas
        .where((r) => r.fecha.isBefore(hoy))
        .toList()
      ..sort((a, b) => b.fecha.compareTo(a.fecha));

    if (_misReservas.isEmpty) {
      return EstadoVacioReservas(
        onReservarAhora: () => _tabController.animateTo(0),
      );
    }

    return RefreshIndicator(
      onRefresh: _cargarReservas,
      color: AppColors.primary,
      backgroundColor: AppColors.panel,
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          if (proximas.isNotEmpty) ...[
            EncabezadoGrupo(titulo: 'PRÓXIMAS', count: proximas.length),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (_, i) => TarjetaDismissible(
                    reserva: proximas[i],
                    pasada: false,
                    puedeEliminar: _puedeEliminar(proximas[i].fecha),
                    puedeEditar: _puedeEditar(proximas[i].fecha),
                    onConfirmarEliminar: () =>
                        _confirmarEliminar(proximas[i]),
                    onEditarComensales: () =>
                        _editarComensales(proximas[i]),
                  ),
                  childCount: proximas.length,
                ),
              ),
            ),
          ],
          if (pasadas.isNotEmpty) ...[
            EncabezadoGrupo(titulo: 'HISTORIAL', count: pasadas.length),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (_, i) => TarjetaDismissible(
                    reserva: pasadas[i],
                    pasada: true,
                    puedeEliminar: _puedeEliminar(pasadas[i].fecha),
                    puedeEditar: _puedeEditar(pasadas[i].fecha),
                    onConfirmarEliminar: () => _confirmarEliminar(pasadas[i]),
                    onEditarComensales: () => _editarComensales(pasadas[i]),
                  ),
                  childCount: pasadas.length,
                ),
              ),
            ),
          ],
          const SliverToBoxAdapter(child: SizedBox(height: 30)),
        ],
      ),
    );
  }
}

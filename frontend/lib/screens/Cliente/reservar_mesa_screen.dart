import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../core/app_snackbar.dart';
import '../../core/colors_style.dart';
import '../../models/reserva_model.dart';
import '../../models/restaurante_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/cart_provider.dart';
import '../../providers/restaurante_provider.dart';
import '../../services/api_service.dart';
import '../../components/Cliente/reservar_mesa/confirmacion_sheet.dart';
import '../../components/Cliente/reservar_mesa/opcion_sucursal.dart';
import '../../components/Cliente/reservar_mesa/skeleton_reservas.dart';
import '../../components/Cliente/reservar_mesa/utils.dart' as ru;
import 'perfil_screen.dart';

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

  static const double _dateItemWidth = 64.0;

  /// Ancho máximo del contenido. En móvil (<720px) se usa todo el ancho;
  /// en web/desktop el contenido se centra para no estirarse a 1920px y
  /// quedar absurdo. 720 es un compromiso: cabe la app sin sentirse
  /// estrecha y queda elegante con márgenes en pantalla grande.
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

  /// Carga inicial: pide al provider la lista y preselecciona la del carrito
  /// si existe; si no, la primera activa.
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
      // Recalcular máximo de comensales y disponibilidad ya con la sucursal.
      _cargarMaxComensales();
      _cargarDisponibilidad();
    } catch (e) {
      debugPrint('$e');
    }
  }

  /// Cambio explícito de sucursal desde el selector. Si el cliente tiene
  /// productos en el carrito de OTRA sucursal, le avisamos antes de
  /// permitir el cambio (no vaciamos el carrito automáticamente — se respeta
  /// el flujo de pedido si quiere seguir con él en su restaurante).
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
                style: TextStyle(color: AppColors.button),
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

  bool _horaEnRango(TimeOfDay t) {
    final r = _restaurante;
    if (r?.horarioApertura == null || r?.horarioCierre == null) return true;
    final mins = t.hour * 60 + t.minute;
    final apertura = ru.parseMins(r!.horarioApertura!);
    final cierre = ru.parseMins(r.horarioCierre!);
    if (cierre > apertura) {
      return mins >= apertura && mins < cierre;
    } else {
      return mins >= apertura || mins < cierre;
    }
  }

  List<TimeOfDay> _horasFiltradas(String turno) =>
      _horasPorTurno[turno]!.where(_horaEnRango).toList();

  // Pequeños wrappers locales sobre ru.* para no tener que hacer search-and-
  // replace en todas las referencias del archivo. Mantienen el método como
  // miembro de la clase pero delegan en el módulo de utilidades.
  String _hora(TimeOfDay t) => ru.formateoHora(t);
  String _fechaLarga(DateTime d) => ru.fechaLarga(d);
  bool _mismaFecha(DateTime a, DateTime b) => ru.mismaFecha(a, b);
  bool _esHoy(DateTime d) => ru.esHoy(d);

  void _scrollToFechaSeleccionada({bool animate = true}) {
    final index = _fechas.indexWhere((d) => _mismaFecha(d, _fechaSeleccionada));
    if (index < 0 || !_dateScrollController.hasClients) return;
    final offset = (index * _dateItemWidth).clamp(
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

  // ── Lógica ──
  Future<void> _cargarMaxComensales() async {
    try {
      // Solo nos interesa el aforo de la sucursal elegida (no de todo el
      // grupo). Si aún no hay seleccionada, no podemos saberlo.
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
      debugPrint('$e');
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
        // Filtra contra reservas y mesas SOLO de la sucursal elegida.
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
    HapticFeedback.selectionClick();
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

  /// La reserva se puede editar si falta más de 1 día para su fecha.
  bool _puedeEditar(DateTime fecha) {
    final hoy = DateTime(
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day,
    );
    return fecha.difference(hoy).inDays > 1;
  }

  /// La reserva se puede eliminar si su fecha no ha pasado (hoy incluido).
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
                  _botonDialogo(
                    Icons.remove,
                    () => setDlg(() => editados--),
                    editados > 1,
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
                  _botonDialogo(
                    Icons.add,
                    () => setDlg(() => editados++),
                    editados < _maxComensales,
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
                  color: AppColors.button,
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

  Widget _botonDialogo(IconData icono, VoidCallback onTap, bool activo) {
    return GestureDetector(
      onTap: activo ? onTap : null,
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: activo
              ? AppColors.button.withValues(alpha: 0.1)
              : Colors.transparent,
          border: Border.all(color: activo ? AppColors.button : AppColors.line),
        ),
        child: Icon(
          icono,
          color: activo ? AppColors.button : AppColors.line,
          size: 20,
        ),
      ),
    );
  }

  void _mostrarConfirmacion(Reserva r) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => ConfirmacionSheet(
        reserva: r,
        turno: _turnoSeleccionado,
        fechaLarga: _fechaLarga(_fechaSeleccionada),
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
            child: Container(color: AppColors.shadow.withValues(alpha: 0.88)),
          ),
          SafeArea(
            // Centrar y limitar el ancho. En móvil (≤720) se ocupa todo,
            // en web/desktop el contenido se queda en 720 px con la imagen
            // de fondo extendiéndose detrás a todo el viewport.
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: _kMaxContentWidth),
                child: Column(
                  children: [
                    _buildAppBar(),
                    _buildSelectorSucursal(),
                    _buildTabBar(),
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

  /// Cabecera unificada: back + título Playfair + perfil. Justo debajo, un
  /// "selector" tipo pill clicable con la sucursal actual; al pulsarlo se
  /// abre un bottom sheet con las sucursales activas (cuando hay más de una).
  Widget _buildAppBar() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
          child: Row(
            children: [
              IconButton(
                tooltip: 'Volver',
                icon: const Icon(
                  Icons.arrow_back_ios_new,
                  color: Colors.white,
                  size: 20,
                ),
                onPressed: () => Navigator.pop(context),
              ),
              const Spacer(),
              IconButton(
                tooltip: 'Mi perfil',
                icon: const Icon(
                  Icons.person_outline,
                  color: Colors.white,
                  size: 24,
                ),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const PerfilScreen()),
                ),
              ),
            ],
          ),
        ),
        // Eyebrow + título Playfair + filete burdeos.
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 6),
          child: Column(
            children: [
              Text(
                'RESTAURANTE BRAVO',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.55),
                  fontSize: 10,
                  letterSpacing: 4,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Reservar mesa',
                style: GoogleFonts.playfairDisplay(
                  color: Colors.white,
                  fontSize: 30,
                  fontWeight: FontWeight.w700,
                  height: 1.05,
                ),
              ),
              const SizedBox(height: 8),
              Container(width: 28, height: 2, color: AppColors.button),
            ],
          ),
        ),
      ],
    );
  }

  /// Píldora con la sucursal actual. Si hay más de una activa, al tocarla
  /// se abre un bottom sheet para elegir; si solo hay una, es informativa.
  Widget _buildSelectorSucursal() {
    return Consumer<RestauranteProvider>(
      builder: (_, prov, _) {
        final activas = prov.restaurantes.where((r) => r.activo).toList();
        if (prov.cargando && activas.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 14),
            child: SizedBox(
              height: 18,
              width: 18,
              child: CircularProgressIndicator(
                color: AppColors.button,
                strokeWidth: 2,
              ),
            ),
          );
        }
        if (_restaurante == null) return const SizedBox(height: 14);

        final clicable = activas.length > 1;
        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 14, 24, 4),
          child: Center(
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(24),
                onTap: clicable ? () => _abrirSelectorSucursal(activas) : null,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 9,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.07),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.18),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.storefront_rounded,
                        color: AppColors.button,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _restaurante!.nombre,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.4,
                        ),
                      ),
                      if (clicable) ...[
                        const SizedBox(width: 6),
                        Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: Colors.white.withValues(alpha: 0.7),
                          size: 18,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  /// Bottom sheet con la lista de sucursales activas. Pulsar una llama a
  /// [_cambiarSucursal] (que pide confirmación si hay carrito de otra).
  Future<void> _abrirSelectorSucursal(List<Restaurante> activas) async {
    HapticFeedback.selectionClick();
    final elegida = await showModalBottomSheet<Restaurante>(
      context: context,
      backgroundColor: AppColors.panel,
      // En web el bottom sheet se centra y limita al mismo ancho que el
      // contenido principal, para mantener coherencia visual.
      constraints: const BoxConstraints(maxWidth: _kMaxContentWidth),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.line,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'Elige restaurante',
                style: GoogleFonts.playfairDisplay(
                  color: AppColors.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Tu reserva se hará en el local que elijas',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 16),
              ...activas.map((r) {
                final activa = r.id == _restaurante?.id;
                return OpcionSucursal(
                  restaurante: r,
                  activa: activa,
                  onTap: () => Navigator.pop(ctx, r),
                );
              }),
            ],
          ),
        ),
      ),
    );
    if (elegida != null) await _cambiarSucursal(elegida);
  }

  /// Segmented control en píldora — más coherente con la estética que un
  /// `TabBar` por defecto. El `TabController` sigue siendo el mismo para no
  /// romper la lógica del resto del archivo.
  Widget _buildTabBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 18, 24, 14),
      child: AnimatedBuilder(
        animation: _tabController,
        builder: (_, _) {
          final i = _tabController.index;
          return Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
            ),
            child: Row(
              children: [
                _segmentoTab(
                  'NUEVA RESERVA',
                  activo: i == 0,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    _tabController.animateTo(0);
                  },
                ),
                _segmentoTab(
                  'MIS RESERVAS',
                  activo: i == 1,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    _tabController.animateTo(1);
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _segmentoTab(
    String label, {
    required bool activo,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          height: 38,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: activo ? AppColors.button : Colors.transparent,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: activo ? Colors.white : Colors.white60,
              fontSize: 11,
              fontWeight: activo ? FontWeight.w800 : FontWeight.w600,
              letterSpacing: 1.6,
            ),
          ),
        ),
      ),
    );
  }

  // ── TAB 1 ──────────────────────────────────────────────────────
  Widget _buildTabNuevaReserva() {
    return Stack(
      children: [
        Form(
          key: _formKey,
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            // Espacio para la barra sticky inferior
            padding: const EdgeInsets.only(bottom: 150),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 22),
                _buildFechaStrip(),
                const SizedBox(height: 28),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildTurnoToggle(),
                      const SizedBox(height: 28),
                      _buildSeccion('HORA'),
                      _buildSlotsHora(),
                      const SizedBox(height: 28),
                      _buildSeccion('COMENSALES'),
                      _buildContadorComensales(),
                      const SizedBox(height: 28),
                      _buildSeccion('NOMBRE'),
                      _buildCampoTexto(
                        controller: _nombreController,
                        hint: 'Nombre completo',
                        icono: Icons.person_outline,
                        capitalizacion: TextCapitalization.words,
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'El nombre es obligatorio'
                            : null,
                      ),
                      const SizedBox(height: 20),
                      _buildSeccion('NOTAS ESPECIALES'),
                      _buildCampoTexto(
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
        Positioned(bottom: 0, left: 0, right: 0, child: _buildBarraConfirmar()),
      ],
    );
  }

  // ── Strip de fechas ──
  Widget _buildFechaStrip() {
    return SizedBox(
      height: 92,
      child: ListView.builder(
        controller: _dateScrollController,
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: _fechas.length,
        itemBuilder: (_, i) => _buildDateChip(_fechas[i]),
      ),
    );
  }

  Widget _buildDateChip(DateTime fecha) {
    final seleccionada = _mismaFecha(fecha, _fechaSeleccionada);
    final hoy = _esHoy(fecha);
    final esFinDeSemana = fecha.weekday >= 6; // 6 = sábado, 7 = domingo

    return GestureDetector(
      onTap: () => _seleccionarFecha(fecha),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        width: _dateItemWidth - 4,
        margin: const EdgeInsets.only(right: 6),
        decoration: BoxDecoration(
          color: seleccionada
              ? AppColors.button
              : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: seleccionada
                ? AppColors.button
                : Colors.white.withValues(alpha: 0.12),
            width: seleccionada ? 1.4 : 1,
          ),
          boxShadow: seleccionada
              ? [
                  BoxShadow(
                    color: AppColors.button.withValues(alpha: 0.45),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              hoy ? 'HOY' : ru.kDiasAbrev[fecha.weekday - 1],
              style: TextStyle(
                color: seleccionada
                    ? Colors.white
                    : (esFinDeSemana
                          ? AppColors.button.withValues(alpha: 0.9)
                          : Colors.white60),
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.4,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '${fecha.day}',
              style: GoogleFonts.playfairDisplay(
                color: Colors.white,
                fontSize: 26,
                fontWeight: FontWeight.w700,
                height: 1,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              ru.kMesesAbrev[fecha.month - 1],
              style: TextStyle(
                color: seleccionada
                    ? Colors.white.withValues(alpha: 0.85)
                    : Colors.white54,
                fontSize: 9,
                letterSpacing: 1.2,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Turno toggle ──
  Widget _buildTurnoToggle() {
    return Row(
      children: [
        _buildTurnoSegmento(
          'comida',
          'Comida',
          'De 12:30 a 16:00',
          Icons.wb_sunny_rounded,
        ),
        const SizedBox(width: 12),
        _buildTurnoSegmento(
          'cena',
          'Cena',
          'De 20:00 a 23:30',
          Icons.nightlight_round,
        ),
      ],
    );
  }

  Widget _buildTurnoSegmento(
    String turno,
    String label,
    String horario,
    IconData icono,
  ) {
    final sel = _turnoSeleccionado == turno;
    return Expanded(
      child: GestureDetector(
        onTap: () => _cambiarTurno(turno),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: sel
                ? AppColors.button.withValues(alpha: 0.18)
                : Colors.white.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: sel
                  ? AppColors.button
                  : Colors.white.withValues(alpha: 0.12),
              width: sel ? 1.4 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: sel
                      ? AppColors.button
                      : Colors.white.withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icono,
                  color: sel ? Colors.white : Colors.white60,
                  size: 16,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                label,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: sel ? FontWeight.w800 : FontWeight.w600,
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                horario,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: sel ? 0.7 : 0.45),
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Sección label ──
  Widget _buildSeccion(String titulo) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          titulo,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 2.5,
          ),
        ),
        const SizedBox(height: 5),
        Container(height: 2, width: 24, color: AppColors.button),
        const SizedBox(height: 14),
      ],
    );
  }

  // ── Slots de hora ──
  Widget _buildSlotsHora() {
    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = 10.0;
        const columns = 4;
        final slotWidth =
            (constraints.maxWidth - spacing * (columns - 1)) / columns;
        final fontSize = (slotWidth * 0.2).clamp(11.0, 15.0);

        if (_cargandoDisponibilidad) {
          return const SizedBox(
            height: 54,
            child: Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  color: AppColors.button,
                  strokeWidth: 2.5,
                ),
              ),
            ),
          );
        }

        final slotsFiltrados = _horasFiltradas(_turnoSeleccionado);

        if (slotsFiltrados.isEmpty) {
          return Container(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white10),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.schedule_outlined,
                  color: Colors.white38,
                  size: 16,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _restaurante?.horarioApertura != null
                        ? 'El restaurante no tiene horario de ${_turnoSeleccionado == 'comida' ? 'comida' : 'cena'} · Abre ${_restaurante!.horarioApertura} – ${_restaurante!.horarioCierre}'
                        : 'No hay horarios disponibles para este turno',
                    style: const TextStyle(color: Colors.white38, fontSize: 12),
                  ),
                ),
              ],
            ),
          );
        }

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: slotsFiltrados.map((hora) {
            final horaStr = _hora(hora);
            final disponible = _disponibilidadHoras[horaStr] ?? true;
            final sel = hora == _horaSeleccionada && disponible;
            return GestureDetector(
              onTap: disponible
                  ? () {
                      HapticFeedback.selectionClick();
                      setState(() => _horaSeleccionada = hora);
                    }
                  : null,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: slotWidth,
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: sel
                      ? AppColors.button
                      : disponible
                      ? AppColors.panel.withValues(alpha: 0.9)
                      : Colors.white.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: sel
                        ? AppColors.button
                        : disponible
                        ? Colors.white24
                        : Colors.white10,
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      horaStr,
                      style: TextStyle(
                        color: sel
                            ? Colors.white
                            : disponible
                            ? AppColors.textPrimary
                            : Colors.white24,
                        fontWeight: FontWeight.bold,
                        fontSize: fontSize + 2,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      disponible ? (sel ? '✓ Elegida' : 'Libre') : 'Completo',
                      style: TextStyle(
                        color: sel
                            ? Colors.white70
                            : disponible
                            ? AppColors.disp
                            : AppColors.error,
                        fontSize: fontSize,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  // ── Contador comensales ──
  Widget _buildContadorComensales() {
    final puedeRestar = _numComensales > 1;
    final puedeSumar = _numComensales < _maxComensales;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Row(
        children: [
          _botonComensales(
            Icons.remove_rounded,
            () => _cambiarComensales(-1),
            puedeRestar,
          ),
          Expanded(
            child: Column(
              children: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  transitionBuilder: (child, anim) => FadeTransition(
                    opacity: anim,
                    child: ScaleTransition(scale: anim, child: child),
                  ),
                  child: Text(
                    '$_numComensales',
                    key: ValueKey(_numComensales),
                    style: GoogleFonts.playfairDisplay(
                      color: Colors.white,
                      fontSize: 44,
                      fontWeight: FontWeight.w700,
                      height: 1,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _numComensales == 1
                      ? 'persona'
                      : '$_numComensales personas'.split(' ').last,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.55),
                    fontSize: 11,
                    letterSpacing: 1.4,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          _botonComensales(
            Icons.add_rounded,
            () => _cambiarComensales(1),
            puedeSumar,
          ),
        ],
      ),
    );
  }

  Widget _botonComensales(IconData icono, VoidCallback onTap, bool activo) {
    return GestureDetector(
      onTap: activo ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: activo
              ? AppColors.button
              : Colors.white.withValues(alpha: 0.04),
          border: Border.all(
            color: activo
                ? AppColors.button
                : Colors.white.withValues(alpha: 0.15),
          ),
        ),
        child: Icon(
          icono,
          color: activo ? Colors.white : Colors.white24,
          size: 22,
        ),
      ),
    );
  }

  // ── Campos de texto ──
  Widget _buildCampoTexto({
    required TextEditingController controller,
    required String hint,
    required IconData icono,
    int maxLines = 1,
    TextCapitalization capitalizacion = TextCapitalization.none,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      textCapitalization: capitalizacion,
      validator: validator,
      style: const TextStyle(color: AppColors.textPrimary, fontSize: 15),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(
          color: AppColors.textSecondary.withValues(alpha: 0.55),
          fontSize: 14,
        ),
        prefixIcon: maxLines == 1
            ? Icon(icono, color: AppColors.button, size: 20)
            : null,
        contentPadding: EdgeInsets.symmetric(
          horizontal: maxLines > 1 ? 16 : 0,
          vertical: 14,
        ),
        filled: true,
        fillColor: AppColors.panel.withValues(alpha: 0.92),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.white24),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.button, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.error, width: 2),
        ),
        errorStyle: const TextStyle(color: AppColors.error),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  // ── Barra inferior sticky ──
  Widget _buildBarraConfirmar() {
    final diaTexto =
        '${ru.kDiasAbrev[_fechaSeleccionada.weekday - 1]} '
        '${_fechaSeleccionada.day} ${ru.kMesesAbrev[_fechaSeleccionada.month - 1]}';

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.transparent,
            Colors.black.withValues(alpha: 0.6),
            Colors.black.withValues(alpha: 0.97),
          ],
          stops: const [0.0, 0.18, 1.0],
        ),
      ),
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Resumen unificado: una sola tarjeta con los 4 datos. Más legible
          // y más coherente que la fila de chips dispares anterior.
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _datoResumen(
                    icono: Icons.calendar_today_rounded,
                    texto: diaTexto,
                  ),
                ),
                _separador(),
                Expanded(
                  child: _datoResumen(
                    icono: Icons.access_time_rounded,
                    texto: _hora(_horaSeleccionada),
                  ),
                ),
                _separador(),
                Expanded(
                  child: _datoResumen(
                    icono: Icons.people_rounded,
                    texto: '$_numComensales',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton.icon(
              onPressed: _isLoading ? null : _confirmarReserva,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.button,
                foregroundColor: Colors.white,
                disabledBackgroundColor: AppColors.button.withValues(
                  alpha: 0.5,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 0,
              ),
              icon: _isLoading
                  ? const SizedBox.shrink()
                  : const Icon(Icons.check_circle_outline_rounded, size: 18),
              label: _isLoading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2.5,
                      ),
                    )
                  : const Text(
                      'CONFIRMAR RESERVA',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        letterSpacing: 2,
                        fontSize: 13,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _datoResumen({required IconData icono, required String texto}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icono, color: AppColors.button, size: 14),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            texto,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3,
            ),
          ),
        ),
      ],
    );
  }

  Widget _separador() => Container(
    width: 1,
    height: 22,
    color: Colors.white.withValues(alpha: 0.12),
  );

  // ── TAB 2: Mis reservas ───────────────────────────────────────
  Widget _buildTabMisReservas() {
    if (_cargandoReservas) {
      return const SkeletonReservas();
    }

    final ahora = DateTime.now();
    final proximas =
        _misReservas
            .where(
              (r) => !r.fecha.isBefore(
                DateTime(ahora.year, ahora.month, ahora.day),
              ),
            )
            .toList()
          ..sort((a, b) => a.fecha.compareTo(b.fecha));
    final pasadas =
        _misReservas
            .where(
              (r) => r.fecha.isBefore(
                DateTime(ahora.year, ahora.month, ahora.day),
              ),
            )
            .toList()
          ..sort((a, b) => b.fecha.compareTo(a.fecha));

    if (_misReservas.isEmpty) {
      return _buildEstadoVacio();
    }

    return RefreshIndicator(
      onRefresh: _cargarReservas,
      color: AppColors.button,
      backgroundColor: AppColors.panel,
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          if (proximas.isNotEmpty) ...[
            _buildEncabezadoGrupo('PRÓXIMAS', proximas.length),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (_, i) =>
                      _buildTarjetaDismissible(proximas[i], pasada: false),
                  childCount: proximas.length,
                ),
              ),
            ),
          ],
          if (pasadas.isNotEmpty) ...[
            _buildEncabezadoGrupo('HISTORIAL', pasadas.length),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (_, i) => _buildTarjetaDismissible(pasadas[i], pasada: true),
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

  Widget _buildEstadoVacio() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 90,
            height: 90,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.06),
              border: Border.all(color: Colors.white12),
            ),
            child: const Icon(
              Icons.calendar_month_outlined,
              color: Colors.white24,
              size: 42,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Sin reservas',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
              fontFamily: 'Playfair Display',
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Haz tu primera reserva en unos segundos',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.5),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 28),
          TextButton(
            onPressed: () => _tabController.animateTo(0),
            child: const Text(
              'RESERVAR AHORA',
              style: TextStyle(
                color: AppColors.button,
                fontWeight: FontWeight.bold,
                letterSpacing: 2,
                fontSize: 13,
                decoration: TextDecoration.underline,
                decorationColor: AppColors.button,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEncabezadoGrupo(String titulo, int count) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
        child: Row(
          children: [
            Text(
              titulo,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 2.5,
              ),
            ),
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.button.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: const TextStyle(
                  color: AppColors.button,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTarjetaDismissible(Reserva reserva, {required bool pasada}) {
    // Las reservas pasadas no se pueden eliminar
    if (!_puedeEliminar(reserva.fecha)) {
      return _buildTarjetaReserva(reserva, pasada: pasada);
    }

    return Dismissible(
      key: Key(reserva.id),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) => _confirmarEliminar(reserva),
      background: Container(
        alignment: Alignment.centerRight,
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.only(right: 24),
        decoration: BoxDecoration(
          color: AppColors.error.withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.delete_outline, color: Colors.white, size: 26),
            SizedBox(height: 4),
            Text(
              'CANCELAR',
              style: TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
      child: _buildTarjetaReserva(reserva, pasada: pasada),
    );
  }

  Widget _buildTarjetaReserva(Reserva reserva, {required bool pasada}) {
    final esCena = reserva.turno == 'cena';
    final colorEstado = _colorEstado(reserva.estado);

    return Opacity(
      opacity: pasada ? 0.55 : 1.0,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: AppColors.panel.withValues(alpha: pasada ? 0.8 : 0.96),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: pasada ? Colors.white10 : Colors.white24),
        ),
        child: IntrinsicHeight(
          child: Row(
            children: [
              // ── Columna fecha ──
              Container(
                width: 70,
                decoration: BoxDecoration(
                  color: pasada
                      ? AppColors.line.withValues(alpha: 0.5)
                      : AppColors.button.withValues(alpha: 0.08),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(14),
                    bottomLeft: Radius.circular(14),
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '${reserva.fecha.day}',
                      style: TextStyle(
                        color: pasada
                            ? AppColors.textSecondary
                            : AppColors.button,
                        fontSize: 30,
                        fontWeight: FontWeight.bold,
                        height: 1,
                      ),
                    ),
                    Text(
                      ru.kMesesAbrev[reserva.fecha.month - 1],
                      style: TextStyle(
                        color: pasada
                            ? AppColors.textSecondary
                            : AppColors.button,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      ru.kDiasAbrev[reserva.fecha.weekday - 1],
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
              // ── Detalles ──
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 14, 12, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          _badgeSmall(
                            esCena ? 'Cena' : 'Comida',
                            esCena
                                ? Icons.nightlight_outlined
                                : Icons.wb_sunny_outlined,
                            esCena ? Colors.indigo : Colors.orange,
                          ),
                          const SizedBox(width: 6),
                          _badgeSmall(
                            reserva.estado,
                            Icons.circle,
                            colorEstado,
                          ),
                          const Spacer(),
                          if (_puedeEditar(reserva.fecha))
                            GestureDetector(
                              onTap: () => _editarComensales(reserva),
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: AppColors.button.withValues(
                                    alpha: 0.1,
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: AppColors.button.withValues(
                                      alpha: 0.3,
                                    ),
                                  ),
                                ),
                                child: const Icon(
                                  Icons.group_outlined,
                                  color: AppColors.button,
                                  size: 16,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          const Icon(
                            Icons.access_time,
                            size: 14,
                            color: AppColors.textSecondary,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            reserva.hora,
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(width: 16),
                          const Icon(
                            Icons.people_outline,
                            size: 14,
                            color: AppColors.textSecondary,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            '${reserva.comensales}',
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(width: 16),
                          const Icon(
                            Icons.table_bar,
                            size: 14,
                            color: AppColors.textSecondary,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            'Mesa ${reserva.numeroMesa ?? "-"}',
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 15,
                            ),
                          ),
                        ],
                      ),
                      if (reserva.notas != null &&
                          reserva.notas!.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(
                              Icons.note_outlined,
                              size: 13,
                              color: AppColors.textSecondary,
                            ),
                            const SizedBox(width: 5),
                            Expanded(
                              child: Text(
                                reserva.notas!,
                                style: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 12,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _badgeSmall(String label, IconData icono, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icono, size: 10, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Color _colorEstado(String estado) {
    switch (estado.toLowerCase()) {
      case 'confirmada':
        return AppColors.disp;
      case 'pendiente':
        return Colors.orange;
      case 'cancelada':
        return AppColors.error;
      default:
        return const Color(0xFF3B82F6);
    }
  }
}

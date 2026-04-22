import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/colors_style.dart';
import '../../models/reserva_model.dart';
import '../../services/api_service.dart';
import '../../providers/auth_provider.dart';
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

  static const double _dateItemWidth = 64.0;

  // ── Constantes de texto ──
  static const _diasAbrev = ['LUN', 'MAR', 'MIÉ', 'JUE', 'VIE', 'SÁB', 'DOM'];
  static const _mesesAbrev = ['ENE', 'FEB', 'MAR', 'ABR', 'MAY', 'JUN',
                               'JUL', 'AGO', 'SEP', 'OCT', 'NOV', 'DIC'];
  static const _mesesCompletos = ['enero', 'febrero', 'marzo', 'abril', 'mayo',
    'junio', 'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre'];
  static const _diasCompletos = ['Lunes', 'Martes', 'Miércoles', 'Jueves',
                                  'Viernes', 'Sábado', 'Domingo'];

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

  // ── Helpers ──
  String _hora(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  String _fechaLarga(DateTime d) =>
      '${_diasCompletos[d.weekday - 1]}, ${d.day} de ${_mesesCompletos[d.month - 1]}';

  bool _mismaFecha(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  bool _esHoy(DateTime d) => _mismaFecha(d, DateTime.now());

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
      final mesas = await ApiService.obtenerMesas();
      if (mesas.isNotEmpty && mounted) {
        setState(() => _maxComensales =
            mesas.map((m) => m.capacidad).reduce((a, b) => a > b ? a : b));
      }
    } catch (_) {}
  }

  Future<void> _cargarDisponibilidad() async {
    setState(() => _cargandoDisponibilidad = true);
    final horas = _horasPorTurno[_turnoSeleccionado]!;
    final resultado = <String, bool>{};
    for (final h in horas) {
      resultado[_hora(h)] = await ApiService.hayDisponibilidad(
        fecha: _fechaSeleccionada,
        hora: _hora(h),
        comensales: _numComensales,
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
    if (!(_disponibilidadHoras[_hora(_horaSeleccionada)] ?? true)) {
      for (final h in _horasPorTurno[_turnoSeleccionado]!) {
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
      _horaSeleccionada = _horasPorTurno[turno]!.first;
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
      final r = await ApiService.obtenerReservas(userId: auth.usuarioActual?.id ?? '');
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
        title: const Text('¿Cancelar reserva?',
            style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
        content: Text(
          '${_fechaLarga(reserva.fecha)} · ${reserva.hora}',
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('MANTENER',
                style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('CANCELAR RESERVA',
                style: TextStyle(color: AppColors.error, fontWeight: FontWeight.bold)),
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
    final hoy = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    return fecha.difference(hoy).inDays > 1;
  }

  /// La reserva se puede eliminar si su fecha no ha pasado (hoy incluido).
  bool _puedeEliminar(DateTime fecha) {
    final hoy = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    return !fecha.isBefore(hoy);
  }

  Future<void> _editarComensales(Reserva reserva) async {
    int editados = reserva.comensales;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          backgroundColor: AppColors.panel,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
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
                              color: AppColors.textSecondary, fontSize: 12),
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
              child: const Text('CANCELAR',
                  style: TextStyle(color: AppColors.textSecondary)),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('GUARDAR',
                  style: TextStyle(
                      color: AppColors.button, fontWeight: FontWeight.bold)),
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
      if (mounted) _snack(e.toString().replaceAll('Exception: ', ''), error: true);
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
          border: Border.all(
              color: activo ? AppColors.button : AppColors.line),
        ),
        child: Icon(icono,
            color: activo ? AppColors.button : AppColors.line, size: 20),
      ),
    );
  }

  void _mostrarConfirmacion(Reserva r) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _ConfirmacionSheet(
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
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: error ? AppColors.error : Colors.green,
      behavior: SnackBarBehavior.floating,
    ));
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
            child: Image.asset('assets/images/Bravo restaurante.jpg', fit: BoxFit.cover),
          ),
          Positioned.fill(
            child: Container(color: AppColors.shadow.withValues(alpha: 0.88)),
          ),
          SafeArea(
            child: Column(
              children: [
                _buildAppBar(),
                _buildTabBar(),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [_buildTabNuevaReserva(), _buildTabMisReservas()],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
            onPressed: () => Navigator.pop(context),
          ),
          const Expanded(
            child: Text(
              'RESERVAR MESA',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                letterSpacing: 2.5,
                fontSize: 15,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.person_outline, color: Colors.white, size: 26),
            onPressed: () => Navigator.push(
                context, MaterialPageRoute(builder: (_) => const PerfilScreen())),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 30),
      child: TabBar(
        controller: _tabController,
        indicatorColor: AppColors.button,
        indicatorWeight: 2,
        labelColor: Colors.white,
        unselectedLabelColor: Colors.white38,
        labelStyle: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.5, fontSize: 13),
        unselectedLabelStyle: const TextStyle(fontSize: 13),
        dividerColor: Colors.white12,
        tabs: const [Tab(text: 'NUEVA RESERVA'), Tab(text: 'MIS RESERVAS')],
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
                        validator: (v) =>
                            (v == null || v.trim().isEmpty) ? 'El nombre es obligatorio' : null,
                      ),
                      const SizedBox(height: 20),
                      _buildSeccion('NOTAS ESPECIALES'),
                      _buildCampoTexto(
                        controller: _notasController,
                        hint: 'Alergias, celebración, silla para niños… (opcional)',
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
          bottom: 0, left: 0, right: 0,
          child: _buildBarraConfirmar(),
        ),
      ],
    );
  }

  // ── Strip de fechas ──
  Widget _buildFechaStrip() {
    return SizedBox(
      height: 82,
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

    return GestureDetector(
      onTap: () => _seleccionarFecha(fecha),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        width: _dateItemWidth - 4,
        margin: const EdgeInsets.only(right: 4),
        decoration: BoxDecoration(
          color: seleccionada
              ? AppColors.button
              : AppColors.panel.withValues(alpha: 0.13),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: seleccionada ? AppColors.button : Colors.white12,
            width: seleccionada ? 2 : 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              hoy ? 'HOY' : _diasAbrev[fecha.weekday - 1],
              style: TextStyle(
                color: seleccionada ? Colors.white70 : Colors.white38,
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${fecha.day}',
              style: TextStyle(
                color: seleccionada ? Colors.white : Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
                height: 1,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              _mesesAbrev[fecha.month - 1],
              style: TextStyle(
                color: seleccionada ? Colors.white60 : Colors.white24,
                fontSize: 10,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Turno toggle ──
  Widget _buildTurnoToggle() {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: AppColors.panel.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        children: [
          _buildTurnoSegmento('comida', 'Comida', Icons.wb_sunny_outlined),
          _buildTurnoSegmento('cena', 'Cena', Icons.nightlight_outlined),
        ],
      ),
    );
  }

  Widget _buildTurnoSegmento(String turno, String label, IconData icono) {
    final sel = _turnoSeleccionado == turno;
    return Expanded(
      child: GestureDetector(
        onTap: () => _cambiarTurno(turno),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: sel ? AppColors.button : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icono, color: sel ? Colors.white : Colors.white38, size: 18),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: sel ? Colors.white : Colors.white38,
                  fontWeight: sel ? FontWeight.bold : FontWeight.normal,
                  fontSize: 14,
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

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: _horasPorTurno[_turnoSeleccionado]!.map((hora) {
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
                                ? Colors.green
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.panel.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white24),
      ),
      child: Row(
        children: [
          _botonComensales(Icons.remove, () => _cambiarComensales(-1), _numComensales > 1),
          const Spacer(),
          Column(
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                transitionBuilder: (child, anim) =>
                    ScaleTransition(scale: anim, child: child),
                child: Text(
                  '$_numComensales',
                  key: ValueKey(_numComensales),
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    height: 1,
                  ),
                ),
              ),
              Text(
                _numComensales == 1 ? 'persona' : 'personas',
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const Spacer(),
          _botonComensales(Icons.add, () => _cambiarComensales(1), _numComensales < _maxComensales),
        ],
      ),
    );
  }

  Widget _botonComensales(IconData icono, VoidCallback onTap, bool activo) {
    return GestureDetector(
      onTap: activo ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: activo
              ? AppColors.button.withValues(alpha: 0.12)
              : Colors.transparent,
          border: Border.all(
            color: activo ? AppColors.button : AppColors.line,
          ),
        ),
        child: Icon(icono,
            color: activo ? AppColors.button : AppColors.line, size: 20),
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
            color: AppColors.textSecondary.withValues(alpha: 0.55), fontSize: 14),
        prefixIcon: maxLines == 1
            ? Icon(icono, color: AppColors.button, size: 20)
            : null,
        contentPadding: EdgeInsets.symmetric(
            horizontal: maxLines > 1 ? 16 : 0, vertical: 14),
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
    final diasSemana = _diasAbrev[_fechaSeleccionada.weekday - 1];
    final dia = _fechaSeleccionada.day;
    final mes = _mesesAbrev[_fechaSeleccionada.month - 1];

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.transparent,
            Colors.black.withValues(alpha: 0.65),
            Colors.black.withValues(alpha: 0.95),
          ],
          stops: const [0.0, 0.25, 1.0],
        ),
      ),
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Chips resumen
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _chipResumen(Icons.calendar_today, '$diasSemana $dia $mes'),
                _chipResumen(
                  _turnoSeleccionado == 'comida' ? Icons.wb_sunny_outlined : Icons.nightlight_outlined,
                  _turnoSeleccionado == 'comida' ? 'Comida' : 'Cena',
                ),
                _chipResumen(Icons.access_time, _hora(_horaSeleccionada)),
                _chipResumen(Icons.people_outline, '$_numComensales pers.'),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _confirmarReserva,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.button,
                foregroundColor: Colors.white,
                disabledBackgroundColor: AppColors.button.withValues(alpha: 0.5),
                shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                elevation: 0,
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 22, height: 22,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                    )
                  : const Text(
                      'CONFIRMAR RESERVA',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2,
                        fontSize: 14,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _chipResumen(IconData icono, String texto) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icono, color: Colors.white60, size: 13),
          const SizedBox(width: 5),
          Text(
            texto,
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ],
      ),
    );
  }

  // ── TAB 2: Mis reservas ───────────────────────────────────────
  Widget _buildTabMisReservas() {
    if (_cargandoReservas) {
      return const _SkeletonReservas();
    }

    final ahora = DateTime.now();
    final proximas = _misReservas
        .where((r) => !r.fecha.isBefore(DateTime(ahora.year, ahora.month, ahora.day)))
        .toList()
      ..sort((a, b) => a.fecha.compareTo(b.fecha));
    final pasadas = _misReservas
        .where((r) => r.fecha.isBefore(DateTime(ahora.year, ahora.month, ahora.day)))
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
                  (_, i) => _buildTarjetaDismissible(proximas[i], pasada: false),
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
            child: const Icon(Icons.calendar_month_outlined,
                color: Colors.white24, size: 42),
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
            style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 14),
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
            Text('CANCELAR', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
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
                        color: pasada ? AppColors.textSecondary : AppColors.button,
                        fontSize: 30,
                        fontWeight: FontWeight.bold,
                        height: 1,
                      ),
                    ),
                    Text(
                      _mesesAbrev[reserva.fecha.month - 1],
                      style: TextStyle(
                        color: pasada ? AppColors.textSecondary : AppColors.button,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _diasAbrev[reserva.fecha.weekday - 1],
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
                            esCena ? Icons.nightlight_outlined : Icons.wb_sunny_outlined,
                            esCena ? Colors.indigo : Colors.orange,
                          ),
                          const SizedBox(width: 6),
                          _badgeSmall(reserva.estado, Icons.circle, colorEstado),
                          const Spacer(),
                          if (_puedeEditar(reserva.fecha))
                            GestureDetector(
                              onTap: () => _editarComensales(reserva),
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: AppColors.button.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                      color: AppColors.button.withValues(alpha: 0.3)),
                                ),
                                child: const Icon(Icons.group_outlined,
                                    color: AppColors.button, size: 16),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          const Icon(Icons.access_time, size: 14, color: AppColors.textSecondary),
                          const SizedBox(width: 5),
                          Text(reserva.hora,
                              style: const TextStyle(
                                  color: AppColors.textPrimary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15)),
                          const SizedBox(width: 16),
                          const Icon(Icons.people_outline, size: 14, color: AppColors.textSecondary),
                          const SizedBox(width: 5),
                          Text('${reserva.comensales}',
                              style: const TextStyle(
                                  color: AppColors.textPrimary, fontSize: 15)),
                          const SizedBox(width: 16),
                          const Icon(Icons.table_bar, size: 14, color: AppColors.textSecondary),
                          const SizedBox(width: 5),
                          Text('Mesa ${reserva.numeroMesa ?? "-"}',
                              style: const TextStyle(
                                  color: AppColors.textPrimary, fontSize: 15)),
                        ],
                      ),
                      if (reserva.notas != null && reserva.notas!.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(Icons.note_outlined,
                                size: 13, color: AppColors.textSecondary),
                            const SizedBox(width: 5),
                            Expanded(
                              child: Text(
                                reserva.notas!,
                                style: const TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 12),
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
          Text(label,
              style: TextStyle(
                  color: color, fontWeight: FontWeight.bold, fontSize: 11)),
        ],
      ),
    );
  }

  Color _colorEstado(String estado) {
    switch (estado.toLowerCase()) {
      case 'confirmada': return Colors.green;
      case 'pendiente':  return Colors.orange;
      case 'cancelada':  return AppColors.error;
      default:           return Colors.blueAccent;
    }
  }
}

// ── Bottom sheet de confirmación ──────────────────────────────────────────────
class _ConfirmacionSheet extends StatelessWidget {
  final Reserva reserva;
  final String turno;
  final String fechaLarga;
  final VoidCallback onVerReservas;

  const _ConfirmacionSheet({
    required this.reserva,
    required this.turno,
    required this.fechaLarga,
    required this.onVerReservas,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.panel,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(28, 12, 28, 36),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40, height: 4,
            decoration: BoxDecoration(
              color: AppColors.line,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),
          Container(
            width: 70, height: 70,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.successBackground,
            ),
            child: const Icon(Icons.check, color: Colors.green, size: 36),
          ),
          const SizedBox(height: 16),
          const Text(
            '¡Reserva Confirmada!',
            style: TextStyle(
              fontFamily: 'Playfair Display',
              color: AppColors.textPrimary,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Te esperamos en Bravo',
            style: TextStyle(color: AppColors.textSecondary.withValues(alpha: 0.8)),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.line),
            ),
            child: Column(
              children: [
                _fila(Icons.calendar_today, fechaLarga),
                const Divider(color: AppColors.line, height: 16),
                _fila(
                  turno == 'comida' ? Icons.wb_sunny_outlined : Icons.nightlight_outlined,
                  turno == 'comida' ? 'Turno de comida' : 'Turno de cena',
                ),
                const Divider(color: AppColors.line, height: 16),
                _fila(Icons.access_time, reserva.hora),
                const Divider(color: AppColors.line, height: 16),
                _fila(Icons.people_outline, '${reserva.comensales} comensales'),
                const Divider(color: AppColors.line, height: 16),
                _fila(Icons.table_bar, 'Mesa ${reserva.numeroMesa ?? "-"}'),
              ],
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton(
              onPressed: onVerReservas,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.button,
                foregroundColor: Colors.white,
                shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                elevation: 0,
              ),
              child: const Text(
                'VER MIS RESERVAS',
                style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 2),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _fila(IconData icono, String texto) {
    return Row(
      children: [
        Icon(icono, color: AppColors.button, size: 18),
        const SizedBox(width: 12),
        Expanded(
          child: Text(texto,
              style: const TextStyle(color: AppColors.textPrimary, fontSize: 14)),
        ),
      ],
    );
  }
}

// ── Skeleton loader para "Mis reservas" ──────────────────────────────────────
class _SkeletonReservas extends StatefulWidget {
  const _SkeletonReservas();

  @override
  State<_SkeletonReservas> createState() => _SkeletonReservasState();
}

class _SkeletonReservasState extends State<_SkeletonReservas>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, _) => CustomScrollView(
        physics: const NeverScrollableScrollPhysics(),
        slivers: [
          // Label "PRÓXIMAS"
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 28, 20, 14),
              child: Row(
                children: [
                  _caja(96, 11),
                  const SizedBox(width: 10),
                  _caja(22, 22, radio: 11),
                ],
              ),
            ),
          ),
          // Tarjetas skeleton
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _tarjeta(notas: false),
                _tarjeta(notas: true),
                _tarjeta(notas: false),
              ]),
            ),
          ),
          // Segunda sección
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 14),
              child: _caja(80, 11),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _tarjeta(notas: false, pasada: true),
                _tarjeta(notas: false, pasada: true),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  /// Caja con pulso dorado
  Widget _caja(double w, double h, {double radio = 6}) {
    final t = Curves.easeInOut.transform(_ctrl.value);
    return Container(
      width: w,
      height: h,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radio),
        color: Color.lerp(
          Colors.white.withValues(alpha: 0.05),
          AppColors.button.withValues(alpha: 0.20),
          t,
        ),
      ),
    );
  }

  Widget _tarjeta({required bool notas, bool pasada = false}) {
    final t = Curves.easeInOut.transform(_ctrl.value);
    final cardColor = Color.lerp(
      AppColors.panel.withValues(alpha: pasada ? 0.40 : 0.55),
      AppColors.panel.withValues(alpha: pasada ? 0.55 : 0.72),
      t,
    )!;
    final colFecha = Color.lerp(
      AppColors.button.withValues(alpha: pasada ? 0.03 : 0.05),
      AppColors.button.withValues(alpha: pasada ? 0.07 : 0.12),
      t,
    )!;

    return Opacity(
      opacity: pasada ? 0.55 : 1.0,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white10),
        ),
        child: IntrinsicHeight(
          child: Row(
            children: [
              // ── Columna fecha ──
              Container(
                width: 70,
                decoration: BoxDecoration(
                  color: colFecha,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(14),
                    bottomLeft: Radius.circular(14),
                  ),
                ),
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _caja(30, 28, radio: 4),
                    const SizedBox(height: 6),
                    _caja(22, 10, radio: 3),
                    const SizedBox(height: 4),
                    _caja(18, 9, radio: 3),
                  ],
                ),
              ),
              // ── Contenido ──
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 14, 12, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          _caja(56, 20, radio: 6),
                          const SizedBox(width: 8),
                          _caja(68, 20, radio: 6),
                        ],
                      ),
                      const SizedBox(height: 10),
                      _caja(double.infinity, 14, radio: 4),
                      if (notas) ...[
                        const SizedBox(height: 8),
                        _caja(120, 11, radio: 4),
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
}

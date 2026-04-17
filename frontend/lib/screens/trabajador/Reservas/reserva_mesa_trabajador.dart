import 'package:flutter/material.dart';
import 'package:frontend/screens/cliente/perfil_screen.dart';
import 'package:frontend/screens/trabajador/Reservas/gestion_reservas.dart';
import 'package:provider/provider.dart';
import '../../../core/colors_style.dart';
import '../../../models/reserva_model.dart';
import '../../../services/api_service.dart';
import '../../../providers/auth_provider.dart';

class ReservaMesaTrabajador extends StatefulWidget {
  const ReservaMesaTrabajador({super.key});

  @override
  State<ReservaMesaTrabajador> createState() => _ReservaMesaTrabajadorState();
}

class _ReservaMesaTrabajadorState extends State<ReservaMesaTrabajador>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  DateTime _fechaSeleccionada = DateTime.now().add(const Duration(days: 1));
  TimeOfDay _horaSeleccionada = const TimeOfDay(hour: 14, minute: 0);
  int _numComensales = 2;
  int _maxComensales = 12;
  final TextEditingController _nombreCompletoController = TextEditingController();
  final TextEditingController _notasController = TextEditingController();
  bool _isLoading = false;

  Map<String, bool> _disponibilidadHoras = {};

  String _turnoSeleccionado = 'comida';

  final Map<String, List<TimeOfDay>> _horasPorTurno = {
    'comida': [
      const TimeOfDay(hour: 13, minute: 0),
      const TimeOfDay(hour: 13, minute: 30),
      const TimeOfDay(hour: 14, minute: 0),
      const TimeOfDay(hour: 14, minute: 30),
      const TimeOfDay(hour: 15, minute: 0),
    ],
    'cena': [
      const TimeOfDay(hour: 20, minute: 0),
      const TimeOfDay(hour: 20, minute: 30),
      const TimeOfDay(hour: 21, minute: 0),
      const TimeOfDay(hour: 21, minute: 30),
      const TimeOfDay(hour: 22, minute: 0),
    ],
  };

  List<Reserva> _misReservas = [];
  bool _cargandoReservas = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (_tabController.index == 1) _cargarReservas();
    });
    _cargarDisponibilidad();
    _cargarMaxComensales();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _nombreCompletoController.dispose();
    _notasController.dispose();
    super.dispose();
  }

  void _cambiarTurno(String turno) {
    setState(() {
      _turnoSeleccionado = turno;
      _horaSeleccionada = _horasPorTurno[turno]!.first;
    });
    _cargarDisponibilidad();
  }

  Future<void> _cargarMaxComensales() async {
    try {
      final mesas = await ApiService.obtenerMesas();
      if (mesas.isNotEmpty && mounted) {
        final max = mesas.map((m) => m.capacidad).reduce((a, b) => a > b ? a : b);
        setState(() => _maxComensales = max);
      }
    } catch (_) {}
  }

  Future<void> _seleccionarFecha() async {
    final fecha = await showDatePicker(
      context: context,
      initialDate: _fechaSeleccionada,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 60)),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AppColors.button,
              onPrimary: AppColors.background,
              surface: AppColors.panel,
              onSurface: AppColors.textPrimary,
            ),
            dialogBackgroundColor: AppColors.background,
          ),
          child: child!,
        );
      },
    );
    if (fecha != null) {
      setState(() {
        _fechaSeleccionada = fecha;
      });
      _cargarDisponibilidad();
    }
  }

  void _autoSeleccionarHoraDisponible() {
    final horaActualStr = _formatearHora(_horaSeleccionada);
    final disponible = _disponibilidadHoras[horaActualStr] ?? true;
    if (!disponible) {
      final horas = _horasPorTurno[_turnoSeleccionado] ?? [];
      for (final h in horas) {
        if (_disponibilidadHoras[_formatearHora(h)] ?? true) {
          _horaSeleccionada = h;
          return;
        }
      }
    }
  }

  Future<void> _cargarDisponibilidad() async {
    final horas = _horasPorTurno[_turnoSeleccionado] ?? [];
    final Map<String, bool> resultado = {};
    for (final h in horas) {
      final horaStr = _formatearHora(h);
      resultado[horaStr] = await ApiService.hayDisponibilidad(
        fecha: _fechaSeleccionada,
        hora: horaStr,
        comensales: _numComensales,
      );
    }
    if (!mounted) return;
    setState(() {
      _disponibilidadHoras = resultado;
      _autoSeleccionarHoraDisponible();
    });
  }

  String _formatearFecha(DateTime fecha) {
    const meses = [
      'enero',
      'febrero',
      'marzo',
      'abril',
      'mayo',
      'junio',
      'julio',
      'agosto',
      'septiembre',
      'octubre',
      'noviembre',
      'diciembre',
    ];
    const dias = [
      'Lunes',
      'Martes',
      'Miércoles',
      'Jueves',
      'Viernes',
      'Sábado',
      'Domingo',
    ];
    return '${dias[fecha.weekday - 1]}, ${fecha.day} de ${meses[fecha.month - 1]}';
  }

  String _formatearHora(TimeOfDay hora) {
    return '${hora.hour.toString().padLeft(2, '0')}:${hora.minute.toString().padLeft(2, '0')}';
  }

  void _confirmarReserva() async {
    setState(() => _isLoading = true);

    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final nombreCompleto = _nombreCompletoController.text.trim().isNotEmpty
          ? _nombreCompletoController.text.trim()
          : auth.usuarioActual?.nombre ?? '';
      final resultado = await ApiService.crearReserva(
        userId: auth.usuarioActual?.id ?? '',
        nombreCompleto: nombreCompleto,
        fecha: _fechaSeleccionada,
        hora: _formatearHora(_horaSeleccionada),
        comensales: _numComensales,
        turno: _turnoSeleccionado,
        notas: _notasController.text.trim().isNotEmpty
            ? _notasController.text.trim()
            : null,
      );

      if (!mounted) return;
      setState(() => _isLoading = false);

      showDialog(
        context: context,
        barrierDismissible: true,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppColors.panel,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Column(
            children: [
              Icon(Icons.check_circle, color: Colors.green, size: 60),
              SizedBox(height: 12),
              Text(
                '¡Reserva Confirmada!',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _filaDetalle(
                Icons.calendar_today,
                _formatearFecha(_fechaSeleccionada),
              ),
              const SizedBox(height: 8),
              _filaDetalle(
                _turnoSeleccionado == 'comida'
                    ? Icons.wb_sunny
                    : Icons.nightlight_round,
                _turnoSeleccionado == 'comida'
                    ? 'Turno de comida'
                    : 'Turno de cena',
              ),
              const SizedBox(height: 8),
              _filaDetalle(
                Icons.access_time,
                _formatearHora(_horaSeleccionada),
              ),
              const SizedBox(height: 8),
              _filaDetalle(Icons.people, '$_numComensales comensales'),
              const SizedBox(height: 8),
              _filaDetalle(
                Icons.table_bar,
                'Mesa ${resultado.numeroMesa ?? "-"}',
              ),
              if (_notasController.text.trim().isNotEmpty) ...[
                const SizedBox(height: 8),
                _filaDetalle(Icons.note, _notasController.text.trim()),
              ],
            ],
          ),
          actions: [
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const GestionReservas(),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.button,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text(
                  'IR A GESTIÓN DE RESERVAS',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al reservar: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _cargarReservas() async {
    setState(() => _cargandoReservas = true);
    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final reservas = await ApiService.obtenerReservas(
        userId: auth.usuarioActual?.id ?? '',
      );
      if (!mounted) return;
      setState(() {
        _misReservas = reservas;
        _cargandoReservas = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _cargandoReservas = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al cargar reservas: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _eliminarReserva(String reservaId) async {
    final confirmar = await showDialog<bool>(
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
        content: const Text(
          'Esta acción no se puede deshacer.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text(
              'NO',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text(
              'SÍ, CANCELAR',
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );

    if (confirmar != true) return;

    try {
      await ApiService.eliminarReserva(reservaId: reservaId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Reserva cancelada'),
          backgroundColor: Colors.green,
        ),
      );
      _cargarReservas();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al cancelar: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _filaDetalle(IconData icono, String texto) {
    return Row(
      children: [
        Icon(icono, color: AppColors.gold, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            texto,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14,
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.iconPrimary),
        title: const Text(
          'RESERVAR MESA',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16, top: 8),
            child: IconButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const PerfilScreen()),
                );
              },
              icon: const Icon(
                Icons.person_outline,
                color: AppColors.gold,
                size: 28,
              ),
            ),
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [_buildFormularioReserva(), _buildMisReservas()],
      ),
    );
  }

  Widget _buildFormularioReserva() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Selecciona el turno',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _botonTurno('comida', 'Comida', Icons.wb_sunny)),
              const SizedBox(width: 12),
              Expanded(
                child: _botonTurno('cena', 'Cena', Icons.nightlight_round),
              ),
            ],
          ),
          const SizedBox(height: 24),
          const Text(
            'Nombre completo',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _nombreCompletoController,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
            style: const TextStyle(color: AppColors.textPrimary),
            decoration: InputDecoration(
              hintText: 'Ingresa tu nombre completo',
              hintStyle: TextStyle(
                color: AppColors.textSecondary.withOpacity(0.5),
              ),
              filled: true,
              fillColor: AppColors.panel,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.line),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.line),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.button),
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Selecciona la fecha',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: _seleccionarFecha,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.panel,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.line),
              ),
              child: Row(
                children: [
                  const Icon(Icons.calendar_today, color: AppColors.gold),
                  const SizedBox(width: 12),
                  Text(
                    _formatearFecha(_fechaSeleccionada),
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 16,
                    ),
                  ),
                  const Spacer(),
                  const Icon(
                    Icons.chevron_right,
                    color: AppColors.textSecondary,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Selecciona la hora',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: (_horasPorTurno[_turnoSeleccionado] ?? []).map((hora) {
              final horaStr = _formatearHora(hora);
              final disponible = _disponibilidadHoras[horaStr] ?? true;
              final seleccionada = hora == _horaSeleccionada && disponible;
              return GestureDetector(
                onTap: disponible
                    ? () => setState(() => _horaSeleccionada = hora)
                    : null,
                child: Opacity(
                  opacity: disponible ? 1.0 : 0.35,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: seleccionada ? AppColors.button : AppColors.panel,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: seleccionada ? AppColors.gold : AppColors.line,
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          horaStr,
                          style: TextStyle(
                            color: seleccionada
                                ? Colors.white
                                : AppColors.textPrimary,
                            fontWeight: seleccionada
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                        if (!disponible)
                          const Text(
                            'Completo',
                            style: TextStyle(
                              color: AppColors.error,
                              fontSize: 10,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),
          const Text(
            'Número de comensales',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.panel,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.line),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  onPressed: _numComensales > 1
                      ? () {
                          setState(() => _numComensales--);
                          _cargarDisponibilidad();
                        }
                      : null,
                  icon: Icon(
                    Icons.remove_circle_outline,
                    color: _numComensales > 1 ? AppColors.gold : AppColors.line,
                    size: 32,
                  ),
                ),
                const SizedBox(width: 20),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '$_numComensales',
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 20),
                IconButton(
                  onPressed: _numComensales < _maxComensales
                      ? () {
                          setState(() => _numComensales++);
                          _cargarDisponibilidad();
                        }
                      : null,
                  icon: Icon(
                    Icons.add_circle_outline,
                    color: _numComensales < _maxComensales
                        ? AppColors.gold
                        : AppColors.line,
                    size: 32,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Notas especiales (opcional)',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _notasController,
            maxLines: 3,
            style: const TextStyle(color: AppColors.textPrimary),
            decoration: InputDecoration(
              hintText: 'Alergias, celebración, silla para niños...',
              hintStyle: TextStyle(
                color: AppColors.textSecondary.withOpacity(0.5),
              ),
              filled: true,
              fillColor: AppColors.panel,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.line),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.line),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.button),
              ),
            ),
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            height: 55,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _confirmarReserva,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.button,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
                elevation: 0,
              ),
              child: _isLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text(
                      'CONFIRMAR RESERVA',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        letterSpacing: 1.5,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _botonTurno(String turno, String label, IconData icono) {
    final seleccionado = _turnoSeleccionado == turno;
    return GestureDetector(
      onTap: () => _cambiarTurno(turno),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          color: seleccionado
              ? AppColors.button.withOpacity(0.15)
              : AppColors.panel,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: seleccionado ? AppColors.button : AppColors.line,
            width: seleccionado ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icono,
              color: seleccionado ? AppColors.gold : AppColors.textSecondary,
              size: 28,
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                color: seleccionado
                    ? AppColors.textPrimary
                    : AppColors.textSecondary,
                fontWeight: seleccionado ? FontWeight.bold : FontWeight.normal,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              turno == 'comida' ? '13:00 - 15:00' : '20:00 - 22:00',
              style: TextStyle(
                color: seleccionado
                    ? AppColors.textSecondary
                    : AppColors.textSecondary.withOpacity(0.5),
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMisReservas() {
    if (_cargandoReservas) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.button),
      );
    }

    if (_misReservas.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.event_busy,
              color: AppColors.textSecondary.withOpacity(0.4),
              size: 80,
            ),
            const SizedBox(height: 16),
            const Text(
              'No tienes reservas',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 18),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => _tabController.animateTo(0),
              child: const Text(
                'Hacer una reserva',
                style: TextStyle(color: AppColors.button, fontSize: 16),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _cargarReservas,
      color: AppColors.button,
      backgroundColor: AppColors.panel,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _misReservas.length,
        itemBuilder: (context, index) {
          final reserva = _misReservas[index];
          return _tarjetaReserva(reserva);
        },
      ),
    );
  }

  Widget _tarjetaReserva(Reserva reserva) {
    final esCena = reserva.turno == 'cena';

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: AppColors.panel,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.line),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: esCena
                        ? Colors.indigo.withOpacity(0.2)
                        : Colors.orange.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        esCena ? Icons.nightlight_round : Icons.wb_sunny,
                        size: 14,
                        color: esCena ? Colors.indigoAccent : Colors.orange,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        esCena ? 'Cena' : 'Comida',
                        style: TextStyle(
                          color: esCena ? Colors.indigoAccent : Colors.orange,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    reserva.estado,
                    style: const TextStyle(
                      color: Colors.green,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => _eliminarReserva(reserva.id),
                  icon: const Icon(
                    Icons.delete_outline,
                    color: AppColors.error,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.calendar_today,
                    size: 18, color: AppColors.gold),
                const SizedBox(width: 8),
                Text(
                  _formatearFecha(reserva.fecha as DateTime),
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.access_time,
                    size: 18, color: AppColors.gold),
                const SizedBox(width: 8),
                Text(
                  reserva.hora,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.people, size: 18, color: AppColors.gold),
                const SizedBox(width: 8),
                Text(
                  '${reserva.comensales} comensales',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            if (reserva.numeroMesa != null) ...[
              Row(
                children: [
                  const Icon(Icons.table_bar,
                      size: 18, color: AppColors.gold),
                  const SizedBox(width: 8),
                  Text(
                    'Mesa ${reserva.numeroMesa}',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
            ],
            if (reserva.notas != null && reserva.notas!.isNotEmpty) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.note, size: 18, color: AppColors.gold),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      reserva.notas!,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
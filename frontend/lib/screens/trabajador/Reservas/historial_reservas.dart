import 'package:flutter/material.dart';
import 'package:frontend/models/reserva_model.dart';
import 'package:frontend/services/reserva_service.dart';
import 'package:intl/intl.dart';
import '../../../core/colors_style.dart';

// -- Constantes de texto --
const _diasAbrevH = ['LUN', 'MAR', 'MIÉ', 'JUE', 'VIE', 'SÁB', 'DOM'];
const _mesesAbrevH = [
  'ENE', 'FEB', 'MAR', 'ABR', 'MAY', 'JUN',
  'JUL', 'AGO', 'SEP', 'OCT', 'NOV', 'DIC'
];

class HistorialReservas extends StatefulWidget {
  const HistorialReservas({super.key});

  @override
  State<HistorialReservas> createState() => _HistorialReservasState();
}

class _HistorialReservasState extends State<HistorialReservas> {
  late Future<List<Reserva>> _reservasFuture;
  DateTime _fechaSeleccionada = DateTime.now();
  bool _mostrarBusqueda = false;
  String _textoBusqueda = '';
  final TextEditingController _controladorBusqueda = TextEditingController();

  @override
  void initState() {
    super.initState();
    _reservasFuture = ReservaService.obtenerReservasFuturas();
  }

  Future<void> _cargarReservas() async {
    setState(() {
      _reservasFuture = ReservaService.obtenerReservasFuturas();
    });
  }

  @override
  void dispose() {
    _controladorBusqueda.dispose();
    super.dispose();
  }

  Future<void> _seleccionarFecha() async {
    final fecha = await showDatePicker(
      context: context,
      initialDate: _fechaSeleccionada,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: ColorScheme.dark(
              primary: AppColors.button,
              onPrimary: Colors.white,
              surface: AppColors.panel,
              onSurface: Colors.white,
              surfaceContainerHighest: AppColors.backgroundButton,
              onSurfaceVariant: Colors.white70,
              secondaryContainer: AppColors.backgroundButton,
              onSecondaryContainer: Colors.white,
            ),
            datePickerTheme: DatePickerThemeData(
              backgroundColor: AppColors.background,
              headerBackgroundColor: AppColors.backgroundButton,
              headerForegroundColor: Colors.white,
              dayBackgroundColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) return AppColors.button;
                return AppColors.backgroundButton;
              }),
              dayForegroundColor: WidgetStateProperty.all(Colors.white),
              todayBackgroundColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) return AppColors.button;
                return AppColors.backgroundButton;
              }),
              todayForegroundColor: WidgetStateProperty.all(AppColors.button),
              todayBorder: BorderSide(color: AppColors.button, width: 1.5),
              weekdayStyle: const TextStyle(color: Colors.white54, fontSize: 12),
              dayStyle: const TextStyle(fontSize: 13),
              yearBackgroundColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) return AppColors.button;
                return AppColors.backgroundButton;
              }),
              yearForegroundColor: WidgetStateProperty.all(Colors.white),
            ),
            dialogTheme:
                const DialogThemeData(backgroundColor: AppColors.background),
          ),
          child: child!,
        );
      },
    );
    if (fecha != null) {
      setState(() => _fechaSeleccionada = fecha);
    }
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
                color: AppColors.shadow.withValues(alpha: 0.88)),
          ),
          SafeArea(
            child: Column(
              children: [
                _buildAppBar(),
                Expanded(child: _buildContent()),
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
            tooltip: 'Volver',
            icon: const Icon(Icons.arrow_back_ios_new,
                color: Colors.white, size: 20),
            onPressed: () => Navigator.pop(context),
          ),
          const Expanded(
            child: Text(
              'HISTORIAL DE RESERVAS',
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
            tooltip: 'Buscar por nombre',
            icon: Icon(
              _mostrarBusqueda ? Icons.search_off : Icons.search,
              color: _mostrarBusqueda ? AppColors.button : Colors.white,
              size: 22,
            ),
            onPressed: () {
              setState(() {
                _mostrarBusqueda = !_mostrarBusqueda;
                if (!_mostrarBusqueda) {
                  _textoBusqueda = '';
                  _controladorBusqueda.clear();
                }
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
          child: _buildSelectorFecha(),
        ),
        if (_mostrarBusqueda) ...[
          const SizedBox(height: 8),
          _buildBarraBusqueda(),
        ],
        const SizedBox(height: 12),
        Expanded(
          child: FutureBuilder<List<Reserva>>(
            future: _reservasFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(color: AppColors.button),
                );
              }
              if (snapshot.hasError) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline,
                          size: 48, color: Colors.white24),
                      const SizedBox(height: 12),
                      Text(
                        'Error: ${snapshot.error}',
                        style: const TextStyle(color: Colors.white70),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      TextButton(
                        onPressed: _cargarReservas,
                        child: const Text(
                          'Reintentar',
                          style: TextStyle(
                              color: AppColors.button,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                );
              }

              final busqueda = _textoBusqueda.trim().toLowerCase();
              final reservasFiltradas = (snapshot.data ?? []).where((r) {
                final coincideFecha = r.fecha.year == _fechaSeleccionada.year &&
                    r.fecha.month == _fechaSeleccionada.month &&
                    r.fecha.day == _fechaSeleccionada.day;
                final coincideNombre = busqueda.isEmpty ||
                    r.nombreCompleto.toLowerCase().contains(busqueda);
                return coincideFecha && coincideNombre;
              }).toList();

              if (reservasFiltradas.isEmpty) return _buildEstadoVacio();

              return RefreshIndicator(
                onRefresh: _cargarReservas,
                color: AppColors.button,
                backgroundColor: AppColors.panel,
                child: ListView.builder(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                  itemCount: reservasFiltradas.length,
                  itemBuilder: (_, i) =>
                      _tarjetaReserva(reservasFiltradas[i]),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSelectorFecha() {
    return GestureDetector(
      onTap: _seleccionarFecha,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.panel.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white24),
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_month, color: AppColors.button, size: 20),
            const SizedBox(width: 12),
            Text(
              DateFormat('EEEE, d \'de\' MMMM \'de\' yyyy', 'es')
                  .format(_fechaSeleccionada),
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            const Spacer(),
            const Icon(Icons.expand_more, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }

  Widget _buildBarraBusqueda() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.panel.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.button.withValues(alpha: 0.5)),
        ),
        child: Row(
          children: [
            const Icon(Icons.person_search, color: AppColors.button, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: _controladorBusqueda,
                autofocus: true,
                style: const TextStyle(
                    color: AppColors.textPrimary, fontSize: 14),
                decoration: const InputDecoration(
                  hintText: 'Nombre o apellido...',
                  hintStyle: TextStyle(color: AppColors.textSecondary),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(vertical: 8),
                ),
                onChanged: (v) => setState(() => _textoBusqueda = v),
              ),
            ),
            if (_textoBusqueda.isNotEmpty)
              GestureDetector(
                onTap: () => setState(() {
                  _textoBusqueda = '';
                  _controladorBusqueda.clear();
                }),
                child: const Icon(Icons.close,
                    color: AppColors.textSecondary, size: 18),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildEstadoVacio() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.event_busy_outlined,
              size: 64, color: Colors.white24),
          const SizedBox(height: 16),
          const Text(
            'No hay reservas para esta fecha',
            style: TextStyle(
                color: Colors.white54, fontSize: 16, letterSpacing: 0.5),
          ),
          const SizedBox(height: 24),
          TextButton(
            onPressed: _seleccionarFecha,
            child: const Text(
              'Cambiar fecha',
              style: TextStyle(
                  color: AppColors.button, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tarjetaReserva(Reserva reserva) {
    final esCena = reserva.turno == 'cena';
    final colorEstado = _colorEstado(reserva.estado);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.panel.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white24),
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            // -- Columna fecha --
            Container(
              width: 70,
              decoration: BoxDecoration(
                color: AppColors.button.withValues(alpha: 0.08),
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
                    style: const TextStyle(
                      color: AppColors.button,
                      fontSize: 30,
                      fontWeight: FontWeight.bold,
                      height: 1,
                    ),
                  ),
                  Text(
                    _mesesAbrevH[reserva.fecha.month - 1],
                    style: const TextStyle(
                      color: AppColors.button,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _diasAbrevH[reserva.fecha.weekday - 1],
                    style: const TextStyle(
                        color: AppColors.textSecondary, fontSize: 10),
                  ),
                ],
              ),
            ),
            // -- Detalles --
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 14, 12, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _badge(
                          esCena ? 'Cena' : 'Comida',
                          esCena
                              ? Icons.nightlight_outlined
                              : Icons.wb_sunny_outlined,
                          esCena ? Colors.indigo : Colors.orange,
                        ),
                        const SizedBox(width: 6),
                        _badge(reserva.estado, Icons.circle, colorEstado),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      reserva.nombreCompleto,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.access_time,
                            size: 14, color: AppColors.textSecondary),
                        const SizedBox(width: 5),
                        Text(
                          reserva.hora,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(width: 14),
                        const Icon(Icons.people_outline,
                            size: 14, color: AppColors.textSecondary),
                        const SizedBox(width: 5),
                        Text(
                          '${reserva.comensales}',
                          style: const TextStyle(
                              color: AppColors.textPrimary, fontSize: 14),
                        ),
                        if (reserva.numeroMesa != null) ...[
                          const SizedBox(width: 14),
                          const Icon(Icons.table_bar,
                              size: 14, color: AppColors.textSecondary),
                          const SizedBox(width: 5),
                          Text(
                            'Mesa ${reserva.numeroMesa}',
                            style: const TextStyle(
                                color: AppColors.textPrimary, fontSize: 14),
                          ),
                        ],
                      ],
                    ),
                    if (reserva.notas != null &&
                        reserva.notas!.isNotEmpty) ...[
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
    );
  }

  Widget _badge(String label, IconData icono, Color color) {
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
                  color: color, fontSize: 11, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Color _colorEstado(String estado) {
    switch (estado.toLowerCase()) {
      case 'confirmada': return AppColors.disp;
      case 'pendiente':  return Colors.orange;
      case 'cancelada':  return AppColors.error;
      default:           return const Color(0xFF3B82F6);
    }
  }
}
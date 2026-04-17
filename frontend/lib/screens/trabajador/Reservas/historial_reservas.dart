import 'package:flutter/material.dart';
import 'package:frontend/models/reserva_model.dart';
import 'package:frontend/services/api_service.dart';
import 'package:intl/intl.dart';
import '../../../core/colors_style.dart';

class HistorialReservas extends StatefulWidget {
  const HistorialReservas({super.key});

  @override
  State<HistorialReservas> createState() => _HistorialReservasState();
}

class _HistorialReservasState extends State<HistorialReservas> {
  List<Reserva> _reservas = [];
  DateTime _fechaSeleccionada = DateTime.now();
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargarReservas();
  }

  Future<void> _cargarReservas() async {
    try {
      final reservas = await ApiService.obtenerReservas(userId: '');
      setState(() {
        _reservas = reservas;
        _cargando = false;
      });
    } catch (e) {
      setState(() => _cargando = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al cargar reservas: $e')),
      );
    }
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
            colorScheme: const ColorScheme.dark(
              primary: AppColors.button,
              onPrimary: Colors.white,
              surface: AppColors.panel,
              onSurface: Colors.white,
            ),
            dialogBackgroundColor: AppColors.background,
          ),
          child: child!,
        );
      },
    );

    if (fecha != null) {
      setState(() => _fechaSeleccionada = fecha);
    }
  }

  List<Reserva> _filtrarReservasPorFecha() {
    return _reservas.where((reserva) {
      return reserva.fecha.year == _fechaSeleccionada.year &&
          reserva.fecha.month == _fechaSeleccionada.month &&
          reserva.fecha.day == _fechaSeleccionada.day;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final reservasFiltradas = _filtrarReservasPorFecha();

    return Scaffold(
      backgroundColor: AppColors.background,
      extendBodyBehindAppBar: true,

      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          "HISTORIAL DE RESERVAS",
          style: TextStyle(
            fontFamily: 'Playfair Display',
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
          ),
        ),
      ),

      body: Column(
        children: [
          _buildHero(),

          Expanded(
            child: Container(
              decoration: const BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
              ),
              child: _cargando
                  ? const Center(
                      child: CircularProgressIndicator(color: AppColors.button),
                    )
                  : _buildContenido(reservasFiltradas),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // HERO SECTION
  // ─────────────────────────────────────────────────────────────
  Widget _buildHero() {
    return Stack(
      children: [
        SizedBox(
          height: 220,
          width: double.infinity,
          child: Image.asset(
            'assets/images/Bravo restaurante.jpg',
            fit: BoxFit.cover,
          ),
        ),

        Container(
          height: 220,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withOpacity(0.4),
                Colors.black.withOpacity(0.2),
                AppColors.background.withOpacity(0.9),
              ],
            ),
          ),
        ),

        Positioned(
          bottom: 20,
          left: 0,
          right: 0,
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.backgroundButton,
                  border: Border.all(color: AppColors.background, width: 1.5),
                ),
                child: const Text(
                  "GESTIÓN DE RESERVAS",
                  style: TextStyle(
                    color: AppColors.background,
                    fontSize: 10,
                    letterSpacing: 4,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                "Historial",
                style: TextStyle(
                  fontFamily: 'Playfair Display',
                  color: Colors.white,
                  fontSize: 34,
                  fontWeight: FontWeight.bold,
                  shadows: [
                    Shadow(color: Colors.black87, blurRadius: 12),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────
  // CONTENIDO PRINCIPAL
  // ─────────────────────────────────────────────────────────────
  Widget _buildContenido(List<Reserva> reservasFiltradas) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          _buildSelectorFecha(),
          const SizedBox(height: 20),

          Expanded(
            child: reservasFiltradas.isEmpty
                ? const Center(
                    child: Text(
                      'No hay reservas para esta fecha',
                      style: TextStyle(color: Colors.white70),
                    ),
                  )
                : ListView.builder(
                    itemCount: reservasFiltradas.length,
                    itemBuilder: (context, index) =>
                        _tarjetaReserva(reservasFiltradas[index]),
                  ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // SELECTOR DE FECHA PREMIUM
  // ─────────────────────────────────────────────────────────────
  Widget _buildSelectorFecha() {
    return GestureDetector(
      onTap: _seleccionarFecha,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.backgroundButton,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.line),
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_month, color: AppColors.gold),
            const SizedBox(width: 12),
            Text(
              DateFormat('dd/MM/yyyy').format(_fechaSeleccionada),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
              ),
            ),
            const Spacer(),
            const Icon(Icons.expand_more, color: Colors.white70),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // TARJETA DE RESERVA
  // ─────────────────────────────────────────────────────────────
  Widget _tarjetaReserva(Reserva reserva) {
    final esCena = reserva.turno == 'cena';

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: AppColors.backgroundButton,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.line),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // BADGE TURNO
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: esCena
                        ? Colors.indigo.withOpacity(0.2)
                        : Colors.orange.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
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

                // ESTADO
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
              ],
            ),

            const SizedBox(height: 12),

            Text(
              reserva.nombreCompleto,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 6),

            Text(
              "Fecha: ${DateFormat('dd/MM/yyyy').format(reserva.fecha)}",
              style: const TextStyle(color: Colors.white70),
            ),
            Text("Hora: ${reserva.hora}", style: const TextStyle(color: Colors.white70)),
            Text("Comensales: ${reserva.comensales}",
                style: const TextStyle(color: Colors.white70)),

            if (reserva.numeroMesa != null)
              Text("Mesa: ${reserva.numeroMesa}",
                  style: const TextStyle(color: Colors.white70)),

            if (reserva.notas != null && reserva.notas!.isNotEmpty)
              Text("Notas: ${reserva.notas}",
                  style: const TextStyle(color: Colors.white70)),
          ],
        ),
      ),
    );
  }
}

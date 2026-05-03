import 'package:flutter/material.dart';
import 'package:frontend/models/reserva_model.dart';
import 'package:frontend/services/reserva_service.dart';
import 'package:intl/intl.dart';
import '../../../core/colors_style.dart';

class BorrarReservas extends StatefulWidget {
  const BorrarReservas({super.key});

  @override
  State<BorrarReservas> createState() => _BorrarReservasState();
}

class _BorrarReservasState extends State<BorrarReservas> {
  late Future<List<Reserva>> _reservasFuture;

  @override
  void initState() {
    super.initState();
    _reservasFuture = ReservaService.obtenerReservasFuturas();
  }

  void _refreshReservas() {
    setState(() {
      _reservasFuture = ReservaService.obtenerReservasFuturas();
    });
  }

  void _confirmarBorrado(Reserva reserva) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.backgroundButton,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Eliminar Reserva',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          '¿Seguro que deseas eliminar la reserva de ${reserva.nombreCompleto} del '
          '${DateFormat('dd/MM/yyyy').format(reserva.fecha)} a las ${reserva.hora}?',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar', style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: AppColors.background,
            ),
            onPressed: () async {
              Navigator.of(context).pop();
              try {
                await ReservaService.eliminarReserva(reservaId: reserva.id);
                _refreshReservas();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Reserva eliminada')),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e')),
                  );
                }
              }
            },
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      extendBodyBehindAppBar: true,

      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: AppColors.background),
        title: const Text(
          "BORRAR RESERVAS",
          style: TextStyle(
            fontFamily: 'Playfair Display',
            color: AppColors.background,
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
              child: FutureBuilder<List<Reserva>>(
                future: _reservasFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(color: AppColors.button),
                    );
                  } else if (snapshot.hasError) {
                    return Center(
                      child: Text(
                        'Error: ${snapshot.error}',
                        style: const TextStyle(color: AppColors.background),
                      ),
                    );
                  } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return const Center(
                      child: Text(
                        'No hay reservas futuras',
                        style: TextStyle(color: AppColors.background),
                      ),
                    );
                  }

                  final reservas = snapshot.data!;
                  return ListView.builder(
                    padding: const EdgeInsets.all(20),
                    itemCount: reservas.length,
                    itemBuilder: (context, index) =>
                        _tarjetaReserva(reservas[index]),
                  );
                },
              ),
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
                AppColors.shadow.withValues(alpha:0.4),
                AppColors.shadow.withValues(alpha:0.2),
                AppColors.background.withValues(alpha:0.9),
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
                "Eliminar",
                style: TextStyle(
                  fontFamily: 'Playfair Display',
                  color: AppColors.background,
                  fontSize: 34,
                  fontWeight: FontWeight.bold,
                  shadows: [
                    Shadow(color: AppColors.shadow, blurRadius: 12),
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
  // TARJETA PREMIUM
  // ─────────────────────────────────────────────────────────────
  Widget _tarjetaReserva(Reserva reserva) {
    return GestureDetector(
      onTap: () => _confirmarBorrado(reserva),
      child: Container(
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
              Text(
                reserva.nombreCompleto,
                style: const TextStyle(
                  color: AppColors.background,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                "Fecha: ${DateFormat('dd/MM/yyyy').format(reserva.fecha)}",
                style: const TextStyle(color: AppColors.background),
              ),
              Text(
                "Hora: ${reserva.hora}",
                style: const TextStyle(color: AppColors.background),
              ),
              Text(
                "Comensales: ${reserva.comensales}",
                style: const TextStyle(color: AppColors.background),
              ),
              if (reserva.numeroMesa != null)
                Text(
                  "Mesa: ${reserva.numeroMesa}",
                  style: const TextStyle(color: AppColors.background),
                ),
              const SizedBox(height: 10),
              const Align(
                alignment: Alignment.centerRight,
                child: Icon(Icons.delete, color: AppColors.error),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

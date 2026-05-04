import 'package:flutter/material.dart';
import 'package:frontend/models/reserva_model.dart';
import 'package:frontend/services/reserva_service.dart';
import '../../../core/colors_style.dart';

// ── Constantes de texto ──
const _diasAbrevB = ['LUN', 'MAR', 'MIÉ', 'JUE', 'VIE', 'SÁB', 'DOM'];
const _mesesAbrevB = [
  'ENE', 'FEB', 'MAR', 'ABR', 'MAY', 'JUN',
  'JUL', 'AGO', 'SEP', 'OCT', 'NOV', 'DIC'
];

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
        backgroundColor: AppColors.panel,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          '¿Eliminar reserva?',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
            fontFamily: 'Playfair Display',
          ),
        ),
        content: Text(
          '¿Seguro que deseas eliminar la reserva de ${reserva.nombreCompleto} del '
          '${reserva.fecha.day}/${reserva.fecha.month}/${reserva.fecha.year} a las ${reserva.hora}?',
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(
              'CANCELAR',
              style: TextStyle(
                  color: AppColors.textSecondary, fontWeight: FontWeight.w600),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();
              try {
                await ReservaService.eliminarReserva(reservaId: reserva.id);
                _refreshReservas();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Reserva eliminada'),
                      backgroundColor: AppColors.disp,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error: $e'),
                      backgroundColor: AppColors.error,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              }
            },
            child: const Text(
              'ELIMINAR',
              style: TextStyle(
                  color: AppColors.error, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
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
              'BORRAR RESERVAS',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                letterSpacing: 2.5,
                fontSize: 15,
              ),
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }

  Widget _buildContent() {
    return FutureBuilder<List<Reserva>>(
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
              style: const TextStyle(color: Colors.white70),
            ),
          );
        } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return _buildEstadoVacio();
        } else {
          return RefreshIndicator(
            onRefresh: () async => _refreshReservas(),
            color: AppColors.button,
            backgroundColor: AppColors.panel,
            child: ListView.builder(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              itemCount: snapshot.data!.length,
              itemBuilder: (_, i) => _tarjetaReserva(snapshot.data![i]),
            ),
          );
        }
      },
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
            'No hay reservas futuras',
            style: TextStyle(
                color: Colors.white54, fontSize: 16, letterSpacing: 0.5),
          ),
          const SizedBox(height: 24),
          TextButton(
            onPressed: _refreshReservas,
            child: const Text(
              'Reintentar',
              style: TextStyle(
                  color: AppColors.button, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tarjetaReserva(Reserva reserva) {
    return GestureDetector(
      onTap: () => _confirmarBorrado(reserva),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: AppColors.panel.withValues(alpha: 0.96),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white24),
        ),
        child: IntrinsicHeight(
          child: Row(
            children: [
              // ── Columna fecha ──
              Container(
                width: 70,
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.08),
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
                        color: AppColors.error,
                        fontSize: 30,
                        fontWeight: FontWeight.bold,
                        height: 1,
                      ),
                    ),
                    Text(
                      _mesesAbrevB[reserva.fecha.month - 1],
                      style: const TextStyle(
                        color: AppColors.error,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _diasAbrevB[reserva.fecha.weekday - 1],
                      style: const TextStyle(
                          color: AppColors.textSecondary, fontSize: 10),
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
                          Expanded(
                            child: Text(
                              reserva.nombreCompleto,
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: AppColors.error.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                  color: AppColors.error
                                      .withValues(alpha: 0.3)),
                            ),
                            child: const Icon(Icons.delete_outline,
                                color: AppColors.error, size: 16),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
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
      ),
    );
  }
}

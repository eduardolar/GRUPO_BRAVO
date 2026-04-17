import 'package:flutter/material.dart';
import 'package:frontend/models/reserva_model.dart';
import 'package:frontend/services/reserva_service.dart';
import 'package:intl/intl.dart';

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
        title: const Text('Eliminar Reserva'),
        content: Text(
          '¿Estás seguro de que quieres eliminar la reserva de '
          '${reserva.nombreCompleto} del '
          '${DateFormat('dd/MM/yyyy').format(reserva.fecha)} a las ${reserva.hora}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
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
      appBar: AppBar(
        title: const Text('Borrar Reservas'),
      ),
      body: FutureBuilder<List<Reserva>>(
        future: _reservasFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No hay reservas futuras'));
          } else {
            final reservas = snapshot.data!;
            return ListView.builder(
              itemCount: reservas.length,
              itemBuilder: (context, index) {
                final reserva = reservas[index];
                return ListTile(
                  title: Text(
                    '${reserva.nombreCompleto} - Mesa ${reserva.numeroMesa}',
                  ),
                  subtitle: Text(
                    '${DateFormat('dd/MM/yyyy').format(reserva.fecha)} '
                    '${reserva.hora} - ${reserva.comensales} comensales',
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () => _confirmarBorrado(reserva),
                  ),
                  onTap: () => _confirmarBorrado(reserva),
                );
              },
            );
          }
        },
      ),
    );
  }
}
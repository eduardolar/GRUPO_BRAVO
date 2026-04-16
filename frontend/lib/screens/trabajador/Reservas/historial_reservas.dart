import 'package:flutter/material.dart';
import 'package:frontend/models/reserva_model.dart';
import 'package:frontend/providers/auth_provider.dart';
import 'package:frontend/services/api_service.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

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
  print('\n=== CARGAR TODAS LAS RESERVAS ===');

  try {
    // Obtener TODAS las reservas del sistema (pasando vacío o un valor especial)
    final reservas = await ApiService.obtenerReservas(userId: '');
    
    print('✅ Reservas obtenidas: ${reservas.length}');
    reservas.forEach((r) {
      print('  📌 Reserva: ${r.id} | Usuario: ${r.usuarioId} | Fecha: ${r.fecha}');
    });

    setState(() {
      _reservas = reservas;
      _cargando = false;
    });
  } catch (e) {
    print('❌ Error al cargar reservas: $e');
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
    );
    if (fecha != null) {
      setState(() => _fechaSeleccionada = fecha);
    }
  }

  /// Filtra reservas por fecha usando DateTime (ya no Strings)
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
      appBar: AppBar(
        title: const Text('Historial de Reservas'),
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('Seleccionar fecha: '),
                      ElevatedButton(
                        onPressed: _seleccionarFecha,
                        child: Text(DateFormat('dd/MM/yyyy').format(_fechaSeleccionada)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: reservasFiltradas.isEmpty
                        ? const Center(child: Text('No hay reservas para esta fecha'))
                        : ListView.builder(
                            itemCount: reservasFiltradas.length,
                            itemBuilder: (context, index) {
                              final reserva = reservasFiltradas[index];
                              return Card(
                                margin: const EdgeInsets.symmetric(vertical: 8),
                                child: Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('Nombre: ${reserva.nombreCompleto}'),
                                      Text(
                                        'Fecha: ${DateFormat('dd/MM/yyyy').format(reserva.fecha)}',
                                        style: const TextStyle(fontWeight: FontWeight.bold),
                                      ),
                                      Text('Hora: ${reserva.hora}'),
                                      Text('Turno: ${reserva.turno}'),
                                      Text('Comensales: ${reserva.comensales}'),
                                      Text('Estado: ${reserva.estado}'),
                                      if (reserva.numeroMesa != null)
                                        Text('Mesa: ${reserva.numeroMesa}'),
                                      if (reserva.notas != null && reserva.notas!.isNotEmpty)
                                        Text('Notas: ${reserva.notas}'),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
    );
  }
}

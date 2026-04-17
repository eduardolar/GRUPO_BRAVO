import 'package:flutter/material.dart';
import 'package:frontend/models/reserva_model.dart';
import 'package:frontend/services/reserva_service.dart';
import 'package:intl/intl.dart';

class ModificarReservas extends StatefulWidget {
  const ModificarReservas({super.key});

  @override
  State<ModificarReservas> createState() => _ModificarReservasState();
}

class _ModificarReservasState extends State<ModificarReservas> {
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

  void _editarReserva(Reserva reserva) {
    showDialog(
      context: context,
      builder: (context) => EditarReservaDialog(
        reserva: reserva,
        onSave: (updatedReserva) async {
          try {
            await ReservaService.actualizarReserva(updatedReserva);
            _refreshReservas();
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Reserva actualizada')),
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
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Modificar Reservas'),
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
                  title: Text('${reserva.nombreCompleto} - Mesa ${reserva.numeroMesa}'),
                  subtitle: Text(
                    '${DateFormat('dd/MM/yyyy').format(reserva.fecha)} ${reserva.hora} - ${reserva.comensales} comensales',
                  ),
                  trailing: const Icon(Icons.edit, color: Colors.grey),
                  onTap: () => _editarReserva(reserva),
                );
              },
            );
          }
        },
      ),
    );
  }
}

class EditarReservaDialog extends StatefulWidget {
  final Reserva reserva;
  final Function(Reserva) onSave;

  const EditarReservaDialog({super.key, required this.reserva, required this.onSave});

  @override
  State<EditarReservaDialog> createState() => _EditarReservaDialogState();
}

class _EditarReservaDialogState extends State<EditarReservaDialog> {
  late TextEditingController _fechaController;
  late TextEditingController _horaController;
  late TextEditingController _comensalesController;
  late TextEditingController _notasController;
  String? _turno;

  @override
  void initState() {
    super.initState();
    _fechaController = TextEditingController(
        text: DateFormat('dd/MM/yyyy').format(widget.reserva.fecha));
    _horaController = TextEditingController(text: widget.reserva.hora);
    _comensalesController =
        TextEditingController(text: widget.reserva.comensales.toString());
    _notasController =
        TextEditingController(text: widget.reserva.notas ?? '');
    _turno = widget.reserva.turno;
  }

  @override
  void dispose() {
    _fechaController.dispose();
    _horaController.dispose();
    _comensalesController.dispose();
    _notasController.dispose();
    super.dispose();
  }

  Future<void> _selectFecha() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: widget.reserva.fecha,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() {
        _fechaController.text = DateFormat('dd/MM/yyyy').format(picked);
      });
    }
  }

  Future<void> _selectHora() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(
          DateFormat('HH:mm').parse(widget.reserva.hora)),
    );
    if (picked != null) {
      setState(() {
        _horaController.text =
            '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
      });
    }
  }

  void _save() {
    final fecha = DateFormat('dd/MM/yyyy').parse(_fechaController.text);
    final hora = _horaController.text;
    final comensales =
        int.tryParse(_comensalesController.text) ?? widget.reserva.comensales;
    final notas =
        _notasController.text.isEmpty ? null : _notasController.text;
    final turno = _turno ?? widget.reserva.turno;

    final updatedReserva = widget.reserva.copyWith(
      fecha: fecha,
      hora: hora,
      comensales: comensales,
      turno: turno,
      notas: notas,
    );

    widget.onSave(updatedReserva);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Editar Reserva'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _fechaController,
              decoration: const InputDecoration(labelText: 'Fecha'),
              readOnly: true,
              onTap: _selectFecha,
            ),
            TextField(
              controller: _horaController,
              decoration: const InputDecoration(labelText: 'Hora'),
              readOnly: true,
              onTap: _selectHora,
            ),
            TextField(
              controller: _comensalesController,
              decoration: const InputDecoration(labelText: 'Comensales'),
              keyboardType: TextInputType.number,
            ),
            DropdownButtonFormField<String>(
              value: _turno,
              decoration: const InputDecoration(labelText: 'Turno'),
              items: const [
                DropdownMenuItem(value: 'comida', child: Text('Comida')),
                DropdownMenuItem(value: 'cena', child: Text('Cena')),
              ],
              onChanged: (value) => setState(() => _turno = value),
            ),
            TextField(
              controller: _notasController,
              decoration: const InputDecoration(labelText: 'Notas'),
              maxLines: 3,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: _save,
          child: const Text('Guardar'),
        ),
      ],
    );
  }
}
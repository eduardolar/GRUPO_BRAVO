import 'package:flutter/material.dart';
import 'package:frontend/models/reserva_model.dart';
import 'package:frontend/services/reserva_service.dart';
import 'package:intl/intl.dart';
import '../../../core/colors_style.dart';

/// ─────────────────────────────────────────────────────────────
/// DIÁLOGO EDITAR RESERVA (LÓGICA IGUAL, SOLO DISEÑO)
/// ─────────────────────────────────────────────────────────────
class EditarReservaDialog extends StatefulWidget {
  final Reserva reserva;
  final Function(Reserva) onSave;

  const EditarReservaDialog({
    super.key,
    required this.reserva,
    required this.onSave,
  });

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
      text: DateFormat('dd/MM/yyyy').format(widget.reserva.fecha),
    );
    _horaController = TextEditingController(text: widget.reserva.hora);
    _comensalesController =
        TextEditingController(text: widget.reserva.comensales.toString());
    _notasController = TextEditingController(text: widget.reserva.notas ?? '');
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
        DateFormat('HH:mm').parse(widget.reserva.hora),
      ),
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

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: AppColors.background, fontWeight: FontWeight.bold),
      filled: true,
      fillColor: AppColors.backgroundButton,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.line),
      ),
    );
  }

  Widget _input(
    TextEditingController controller,
    String label, {
    int maxLines = 1,
    TextInputType? keyboard,
    VoidCallback? onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextField(
        controller: controller,
        readOnly: onTap != null,
        onTap: onTap,
        maxLines: maxLines,
        keyboardType: keyboard,
        style: const TextStyle(color: AppColors.background),
        decoration: _inputDecoration(label),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.panel,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text(
        'Editar Reserva',
        style: TextStyle(
          color: AppColors.shadow,
          fontWeight: FontWeight.bold,
        ),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _input(_fechaController, 'Fecha', onTap: _selectFecha),
            _input(_horaController, 'Hora', onTap: _selectHora),
            _input(
              _comensalesController,
              'Comensales',
              keyboard: TextInputType.number,
            ),
            DropdownButtonFormField<String>(
              value: _turno,
              dropdownColor: AppColors.backgroundButton,
              decoration: _inputDecoration('Turno'),
              items: const [
                DropdownMenuItem(value: 'comida', child: Text('Comida', style: TextStyle(color: AppColors.background),)),
                DropdownMenuItem(value: 'cena', child: Text('Cena', style: TextStyle(color: AppColors.background),)),
              ],
              onChanged: (value) => setState(() => _turno = value),
            ),
            SizedBox(height: 10),
            _input(_notasController, 'Notas', maxLines: 3),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text(
            'Cancelar',
            style: TextStyle(color: AppColors.background),
          ),
        ),
        ElevatedButton(
          onPressed: _save,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.button,
            foregroundColor: AppColors.background,
          ),
          child: const Text('Guardar'),
        ),
      ],
    );
  }
}

/// ─────────────────────────────────────────────────────────────
/// PANTALLA MODIFICAR RESERVAS (LÓGICA IGUAL, SOLO DISEÑO)
/// ─────────────────────────────────────────────────────────────
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
      backgroundColor: AppColors.background,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: AppColors.background),
        title: const Text(
          'MODIFICAR RESERVAS',
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
                      child: CircularProgressIndicator(
                        color: AppColors.button,
                      ),
                    );
                  } else if (snapshot.hasError) {
                    return Center(
                      child: Text(
                        'Error: ${snapshot.error}',
                        style: const TextStyle(color: Colors.white70),
                      ),
                    );
                  } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return const Center(
                      child: Text(
                        'No hay reservas futuras',
                        style: TextStyle(color: AppColors.background),
                      ),
                    );
                  } else {
                    final reservas = snapshot.data!;
                    return ListView.builder(
                      padding: const EdgeInsets.all(20),
                      itemCount: reservas.length,
                      itemBuilder: (context, index) {
                        final reserva = reservas[index];
                        return _tarjetaReserva(reserva);
                      },
                    );
                  }
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

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
                AppColors.shadow.withOpacity(0.4),
                AppColors.shadow.withOpacity(0.2),
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.backgroundButton,
                  border: Border.all(
                    color: AppColors.background,
                    width: 1.5,
                  ),
                ),
                child: const Text(
                  'GESTIÓN DE RESERVAS',
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
                'Modificar',
                style: TextStyle(
                  fontFamily: 'Playfair Display',
                  color: AppColors.background,
                  fontSize: 34,
                  fontWeight: FontWeight.bold,
                  shadows: [
                    Shadow(
                      color: Colors.black87,
                      blurRadius: 12,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _tarjetaReserva(Reserva reserva) {
    return GestureDetector(
      onTap: () => _editarReserva(reserva),
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
                'Fecha: ${DateFormat('dd/MM/yyyy').format(reserva.fecha)}',
                style: const TextStyle(color: AppColors.background),
              ),
              Text(
                'Hora: ${reserva.hora}',
                style: const TextStyle(color: AppColors.background),
              ),
              Text(
                'Comensales: ${reserva.comensales}',
                style: const TextStyle(color: AppColors.background),
              ),
              if (reserva.numeroMesa != null)
                Text(
                  'Mesa: ${reserva.numeroMesa}',
                  style: const TextStyle(color: AppColors.background),
                ),
              const SizedBox(height: 10),
              const Align(
                alignment: Alignment.centerRight,
                child: Icon(
                  Icons.edit,
                  color: AppColors.background,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

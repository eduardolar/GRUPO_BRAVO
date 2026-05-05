import 'package:flutter/material.dart';
import 'package:frontend/models/reserva_model.dart';
import 'package:frontend/providers/auth_provider.dart';
import 'package:frontend/services/reserva_service.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../core/colors_style.dart';

// ── Constantes de texto ──
const _diasAbrev = ['LUN', 'MAR', 'MIÉ', 'JUE', 'VIE', 'SÁB', 'DOM'];
const _mesesAbrev = [
  'ENE',
  'FEB',
  'MAR',
  'ABR',
  'MAY',
  'JUN',
  'JUL',
  'AGO',
  'SEP',
  'OCT',
  'NOV',
  'DIC',
];

/// ─────────────────────────────────────────────────────────────
/// DIÁLOGO EDITAR RESERVA
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
    _comensalesController = TextEditingController(
      text: widget.reserva.comensales.toString(),
    );
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
    final notas = _notasController.text.isEmpty ? null : _notasController.text;
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
      labelStyle: const TextStyle(
        color: AppColors.textSecondary,
        fontWeight: FontWeight.w500,
      ),
      filled: true,
      fillColor: AppColors.background,
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.line),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.button, width: 2),
      ),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
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
        style: const TextStyle(color: AppColors.textPrimary, fontSize: 15),
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
          color: AppColors.textPrimary,
          fontWeight: FontWeight.bold,
          fontFamily: 'Playfair Display',
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
              initialValue: _turno,
              dropdownColor: AppColors.panel,
              decoration: _inputDecoration('Turno'),
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 15,
              ),
              items: const [
                DropdownMenuItem(
                  value: 'comida',
                  child: Text(
                    'Comida',
                    style: TextStyle(color: AppColors.textPrimary),
                  ),
                ),
                DropdownMenuItem(
                  value: 'cena',
                  child: Text(
                    'Cena',
                    style: TextStyle(color: AppColors.textPrimary),
                  ),
                ),
              ],
              onChanged: (value) => setState(() => _turno = value),
            ),
            const SizedBox(height: 10),
            _input(_notasController, 'Notas', maxLines: 3),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text(
            'CANCELAR',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        TextButton(
          onPressed: _save,
          child: const Text(
            'GUARDAR',
            style: TextStyle(
              color: AppColors.button,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }
}

/// ─────────────────────────────────────────────────────────────
/// PANTALLA MODIFICAR RESERVAS
/// ─────────────────────────────────────────────────────────────
class ModificarReservas extends StatefulWidget {
  const ModificarReservas({super.key});

  @override
  State<ModificarReservas> createState() => _ModificarReservasState();
}

class _ModificarReservasState extends State<ModificarReservas> {
  late Future<List<Reserva>> _reservasFuture;
  bool _cargado = false;

  @override
  void initState() {
    super.initState();
    // Future inicial vacío: la carga real ocurre en didChangeDependencies
    // cuando el contexto está listo para leer la sucursal del trabajador.
    _reservasFuture = Future.value(<Reserva>[]);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_cargado) {
      _cargado = true;
      _refreshReservas();
    }
  }

  String? get _restauranteId =>
      context.read<AuthProvider>().usuarioActual?.restauranteId;

  void _refreshReservas() {
    setState(() {
      // Aislamos por sucursal: el trabajador solo ve reservas de su local.
      _reservasFuture = ReservaService.obtenerReservasFuturas(
        restauranteId: _restauranteId,
      );
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
                SnackBar(
                  content: const Text('Reserva actualizada'),
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
            child: Container(color: AppColors.shadow.withValues(alpha: 0.88)),
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
            icon: const Icon(
              Icons.arrow_back_ios_new,
              color: Colors.white,
              size: 20,
            ),
            onPressed: () => Navigator.pop(context),
          ),
          const Expanded(
            child: Text(
              'MODIFICAR RESERVAS',
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
          const Icon(
            Icons.event_busy_outlined,
            size: 64,
            color: Colors.white24,
          ),
          const SizedBox(height: 16),
          const Text(
            'No hay reservas futuras',
            style: TextStyle(
              color: Colors.white54,
              fontSize: 16,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 24),
          TextButton(
            onPressed: _refreshReservas,
            child: const Text(
              'Reintentar',
              style: TextStyle(
                color: AppColors.button,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tarjetaReserva(Reserva reserva) {
    return GestureDetector(
      onTap: () => _editarReserva(reserva),
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
                      _mesesAbrev[reserva.fecha.month - 1],
                      style: const TextStyle(
                        color: AppColors.button,
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
                              color: AppColors.button.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: AppColors.button.withValues(alpha: 0.3),
                              ),
                            ),
                            child: const Icon(
                              Icons.edit_outlined,
                              color: AppColors.button,
                              size: 16,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          const Icon(
                            Icons.access_time,
                            size: 14,
                            color: AppColors.textSecondary,
                          ),
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
                          const Icon(
                            Icons.people_outline,
                            size: 14,
                            color: AppColors.textSecondary,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            '${reserva.comensales}',
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 14,
                            ),
                          ),
                          if (reserva.numeroMesa != null) ...[
                            const SizedBox(width: 14),
                            const Icon(
                              Icons.table_bar,
                              size: 14,
                              color: AppColors.textSecondary,
                            ),
                            const SizedBox(width: 5),
                            Text(
                              'Mesa ${reserva.numeroMesa}',
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (reserva.notas != null &&
                          reserva.notas!.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(
                              Icons.note_outlined,
                              size: 13,
                              color: AppColors.textSecondary,
                            ),
                            const SizedBox(width: 5),
                            Expanded(
                              child: Text(
                                reserva.notas!,
                                style: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 12,
                                ),
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

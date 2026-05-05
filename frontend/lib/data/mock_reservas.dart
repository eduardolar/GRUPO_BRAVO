import '../models/reserva_model.dart';

class MockReservas {
  static final List<Reserva> reservas = [
    Reserva(
      id: 'r1',
      usuarioId: 'u1',
      nombreCompleto: 'Juan Pérez',
      fecha: DateTime(2026, 4, 20),
      hora: '13:00',
      comensales: 4,
      turno: 'comida',
      estado: 'Confirmada',
      mesaId: 'm1',
      numeroMesa: 1,
      notas: 'Cumpleaños',
    ),
    Reserva(
      id: 'r2',
      usuarioId: 'u2',
      nombreCompleto: 'María García',
      fecha: DateTime(2026, 4, 18),
      hora: '20:00',
      comensales: 2,
      turno: 'cena',
      estado: 'Confirmada',
      mesaId: 'm2',
      numeroMesa: 2,
      notas: null,
    ),
  ];
}

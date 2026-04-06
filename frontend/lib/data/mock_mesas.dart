import '../models/mesa_model.dart';

class MockMesas {
  static final List<Mesa> mesas = [
    // Interior — mesas pequeñas
    Mesa(id: 'm1', numero: 1, capacidad: 2, ubicacion: 'interior'),
    Mesa(id: 'm2', numero: 2, capacidad: 2, ubicacion: 'interior'),
    Mesa(id: 'm3', numero: 3, capacidad: 4, ubicacion: 'interior'),
    Mesa(id: 'm4', numero: 4, capacidad: 4, ubicacion: 'interior'),
    Mesa(id: 'm5', numero: 5, capacidad: 6, ubicacion: 'interior'),
    Mesa(id: 'm6', numero: 6, capacidad: 6, ubicacion: 'interior'),
    // Terraza
    Mesa(id: 'm7', numero: 7, capacidad: 2, ubicacion: 'terraza'),
    Mesa(id: 'm8', numero: 8, capacidad: 4, ubicacion: 'terraza'),
    Mesa(id: 'm9', numero: 9, capacidad: 4, ubicacion: 'terraza'),
    Mesa(id: 'm10', numero: 10, capacidad: 6, ubicacion: 'terraza'),
    // Privado
    Mesa(id: 'm11', numero: 11, capacidad: 8, ubicacion: 'privado'),
    Mesa(id: 'm12', numero: 12, capacidad: 12, ubicacion: 'privado'),
  ];
}

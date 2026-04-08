import '../models/mesa_model.dart';

class MockMesas {
  static final List<Mesa> mesas = [
    // Interior — mesas pequeñas
    Mesa(id: 'm1', numero: 1, capacidad: 2, ubicacion: 'interior', codigoQr: 'BRAVO-MESA-01'),
    Mesa(id: 'm2', numero: 2, capacidad: 2, ubicacion: 'interior', codigoQr: 'BRAVO-MESA-02'),
    Mesa(id: 'm3', numero: 3, capacidad: 4, ubicacion: 'interior', codigoQr: 'BRAVO-MESA-03'),
    Mesa(id: 'm4', numero: 4, capacidad: 4, ubicacion: 'interior', codigoQr: 'BRAVO-MESA-04'),
    Mesa(id: 'm5', numero: 5, capacidad: 6, ubicacion: 'interior', codigoQr: 'BRAVO-MESA-05'),
    Mesa(id: 'm6', numero: 6, capacidad: 6, ubicacion: 'interior', codigoQr: 'BRAVO-MESA-06'),
    // Terraza
    Mesa(id: 'm7', numero: 7, capacidad: 2, ubicacion: 'terraza', codigoQr: 'BRAVO-MESA-07'),
    Mesa(id: 'm8', numero: 8, capacidad: 4, ubicacion: 'terraza', codigoQr: 'BRAVO-MESA-08'),
    Mesa(id: 'm9', numero: 9, capacidad: 4, ubicacion: 'terraza', codigoQr: 'BRAVO-MESA-09'),
    Mesa(id: 'm10', numero: 10, capacidad: 6, ubicacion: 'terraza', codigoQr: 'BRAVO-MESA-10'),
    // Privado
    Mesa(id: 'm11', numero: 11, capacidad: 8, ubicacion: 'privado', codigoQr: 'BRAVO-MESA-11'),
    Mesa(id: 'm12', numero: 12, capacidad: 12, ubicacion: 'privado', codigoQr: 'BRAVO-MESA-12'),
  ];
}

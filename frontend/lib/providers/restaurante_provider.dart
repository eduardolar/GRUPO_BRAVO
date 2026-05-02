import 'package:flutter/foundation.dart';
import '../models/restaurante_model.dart';
import '../services/restaurante_service.dart';

class RestauranteProvider with ChangeNotifier {
  final _service = RestauranteService();

  List<Restaurante> _restaurantes = [];
  bool _cargando = false;
  String? _error;

  List<Restaurante> get restaurantes => _restaurantes;
  bool get cargando => _cargando;
  String? get error => _error;

  Future<void> cargar() async {
    _cargando = true;
    _error = null;
    notifyListeners();
    try {
      _restaurantes = await _service.obtenerTodos();
    } catch (e) {
      _error = e.toString();
    } finally {
      _cargando = false;
      notifyListeners();
    }
  }

  Future<bool> crear({required String nombre, required String direccion}) async {
    final nuevo = await _service.crearRestaurante(nombre: nombre, direccion: direccion);
    if (nuevo != null) {
      _restaurantes = [..._restaurantes, nuevo];
      notifyListeners();
      return true;
    }
    return false;
  }

  Future<bool> editar({
    required String id,
    required String nombre,
    required String direccion,
    String? horarioApertura,
    String? horarioCierre,
  }) async {
    final ok = await _service.editarRestaurante(
      id: id,
      nombre: nombre,
      direccion: direccion,
      horarioApertura: horarioApertura,
      horarioCierre: horarioCierre,
    );
    if (ok) {
      _restaurantes = _restaurantes.map((r) {
        if (r.id != id) return r;
        return Restaurante(
          id: r.id,
          nombre: nombre,
          direccion: direccion,
          codigo: r.codigo,
          horarioApertura: horarioApertura == null
              ? r.horarioApertura
              : (horarioApertura.isEmpty ? null : horarioApertura),
          horarioCierre: horarioCierre == null
              ? r.horarioCierre
              : (horarioCierre.isEmpty ? null : horarioCierre),
        );
      }).toList();
      notifyListeners();
    }
    return ok;
  }

  Future<bool> eliminar(String id) async {
    final ok = await _service.eliminarRestaurante(id);
    if (ok) {
      _restaurantes = _restaurantes.where((r) => r.id != id).toList();
      notifyListeners();
    }
    return ok;
  }
}

// ============================================================================
// frontend/lib/providers/restaurante_provider.dart
// ----------------------------------------------------------------------------
// Estado global de la lista de sucursales (multi-tenant).
// Lo consulta la pantalla de selector y la carta del cliente.
// ============================================================================
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

  /// Crea una sucursal. Devuelve el [Restaurante] recién creado (para poder
  /// navegar a completar sus datos) o `null` si la creación falló.
  Future<Restaurante?> crear({
    required String nombre,
    required String direccion,
  }) async {
    final nuevo = await _service.crearRestaurante(
      nombre: nombre,
      direccion: direccion,
    );
    if (nuevo != null) {
      _restaurantes = [..._restaurantes, nuevo];
      notifyListeners();
    }
    return nuevo;
  }

  Future<bool> editar({
    required String id,
    required String nombre,
    required String direccion,
  }) async {
    final ok = await _service.editarRestaurante(
      id: id,
      nombre: nombre,
      direccion: direccion,
    );
    if (ok) {
      _restaurantes = _restaurantes.map((r) {
        if (r.id != id) return r;
        return Restaurante(
          id: r.id,
          nombre: nombre,
          direccion: direccion,
          codigo: r.codigo,
        );
      }).toList();
      notifyListeners();
    }
    return ok;
  }

  Future<bool> toggleActivo(String id, bool activo) async {
    final ok = await _service.toggleActivo(id, activo);
    if (ok) {
      _restaurantes = _restaurantes.map((r) {
        if (r.id != id) return r;
        return Restaurante(
          id: r.id,
          nombre: r.nombre,
          direccion: r.direccion,
          codigo: r.codigo,
          activo: activo,
        );
      }).toList();
      notifyListeners();
    }
    return ok;
  }

  /// Elimina una sucursal. Propaga la `ApiException` del service si el backend
  /// rechaza el borrado (p. ej. 409 cuando la sucursal tiene datos asociados),
  /// para que la pantalla muestre el motivo concreto.
  Future<void> eliminar(String id) async {
    await _service.eliminarRestaurante(id);
    _restaurantes = _restaurantes.where((r) => r.id != id).toList();
    notifyListeners();
  }
}

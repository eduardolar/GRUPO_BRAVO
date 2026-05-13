// ============================================================================
// frontend/lib/providers/usuario_provider.dart
// ----------------------------------------------------------------------------
// Estado de la lista de usuarios usada por el panel del administrador.
// Carga perezosa: solo se llama a `cargar()` cuando se abre la pantalla.
// ============================================================================
import 'package:flutter/foundation.dart';
import '../models/usuario_model.dart';
import '../services/usuario_service.dart';

class UsuarioProvider with ChangeNotifier {
  final _service = UsuarioService();

  List<Usuario> _usuarios = [];
  bool _cargando = false;
  String? _error;

  List<Usuario> get usuarios => _usuarios;
  bool get cargando => _cargando;
  String? get error => _error;

  Future<void> cargar() async {
    _cargando = true;
    _error = null;
    notifyListeners();
    try {
      _usuarios = await _service.obtenerTodos();
    } catch (e) {
      _error = e.toString();
    } finally {
      _cargando = false;
      notifyListeners();
    }
  }

  Future<bool> crear({
    required String nombre,
    required String correo,
    required String rol,
    required String restauranteId,
  }) async {
    final ok = await _service.crearUsuario(
      nombre: nombre,
      correo: correo,
      password: '',
      rol: rol,
      restauranteId: restauranteId,
    );
    if (ok) await cargar();
    return ok;
  }

  Future<bool> eliminar(String id) async {
    final ok = await _service.eliminarUsuario(id);
    if (ok) {
      _usuarios = _usuarios.where((u) => u.id != id).toList();
      notifyListeners();
    }
    return ok;
  }

  Future<bool> editar(
    String id, {
    required String nombre,
    required String correo,
  }) async {
    _error = null;
    try {
      await _service.editarUsuario(id, nombre: nombre, correo: correo);
      await cargar();
      return true;
    } catch (e) {
      _error = _extraerDetail(e);
      notifyListeners();
      return false;
    }
  }

  Future<bool> toggleActivo(String id, bool nuevoEstado) async {
    _error = null;
    try {
      await _service.editarUsuario(id, activo: nuevoEstado);
      _usuarios = _usuarios
          .map((u) => u.id == id ? u.copyWith(activo: nuevoEstado) : u)
          .toList();
      notifyListeners();
      return true;
    } catch (e) {
      _error = _extraerDetail(e);
      notifyListeners();
      return false;
    }
  }

  /// Extrae el `detail` del backend de la excepción para mostrarlo limpio.
  /// `ApiException.toString()` ya devuelve el `message` directamente, así
  /// que basta con `e.toString()` y un fallback si quedase vacío.
  String _extraerDetail(Object e) {
    final s = e.toString().trim();
    if (s.isEmpty) return 'Error desconocido (sin detalle)';
    // Por si el toString viene como `Exception: foo` o `ApiException(...)`.
    final cleaned = s
        .replaceFirst(RegExp(r'^Exception:\s*'), '')
        .replaceFirst(RegExp(r'^ApiException\(\d+,\s*"?'), '')
        .replaceFirst(RegExp(r'"?\)$'), '');
    return cleaned.isEmpty ? s : cleaned;
  }

  Future<bool> cambiarRol(String id, String nuevoRol) async {
    final ok = await _service.cambiarRol(id, nuevoRol);
    if (ok) await cargar();
    return ok;
  }
}

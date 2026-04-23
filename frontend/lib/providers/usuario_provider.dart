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

  Future<bool> cambiarRol(String id, String nuevoRol) async {
    final ok = await _service.cambiarRol(id, nuevoRol);
    if (ok) await cargar();
    return ok;
  }
}

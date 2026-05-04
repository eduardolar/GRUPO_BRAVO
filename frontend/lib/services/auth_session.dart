/// Mantiene en memoria el token JWT emitido por el backend tras un login
/// satisfactorio y permite construir cabeceras `Authorization: Bearer ...`
/// para las peticiones autenticadas.
///
/// Persistencia: por ahora sólo en memoria (no se almacena en disco). Si en
/// el futuro se quiere mantener la sesión entre reinicios, leer/escribir
/// `flutter_secure_storage` desde aquí — el resto de la app no debería
/// notar el cambio.
library;

class AuthSession {
  static String? _token;
  static String? _userId;
  static String? _correo;
  static String? _rol;

  /// Guarda los datos de la sesión recibidos del backend.
  static void guardar({
    required String? token,
    String? userId,
    String? correo,
    String? rol,
  }) {
    _token = (token != null && token.isNotEmpty) ? token : null;
    _userId = userId;
    _correo = correo;
    _rol = rol;
  }

  /// Borra todo rastro del token (logout).
  static void limpiar() {
    _token = null;
    _userId = null;
    _correo = null;
    _rol = null;
  }

  static String? get token => _token;
  static String? get userId => _userId;
  static String? get correo => _correo;
  static String? get rol => _rol;
  static bool get autenticado => _token != null;

  /// Construye los headers HTTP estándar añadiendo `Authorization: Bearer`
  /// cuando hay sesión activa. Si [extra] colisiona, prevalece [extra].
  static Map<String, String> headers({Map<String, String>? extra, bool json = true}) {
    final h = <String, String>{};
    if (json) h['Content-Type'] = 'application/json';
    if (_token != null) h['Authorization'] = 'Bearer $_token';
    if (extra != null) h.addAll(extra);
    return h;
  }
}

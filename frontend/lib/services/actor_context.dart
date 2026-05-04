/// Identifica al usuario que está ejecutando una acción privilegiada.
///
/// Se settea desde [AuthProvider] al iniciar/cerrar sesión y los servicios
/// que tocan endpoints con auditoría (crear/editar/eliminar usuarios, cambiar
/// rol…) lo leen para añadir el header `X-Actor` y que el backend lo registre
/// como `actor` del evento.
///
/// **Aviso de seguridad**: el header se rellena en el cliente y por tanto es
/// trivialmente falsificable. Sirve como rastro de auditoría coherente con el
/// estado actual del backend (sin JWT). Cuando se introduzca autenticación
/// real el backend deberá ignorar este header y leer el actor del token.
class ActorContext {
  ActorContext._();
  static final ActorContext instance = ActorContext._();

  String? _email;

  String? get email => _email;

  void set(String? email) {
    _email = (email != null && email.isNotEmpty) ? email : null;
  }

  void clear() {
    _email = null;
  }

  /// Cabeceras a añadir en peticiones que registran auditoría.
  Map<String, String> get headers {
    final e = _email;
    if (e == null) return const {};
    return {'X-Actor': e};
  }
}

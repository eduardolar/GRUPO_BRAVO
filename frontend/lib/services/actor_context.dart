/// Identifica al usuario que está ejecutando una acción privilegiada.
///
/// Se settea desde [AuthProvider] al iniciar/cerrar sesión y los servicios
/// que tocan endpoints con auditoría (crear/editar/eliminar usuarios, cambiar
/// rol…) lo añaden como header `X-Actor`.
///
/// **Cómo lo usa el backend**: desde la introducción del JWT, `_actor_de()`
/// del backend lee el correo del **token firmado** (no falsificable) y solo
/// cae a `X-Actor` cuando la petición no lleva Bearer (flujos públicos).
/// Por tanto este helper queda como complemento — es seguro mantenerlo,
/// pero **el rastro de auditoría real lo da el JWT**, no este header.
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

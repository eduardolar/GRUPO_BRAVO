enum RolUsuario { cliente, trabajador, administrador, superadministrador }

class Usuario {
  final String id;
  final String nombre;
  final String email;
  final String contrasena;
  final String telefono;
  final String direccion;
  final RolUsuario rol;
  // Rol exacto devuelto por la API (cocinero, camarero, mesero, …).
  // Usar este campo para mostrar y agrupar en pantalla.
  final String rolRaw;
  final String? restauranteId;

  Usuario({
    required this.id,
    required this.nombre,
    required this.email,
    required this.contrasena,
    required this.telefono,
    required this.direccion,
    this.rol = RolUsuario.cliente,
    String? rolRaw,
    this.restauranteId,
  }) : rolRaw = rolRaw ?? rol.name;

  factory Usuario.fromJson(Map<String, dynamic> json) {
    final rawRol = (json['rol'] ?? '').toString().toLowerCase().trim();
    final normalizedRol = _normalizeRol(rawRol);
    return Usuario(
      id: json['id'] ?? json['_id'] ?? '',
      nombre: json['nombre'] ?? '',
      email: json['correo'] ?? json['email'] ?? '',
      contrasena: json['password_hash'] ?? json['contrasena'] ?? '',
      telefono: json['telefono'] ?? '',
      direccion: json['direccion'] ?? '',
      rol: _parseRol(normalizedRol),
      rolRaw: normalizedRol,
      restauranteId: json['restaurante_id']?.toString(),
    );
  }

  // Normaliza aliases a nombres canónicos ("admin" → "administrador", etc.)
  static String _normalizeRol(String rolStr) {
    switch (rolStr) {
      case 'admin': return 'administrador';
      case 'superadmin': return 'superadministrador';
      default: return rolStr;
    }
  }

  static RolUsuario _parseRol(String rolStr) {
    switch (rolStr) {
      case 'superadministrador':
        return RolUsuario.superadministrador;
      case 'cocinero':
      case 'camarero':
      case 'mesero':
      case 'trabajador':
        return RolUsuario.trabajador;
      case 'administrador':
        return RolUsuario.administrador;
      default:
        return RolUsuario.cliente;
    }
  }

  Usuario copyWith({
    String? nombre,
    String? email,
    String? contrasena,
    String? telefono,
    String? direccion,
    RolUsuario? rol,
    String? rolRaw,
    String? restauranteId,
  }) {
    return Usuario(
      id: id,
      nombre: nombre ?? this.nombre,
      email: email ?? this.email,
      contrasena: contrasena ?? this.contrasena,
      telefono: telefono ?? this.telefono,
      direccion: direccion ?? this.direccion,
      rol: rol ?? this.rol,
      rolRaw: rolRaw ?? this.rolRaw,
      restauranteId: restauranteId ?? this.restauranteId,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nombre': nombre,
      'email': email,
      'contrasena': contrasena,
      'telefono': telefono,
      'direccion': direccion,
      'rol': rolRaw,
      if (restauranteId != null) 'restaurante_id': restauranteId,
    };
  }
}

enum RolUsuario { cliente, trabajador, administrador, superadministrador }

class Usuario {
  final String id;
  final String nombre;
  final String email;
  final String contrasena;
  final String telefono;
  final String direccion;
  final RolUsuario rol;

  Usuario({
    required this.id,
    required this.nombre,
    required this.email,
    required this.contrasena,
    required this.telefono,
    required this.direccion,
    this.rol = RolUsuario.cliente,
  });

  // Factory para crear desde JSON (útil para API real)
  factory Usuario.fromJson(Map<String, dynamic> json) {
    return Usuario(
      id: json['id'] ?? json['_id'] ?? '',
      nombre: json['nombre'] ?? '',
      email: json['correo'] ?? json['email'] ?? '',
      contrasena: json['password_hash'] ?? json['contrasena'] ?? '',
      telefono: json['telefono'] ?? '',
      direccion: json['direccion'] ?? '',
      rol: _parseRol(json['rol']),
    );
  }

static RolUsuario _parseRol(dynamic rol) {
  if (rol == null) return RolUsuario.cliente;
  
  final String rolStr = rol.toString().toLowerCase().trim();
  
  switch (rolStr) {
    case 'superadministrador':
    case 'superadmin':
      return RolUsuario.superadministrador;
    case 'cocinero':      // añadimos casos comunes para trabajadores
    case 'camarero':
    case 'mesero':
    case 'trabajador':
      return RolUsuario.trabajador;
    case 'administrador':
    case 'admin':
      return RolUsuario.administrador;
    default:
      return RolUsuario.cliente;
  }
}

  // Copia con campos modificados
  Usuario copyWith({
    String? nombre,
    String? email,
    String? contrasena,
    String? telefono,
    String? direccion,
    RolUsuario? rol,
  }) {
    return Usuario(
      id: id,
      nombre: nombre ?? this.nombre,
      email: email ?? this.email,
      contrasena: contrasena ?? this.contrasena,
      telefono: telefono ?? this.telefono,
      direccion: direccion ?? this.direccion,
      rol: rol ?? this.rol,
    );
  }

  // Convertir a JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nombre': nombre,
      'email': email,
      'contrasena': contrasena,
      'telefono': telefono,
      'direccion': direccion,
      'rol': rol.name,
    };
  }
}

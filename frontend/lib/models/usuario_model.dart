enum RolUsuario { cliente, trabajador, cocinero, administrador, superadministrador }

class Usuario {
  final String id;
  final String nombre;
  final String email;
  final String contrasena;
  final String telefono;
  final String direccion;
  final double? latitud;  //nuevas propiedades para geolocalización
  final double? longitud;
  final RolUsuario rol;
  final String? restauranteId; // Para trabajadores, el restaurante al que pertenecen

  String get rolRaw => rol.name;

  Usuario copyWith({
    String? id,
    String? nombre,
    String? email,
    String? contrasena,
    String? telefono,
    String? direccion,
    double? latitud,
    double? longitud,
    RolUsuario? rol,
    String? restauranteId,
    String? rolRaw,
  }) {
    return Usuario(
      id: id ?? this.id,
      nombre: nombre ?? this.nombre,
      email: email ?? this.email,
      contrasena: contrasena ?? this.contrasena,
      telefono: telefono ?? this.telefono,
      direccion: direccion ?? this.direccion,
      latitud: latitud ?? this.latitud,
      longitud: longitud ?? this.longitud,
      rol: rol ?? this.rol,
      restauranteId: restauranteId ?? this.restauranteId,
    );
  }
  Usuario({
    required this.id,
    required this.nombre,
    required this.email,
    required this.contrasena,
    required this.telefono,
    required this.direccion,
    this.latitud,
    this.longitud,
    this.rol = RolUsuario.cliente,
    this.restauranteId,

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
      // Mapeamos los nuevos campos desde el JSON de Python
      latitud: json['latitud'] != null ? double.parse(json['latitud'].toString()) : null,
      longitud: json['longitud'] != null ? double.parse(json['longitud'].toString()) : null,
      rol: _parseRol(json['rol']),
      restauranteId: json['restaurante_id'] ?.toString(),
    );
  }

static RolUsuario _parseRol(dynamic rol) {
  if (rol == null) return RolUsuario.cliente;
  
  final String rolStr = rol.toString().toLowerCase().trim();
  
  switch (rolStr) {
    case 'superadministrador':
    case 'superadmin':
      return RolUsuario.superadministrador;
    case 'cocinero':
      return RolUsuario.cocinero;
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
      if (restauranteId != null) 'restaurante_id': restauranteId,
    };
  }
}

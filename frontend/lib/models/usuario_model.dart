class Usuario {
  final String id;
  final String nombre;
  final String email;
  final String contrasena;
  final String telefono;
  final String direccion;

  Usuario({
    required this.id,
    required this.nombre,
    required this.email,
    required this.contrasena,
    required this.telefono,
    required this.direccion,
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
    );
  }

  // Copia con campos modificados
  Usuario copyWith({
    String? nombre,
    String? email,
    String? contrasena,
    String? telefono,
    String? direccion,
  }) {
    return Usuario(
      id: id,
      nombre: nombre ?? this.nombre,
      email: email ?? this.email,
      contrasena: contrasena ?? this.contrasena,
      telefono: telefono ?? this.telefono,
      direccion: direccion ?? this.direccion,
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
    };
  }
}

class Restaurante {
  final String id;
  final String nombre;
  final String direccion;
  final String codigo;

  Restaurante({
    required this.id, 
    required this.nombre, 
    required this.direccion, 
    required this.codigo
  });

  factory Restaurante.fromJson(Map<String, dynamic> json) {
    return Restaurante(
      id: json['id'] ?? '',
      nombre: json['nombre'] ?? '',
      direccion: json['direccion'] ?? '',
      codigo: json['codigo'] ?? '',
    );
  }
}
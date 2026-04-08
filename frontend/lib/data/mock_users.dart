import '../models/usuario_model.dart';

class MockUsers {
  // Lista de usuarios mock para autenticación
  static final List<Usuario> usuarios = [
    Usuario(
      id: 'u_01',
      nombre: 'Eduardo',
      email: 'edu@ejemplo.com',
      contrasena: '123456',
      telefono: '123456789',
      direccion: 'Calle Ficticia 123',
      rol: RolUsuario.cliente,
    ),
    Usuario(
      id: 'u_02',
      nombre: 'Jose',
      email: 'jose@ejemplo.com',
      contrasena: '123456',
      telefono: '987654321',
      direccion: 'Avenida Imaginaria 456',
      rol: RolUsuario.trabajador,
    ),
    Usuario(
      id: 'u_03',
      nombre: 'Pelayo',
      email: 'pelayo@ejemplo.com',
      contrasena: '123456',
      telefono: '987654321',
      direccion: 'Avenida Imaginaria 456',
      rol: RolUsuario.administrador,
    ),
  ];
}

import '../models/producto_model.dart';
import '../models/pedido_model.dart';
import '../models/mesa_model.dart';
import '../models/reserva_model.dart';
import '../models/ingrediente_model.dart';

import 'auth_service.dart';
import 'producto_service.dart';
import 'ingredientes_service.dart';
import 'pedido_service.dart';
import 'reserva_service.dart';
import 'mesa_service.dart';

/// Fachada que delega en los sub-servicios.
/// Mantiene la misma API pública para no romper imports existentes.
class ApiService {
  // ─── AUTH ────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> iniciarSesion({
    required String correo,
    required String contrasena,
  }) => AuthService.iniciarSesion(correo: correo, contrasena: contrasena);

  static Future<Map<String, dynamic>> registrarUsuario({
    required String nombre,
    required String correo,
    required String contrasena,
    required String telefono,
    required String direccion,
  }) => AuthService.registrarUsuario(
    nombre: nombre,
    correo: correo,
    contrasena: contrasena,
    telefono: telefono,
    direccion: direccion,
  );

  static Future<bool> actualizarPerfil({
    required String userId,
    required String nombre,
    required String email,
    required String telefono,
    required String direccion,
  }) => AuthService.actualizarPerfil(
    userId: userId,
    nombre: nombre,
    email: email,
    telefono: telefono,
    direccion: direccion,
  );

  static Future<Map<String, dynamic>> verPerfil({required String userId}) =>
      AuthService.verPerfil(userId: userId);

  static Future<bool> eliminarPerfil({required String userId}) =>
      AuthService.eliminarPerfil(userId: userId);

  static Future<bool> eliminarCuenta({required String userId}) =>
      AuthService.eliminarCuenta(userId: userId);

  // ─── PRODUCTOS ───────────────────────────────────────────────

  static Future<List<String>> obtenerCategorias() =>
      ProductoService.obtenerCategorias();

  static Future<List<Producto>> obtenerProductos({String? categoria}) =>
      ProductoService.obtenerProductos(categoria: categoria);

  static Future<List<Ingrediente>> obtenerIngredientes({String? categoria}) =>
      IngredienteService.obtenerIngredientes(categoria: categoria);
  // ─── PEDIDOS ─────────────────────────────────────────────────

  static Future<Map<String, dynamic>> crearPedido({
    required String userId,
    required List<Map<String, dynamic>> items,
    required String tipoEntrega,
    required String metodoPago,
    required double total,
    String? direccionEntrega,
    String? mesaId,
    int? numeroMesa,
    String? notas,
  }) => PedidoService.crearPedido(
    userId: userId,
    items: items,
    tipoEntrega: tipoEntrega,
    metodoPago: metodoPago,
    total: total,
    direccionEntrega: direccionEntrega,
    mesaId: mesaId,
    numeroMesa: numeroMesa,
    notas: notas,
  );

  static Future<List<Pedido>> obtenerHistorialPedidos({
    required String userId,
  }) => PedidoService.obtenerHistorialPedidos(userId: userId);

  // ─── MESAS ───────────────────────────────────────────────────

  static Future<List<Mesa>> obtenerMesas() => MesaService.obtenerMesas();

  // ─── RESERVAS ────────────────────────────────────────────────

  static Future<Reserva> crearReserva({
    required String userId,
    required String nombreCompleto,
    required DateTime fecha,
    required String hora,
    required int comensales,
    required String turno,
    String? notas,
  }) => ReservaService.crearReserva(
    userId: userId,
    nombreCompleto: nombreCompleto, 
    fecha: fecha,
    hora: hora,
    comensales: comensales,
    turno: turno,
    notas: notas,
  );

  static Future<bool> hayDisponibilidad({
    required DateTime fecha,
    required String hora,
    required int comensales,
  }) => ReservaService.hayDisponibilidad(
    fecha: fecha,
    hora: hora,
    comensales: comensales,
  );

  static Future<List<Reserva>> obtenerReservas({required String userId}) =>
      ReservaService.obtenerReservas(userId: userId);

  static Future<bool> eliminarReserva({required String reservaId}) =>
      ReservaService.eliminarReserva(reservaId: reservaId);

  // ─── QR / MESA ──────────────────────────────────────────────

  static Future<Map<String, dynamic>> validarQrMesa({
    required String codigoQr,
  }) => MesaService.validarQrMesa(codigoQr: codigoQr);
}

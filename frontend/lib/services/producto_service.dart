import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/producto_model.dart';
import '../data/mock_data.dart';
import 'api_config.dart';
import 'http_client.dart';

class ProductoService {
  static const Map<String, String> _jsonHeaders = {
    'Content-Type': 'application/json',
  };

  // ─── CATEGORÍAS ──────────────────────────────────────────────

  static Future<List<String>> obtenerCategorias() async {
    if (!usarApiReal) {
      await Future.delayed(const Duration(milliseconds: 200));
      return List.from(MockData.categorias);
    }

    final response = await httpWithRetry(
      () => http.get(Uri.parse('$baseUrl/categorias')),
    );
    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.cast<String>();
    }
    throw toApiException(response.statusCode, decodeBody(response));
  }

  static Future<void> crearCategoria(String nombre) async {
    final limpio = nombre.trim();
    if (limpio.isEmpty) {
      throw Exception('El nombre de la categoría no puede estar vacío');
    }
    if (!usarApiReal) {
      await Future.delayed(const Duration(milliseconds: 150));
      if (MockData.categorias.contains(limpio)) {
        throw Exception('La categoría ya existe');
      }
      MockData.categorias.add(limpio);
      return;
    }
    final response = await httpWithRetry(
      () => http.post(
        Uri.parse('$baseUrl/categorias'),
        headers: _jsonHeaders,
        body: jsonEncode({'nombre': limpio}),
      ),
      retry: false,
    );
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw toApiException(response.statusCode, decodeBody(response));
    }
  }

  static Future<void> renombrarCategoria(
    String nombreActual,
    String nuevoNombre,
  ) async {
    final limpio = nuevoNombre.trim();
    if (limpio.isEmpty) {
      throw Exception('El nombre de la categoría no puede estar vacío');
    }
    if (!usarApiReal) {
      await Future.delayed(const Duration(milliseconds: 150));
      final idx = MockData.categorias.indexOf(nombreActual);
      if (idx == -1) throw Exception('Categoría no encontrada');
      if (limpio != nombreActual && MockData.categorias.contains(limpio)) {
        throw Exception('Ya existe una categoría con ese nombre');
      }
      MockData.categorias[idx] = limpio;
      // Re-asignamos los productos a la nueva categoría
      for (var i = 0; i < MockData.productos.length; i++) {
        final p = MockData.productos[i];
        if (p.categoria == nombreActual) {
          MockData.productos[i] = Producto(
            id: p.id,
            nombre: p.nombre,
            descripcion: p.descripcion,
            precio: p.precio,
            categoria: limpio,
            imagenUrl: p.imagenUrl,
            estaDisponible: p.estaDisponible,
            ingredientes: p.ingredientes,
          );
        }
      }
      return;
    }
    final response = await httpWithRetry(
      () => http.put(
        Uri.parse(
          '$baseUrl/categorias/${Uri.encodeComponent(nombreActual)}',
        ),
        headers: _jsonHeaders,
        body: jsonEncode({'nombre': limpio}),
      ),
      retry: false,
    );
    if (response.statusCode != 200) {
      throw toApiException(response.statusCode, decodeBody(response));
    }
  }

  static Future<void> reordenarCategorias(List<String> nuevoOrden) async {
    if (!usarApiReal) {
      await Future.delayed(const Duration(milliseconds: 100));
      MockData.categorias
        ..clear()
        ..addAll(nuevoOrden);
      return;
    }
    final response = await httpWithRetry(
      () => http.put(
        Uri.parse('$baseUrl/categorias/orden'),
        headers: _jsonHeaders,
        body: jsonEncode({'orden': nuevoOrden}),
      ),
      retry: false,
    );
    if (response.statusCode != 200) {
      throw toApiException(response.statusCode, decodeBody(response));
    }
  }

  static Future<void> eliminarCategoria(String nombre) async {
    if (!usarApiReal) {
      await Future.delayed(const Duration(milliseconds: 150));
      MockData.categorias.remove(nombre);
      MockData.productos.removeWhere((p) => p.categoria == nombre);
      return;
    }
    final response = await httpWithRetry(
      () => http.delete(
        Uri.parse('$baseUrl/categorias/${Uri.encodeComponent(nombre)}'),
      ),
      retry: false,
    );
    if (response.statusCode != 200 && response.statusCode != 204) {
      throw toApiException(response.statusCode, decodeBody(response));
    }
  }

  // ─── PRODUCTOS ───────────────────────────────────────────────

  static Future<List<Producto>> obtenerProductos({String? categoria}) async {
    if (!usarApiReal) {
      await Future.delayed(const Duration(milliseconds: 300));
      final productos = MockData.productos;
      if (categoria != null) {
        return productos.where((p) => p.categoria == categoria).toList();
      }
      return List.from(productos);
    }

    final uri = categoria != null
        ? Uri.parse('$baseUrl/productos?categoria=$categoria')
        : Uri.parse('$baseUrl/productos');
    final response = await httpWithRetry(() => http.get(uri));
    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((json) => Producto.fromMap(json)).toList();
    }
    throw toApiException(response.statusCode, decodeBody(response));
  }

  static Future<Producto> crearProducto(Map<String, dynamic> datos) async {
    if (!usarApiReal) {
      await Future.delayed(const Duration(milliseconds: 200));
      final id =
          'p_${DateTime.now().millisecondsSinceEpoch.toRadixString(36)}';
      final producto = Producto.fromMap({...datos, 'id': id});
      MockData.productos.add(producto);
      return producto;
    }
    final response = await httpWithRetry(
      () => http.post(
        Uri.parse('$baseUrl/productos'),
        headers: _jsonHeaders,
        body: jsonEncode(datos),
      ),
      retry: false,
    );
    if (response.statusCode == 200 || response.statusCode == 201) {
      return Producto.fromMap(jsonDecode(response.body));
    }
    throw toApiException(response.statusCode, decodeBody(response));
  }

  static Future<Producto> actualizarProducto(
    String id,
    Map<String, dynamic> datos,
  ) async {
    if (!usarApiReal) {
      await Future.delayed(const Duration(milliseconds: 200));
      final idx = MockData.productos.indexWhere((p) => p.id == id);
      if (idx == -1) throw Exception('Producto no encontrado');
      final actualizado = Producto.fromMap({...datos, 'id': id});
      MockData.productos[idx] = actualizado;
      return actualizado;
    }
    final response = await httpWithRetry(
      () => http.put(
        Uri.parse('$baseUrl/productos/$id'),
        headers: _jsonHeaders,
        body: jsonEncode(datos),
      ),
      retry: false,
    );
    if (response.statusCode == 200) {
      return Producto.fromMap(jsonDecode(response.body));
    }
    throw toApiException(response.statusCode, decodeBody(response));
  }

  static Future<void> reordenarProductos(List<String> ids) async {
    if (!usarApiReal) {
      await Future.delayed(const Duration(milliseconds: 100));
      return;
    }
    final response = await httpWithRetry(
      () => http.put(
        Uri.parse('$baseUrl/productos/orden'),
        headers: _jsonHeaders,
        body: jsonEncode({'orden': ids}),
      ),
      retry: false,
    );
    if (response.statusCode != 200) {
      throw toApiException(response.statusCode, decodeBody(response));
    }
  }

  static Future<void> eliminarProducto(String id) async {
    if (!usarApiReal) {
      await Future.delayed(const Duration(milliseconds: 150));
      MockData.productos.removeWhere((p) => p.id == id);
      return;
    }
    final response = await httpWithRetry(
      () => http.delete(Uri.parse('$baseUrl/productos/$id')),
      retry: false,
    );
    if (response.statusCode != 200 && response.statusCode != 204) {
      throw toApiException(response.statusCode, decodeBody(response));
    }
  }
}

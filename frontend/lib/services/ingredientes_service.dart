import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/ingrediente_model.dart';
import 'api_config.dart';
import 'http_client.dart';
import 'auth_session.dart';

class IngredienteService {
  static const List<String> categorias = [
    'Carnes',
    'Mariscos y Pescados',
    'Verduras',
    'Lácteos',
    'Panadería',
    'Salsas y Condimentos',
    'Especias',
    'Almidones y Cereales',
    'Huevos',
    'Frutas',
    'Otros',
  ];

  static const List<String> unidades = ['kg', 'l', 'g', 'unidades'];

  static final List<Ingrediente> _mockIngredientes = [
    Ingrediente(
      id: '1',
      nombre: 'Carne de Vacuno',
      cantidadActual: 30,
      unidad: 'kg',
      stockMinimo: 10,
      categoria: 'Carnes',
    ),
    Ingrediente(
      id: '2',
      nombre: 'Pechuga de Pollo',
      cantidadActual: 20,
      unidad: 'kg',
      stockMinimo: 8,
      categoria: 'Carnes',
    ),
    Ingrediente(
      id: '3',
      nombre: 'Tomate',
      cantidadActual: 50,
      unidad: 'kg',
      stockMinimo: 10,
      categoria: 'Verduras',
    ),
    Ingrediente(
      id: '4',
      nombre: 'Lechuga',
      cantidadActual: 20,
      unidad: 'kg',
      stockMinimo: 5,
      categoria: 'Verduras',
    ),
    Ingrediente(
      id: '5',
      nombre: 'Queso Cheddar',
      cantidadActual: 15,
      unidad: 'kg',
      stockMinimo: 4,
      categoria: 'Lácteos',
    ),
    Ingrediente(
      id: '6',
      nombre: 'Pan de Hamburguesa',
      cantidadActual: 100,
      unidad: 'unidades',
      stockMinimo: 20,
      categoria: 'Panadería',
    ),
    Ingrediente(
      id: '7',
      nombre: 'Ketchup',
      cantidadActual: 20,
      unidad: 'l',
      stockMinimo: 5,
      categoria: 'Salsas y Condimentos',
    ),
    Ingrediente(
      id: '8',
      nombre: 'Sal',
      cantidadActual: 10,
      unidad: 'kg',
      stockMinimo: 2,
      categoria: 'Especias',
    ),
    Ingrediente(
      id: '9',
      nombre: 'Gambas',
      cantidadActual: 3,
      unidad: 'kg',
      stockMinimo: 4,
      categoria: 'Mariscos y Pescados',
    ),
    Ingrediente(
      id: '10',
      nombre: 'Patatas',
      cantidadActual: 80,
      unidad: 'kg',
      stockMinimo: 20,
      categoria: 'Almidones y Cereales',
    ),
  ];

  static Future<List<Ingrediente>> obtenerIngredientes({
    String? restauranteId,
  }) async {
    if (!usarApiReal) {
      await Future.delayed(const Duration(milliseconds: 300));
      return List.from(_mockIngredientes);
    }
    final uri = Uri.parse('$baseUrl/ingredientes').replace(
      queryParameters: restauranteId != null
          ? {'restaurante_id': restauranteId}
          : null,
    );
    final response = await httpWithRetry(
      () => http.get(uri, headers: AuthSession.headers()),
    );
    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(utf8.decode(response.bodyBytes));
      return data.map((json) => Ingrediente.fromJson(json)).toList();
    }
    throw toApiException(response.statusCode, decodeBody(response));
  }

  static Future<Map<String, List<Ingrediente>>>
  obtenerIngredientesPorCategoria({String? restauranteId}) async {
    if (!usarApiReal) {
      await Future.delayed(const Duration(milliseconds: 300));
      final Map<String, List<Ingrediente>> agrupados = {};
      for (final ing in _mockIngredientes) {
        agrupados.putIfAbsent(ing.categoria, () => []).add(ing);
      }
      return agrupados;
    }
    final uri = Uri.parse('$baseUrl/ingredientes/por-categoria').replace(
      queryParameters: restauranteId != null
          ? {'restaurante_id': restauranteId}
          : null,
    );
    final response = await httpWithRetry(
      () => http.get(uri, headers: AuthSession.headers()),
    );
    if (response.statusCode == 200) {
      final Map<String, dynamic> data = jsonDecode(
        utf8.decode(response.bodyBytes),
      );
      return data.map((key, value) {
        final lista = (value as List)
            .map((json) => Ingrediente.fromJson(json))
            .toList();
        return MapEntry(key, lista);
      });
    }
    throw toApiException(response.statusCode, decodeBody(response));
  }

  static Future<void> crearIngrediente(Map<String, dynamic> datos) async {
    final response = await httpWithRetry(
      () => http.post(
        Uri.parse('$baseUrl/ingredientes'),
        headers: AuthSession.headers(),
        body: jsonEncode(datos),
      ),
      retry: false,
    );
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw toApiException(response.statusCode, decodeBody(response));
    }
  }

  static Future<void> actualizarIngrediente(
    String id,
    Map<String, dynamic> datos,
  ) async {
    final response = await httpWithRetry(
      () => http.put(
        Uri.parse('$baseUrl/ingredientes/$id'),
        headers: AuthSession.headers(),
        body: jsonEncode(datos),
      ),
      retry: false,
    );
    if (response.statusCode != 200) {
      throw toApiException(response.statusCode, decodeBody(response));
    }
  }

  static Future<void> eliminarIngrediente(String id) async {
    final response = await httpWithRetry(
      () => http.delete(
        Uri.parse('$baseUrl/ingredientes/$id'),
        headers: AuthSession.headers(),
      ),
      retry: false,
    );
    if (response.statusCode != 200) {
      throw toApiException(response.statusCode, decodeBody(response));
    }
  }

  /// Devuelve grupos de ingredientes duplicados (mismo nombre normalizado en
  /// la misma sucursal). Cada grupo incluye la lista completa y el `principal`
  /// sugerido por el backend (el de mayor stock).
  static Future<List<Map<String, dynamic>>> obtenerDuplicados({
    String? restauranteId,
  }) async {
    final uri = Uri.parse('$baseUrl/ingredientes/duplicados').replace(
      queryParameters: restauranteId != null
          ? {'restaurante_id': restauranteId}
          : null,
    );
    final response = await httpWithRetry(
      () => http.get(uri, headers: AuthSession.headers()),
    );
    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(utf8.decode(response.bodyBytes));
      return List<Map<String, dynamic>>.from(data);
    }
    throw toApiException(response.statusCode, decodeBody(response));
  }

  /// Fusiona varios ingredientes en uno: suma stock al `principal` y borra los
  /// `absorber`. También reescribe el `ingrediente_id` en los productos que
  /// referenciaban a los absorbidos.
  /// Devuelve `{fusionados: int, stock_total_principal: float}`.
  static Future<Map<String, dynamic>> fusionarIngredientes({
    required String principalId,
    required List<String> absorberIds,
  }) async {
    final response = await httpWithRetry(
      () => http.post(
        Uri.parse('$baseUrl/ingredientes/fusionar'),
        headers: AuthSession.headers(),
        body: jsonEncode({
          'principal_id': principalId,
          'absorber_ids': absorberIds,
        }),
      ),
      retry: false,
    );
    if (response.statusCode == 200) {
      return Map<String, dynamic>.from(decodeBody(response));
    }
    throw toApiException(response.statusCode, decodeBody(response));
  }

  static Future<List<Ingrediente>> obtenerIngredientesStockBajo({
    String? restauranteId,
  }) async {
    if (!usarApiReal) {
      await Future.delayed(const Duration(milliseconds: 300));
      return _mockIngredientes.where((i) => i.stockBajo).toList();
    }
    final uri = Uri.parse('$baseUrl/ingredientes/stock-bajo').replace(
      queryParameters: restauranteId != null
          ? {'restaurante_id': restauranteId}
          : null,
    );
    final response = await httpWithRetry(
      () => http.get(uri, headers: AuthSession.headers()),
    );
    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(utf8.decode(response.bodyBytes));
      return data.map((json) => Ingrediente.fromJson(json)).toList();
    }
    throw toApiException(response.statusCode, decodeBody(response));
  }
}

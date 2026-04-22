import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/ingrediente_model.dart';
import '../data/mock_data.dart';
import 'api_config.dart';

class IngredienteService {
  static final List<Ingrediente> _mockIngredientes = [
    Ingrediente(id: '1', nombre: 'Tomate', cantidadActual: 50, unidad: 'kg', stockMinimo: 10, categoria: 'Vegetales'),
    Ingrediente(id: '2', nombre: 'Queso', cantidadActual: 20, unidad: 'kg', stockMinimo: 5, categoria: 'Lácteos'),
    Ingrediente(id: '3', nombre: 'Lechuga', cantidadActual: 15, unidad: 'kg', stockMinimo: 8, categoria: 'Vegetales'),
    Ingrediente(id: '4', nombre: 'Carne', cantidadActual: 30, unidad: 'kg', stockMinimo: 12, categoria: 'Carnes'),
    Ingrediente(id: '5', nombre: 'Pan', cantidadActual: 100, unidad: 'unidades', stockMinimo: 20, categoria: 'Panadería'),
  ];

  static Future<List<String>> obtenerCategorias() async {
    if (!usarApiReal) {
      await Future.delayed(const Duration(milliseconds: 200));
      return List.from(MockData.categorias);
    }
    final response = await http.get(Uri.parse('$baseUrl/categorias'));
    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.cast<String>();
    } else {
      throw Exception('Error al obtener categorías');
    }
  }

  // OBTENER
  static Future<List<Ingrediente>> obtenerIngredientes({String? categoria}) async {
    if (!usarApiReal) {
      await Future.delayed(const Duration(milliseconds: 300));
      return List.from(_mockIngredientes);
    }
    final uri = categoria != null && categoria != 'Todas'
        ? Uri.parse('$baseUrl/ingredientes?categoria=$categoria')
        : Uri.parse('$baseUrl/ingredientes');
    final response = await http.get(uri);
    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((json) => Ingrediente.fromJson(json)).toList();
    } else {
      throw Exception('Error al obtener ingredientes');
    }
  }

  // CREAR (NUEVO)
  static Future<void> crearIngrediente(Map<String, dynamic> datos) async {
    final response = await http.post(
      Uri.parse('$baseUrl/ingredientes'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(datos),
    );
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception('Error al crear ingrediente');
    }
  }

  // ACTUALIZAR (NUEVO)
  static Future<void> actualizarIngrediente(String id, Map<String, dynamic> datos) async {
    final response = await http.put(
      Uri.parse('$baseUrl/ingredientes/$id'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(datos),
    );
    if (response.statusCode != 200) {
      throw Exception('Error al actualizar ingrediente');
    }
  }
}
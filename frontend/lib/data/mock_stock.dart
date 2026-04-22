import 'package:frontend/models/stock_model.dart';

class MockStock {
  static final List<Stock> stock = [
    Stock(id: "100", nombre: "Tomate", descripcion: "Tomate", estaDisponible: true),

    Stock(id: "101", nombre: "Cebolla", descripcion: "Cebolla", estaDisponible: true),

    Stock(id: "102", nombre: "Pepinillos", descripcion: "Pepinillos", estaDisponible: false),

    Stock(id: "103", nombre: "Pan", descripcion: "Pan", estaDisponible: true),

    Stock(id: "104", nombre: "Carne ternera", descripcion: "Carne ternera", estaDisponible: true),

    Stock(id: "105", nombre: "Mostaza", descripcion: "Mostaza", estaDisponible: false),

  ];
}
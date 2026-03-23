import '../models/producto_model.dart';

class MockData {
  // Lista de categorías para filtros en la UI
  static const List<String> categorias = [
    'Hamburguesas', 
    'Pizzas', 
    'Bebidas', 
    'Postres', 
    'Snacks'
  ];

  // Lista maestra de productos
  static final List<Producto> productos = [
    // --- HAMBURGUESAS ---
    Producto(
      id: 'b_01',
      nombre: 'Classic Cheese',
      descripcion: 'Carne de res 150g, doble queso cheddar y pan brioche.',
      precio: 12.50,
      categoria: 'Hamburguesas',
    ),
    Producto(
      id: 'b_02',
      nombre: 'Bacon BBQ',
      descripcion: 'Doble tocino, cebolla frita y salsa barbacoa ahumada.',
      precio: 14.90,
      categoria: 'Hamburguesas',
    ),
    Producto(
      id: 'b_03',
      nombre: 'Veggie Avocado',
      descripcion: 'Medallón de lentejas, aguacate fresco y alioli de ajo.',
      precio: 11.00,
      categoria: 'Hamburguesas',
    ),
    Producto(
      id: 'b_04',
      nombre: 'Trufa & Hongos',
      descripcion: 'Hongos salteados, aceite de trufa y queso suizo.',
      precio: 16.00,
      categoria: 'Hamburguesas',
    ),

    // --- PIZZAS ---
    Producto(
      id: 'z_01',
      nombre: 'Margarita Especial',
      descripcion: 'Tomates cherry, albahaca fresca y mozzarella de búfala.',
      precio: 14.00,
      categoria: 'Pizzas',
    ),
    Producto(
      id: 'z_02',
      nombre: 'Cuatro Quesos',
      descripcion: 'Mezcla premium de Gorgonzola, Parmesano y Mozzarella.',
      precio: 17.50,
      categoria: 'Pizzas',
    ),
    Producto(
      id: 'z_03',
      nombre: 'Pepperoni Blast',
      descripcion: 'Doble porción de pepperoni crujiente con miel picante.',
      precio: 15.50,
      categoria: 'Pizzas',
    ),

    // --- BEBIDAS ---
    Producto(
      id: 'd_01',
      nombre: 'Limonada Menta',
      descripcion: 'Zumo de limón natural, menta fresca y mucho hielo.',
      precio: 4.50,
      categoria: 'Bebidas',
    ),
    Producto(
      id: 'd_02',
      nombre: 'Iced Caramel Latte',
      descripcion: 'Café de especialidad con caramelo y leche de almendras.',
      precio: 5.50,
      categoria: 'Bebidas',
    ),
    Producto(
      id: 'd_03',
      nombre: 'Cerveza Artesanal',
      descripcion: 'IPA local con notas cítricas y amargor equilibrado.',
      precio: 6.50,
      categoria: 'Bebidas',
    ),

    // --- POSTRES ---
    Producto(
      id: 'p_01',
      nombre: 'Brownie con Helado',
      descripcion: 'Chocolate amargo templado con helado de vainilla.',
      precio: 7.50,
      categoria: 'Postres',
    ),
    Producto(
      id: 'p_02',
      nombre: 'Cheesecake Frutos Rojos',
      descripcion: 'Base de galleta crujiente y coulis de frambuesa.',
      precio: 8.00,
      categoria: 'Postres',
    ),
    Producto(
      id: 'p_03',
      nombre: 'Tiramisú',
      descripcion: 'Clásico italiano con mascarpone y café expreso.',
      precio: 8.50,
      categoria: 'Postres',
    ),

    // --- SNACKS ---
    Producto(
      id: 's_01',
      nombre: 'Papas Rústicas',
      descripcion: 'Papas cortadas a mano con romero y sal marina.',
      precio: 6.00,
      categoria: 'Snacks',
    ),
    Producto(
      id: 's_02',
      nombre: 'Alitas Picantes',
      descripcion: '6 unidades de alitas bañadas en salsa Buffalo.',
      precio: 9.50,
      categoria: 'Snacks',
    ),
    Producto(
      id: 's_03',
      nombre: 'Nachos Supreme',
      descripcion: 'Con queso fundido, guacamole y pico de gallo.',
      precio: 11.00,
      categoria: 'Snacks',
    ),
  ];
}
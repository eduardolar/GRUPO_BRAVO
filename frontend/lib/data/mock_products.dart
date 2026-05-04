import '../models/producto_model.dart';
import '../models/ingrediente_model.dart';

class MockProducts {
  // Lista maestra de productos
  static final List<Producto> productos = [
    // --- HAMBURGUESAS ---
    Producto(
      id: 'b_01',
      nombre: 'Classic Cheese',
      descripcion: 'Carne de res 150g, doble queso cheddar y pan brioche.',
      precio: 12.50,
      categoria: 'Hamburguesas',
      ingredientes: [
        Ingrediente(id: 'i_01', nombre: 'Pan brioche'),
        Ingrediente(id: 'i_02', nombre: 'Carne de res'),
        Ingrediente(id: 'i_03', nombre: 'Queso cheddar'),
        Ingrediente(id: 'i_04', nombre: 'Lechuga'),
        Ingrediente(id: 'i_05', nombre: 'Tomate'),
        Ingrediente(id: 'i_06', nombre: 'Cebolla'),
      ],
    ),
    Producto(
      id: 'b_02',
      nombre: 'Bacon BBQ',
      descripcion: 'Doble tocino, cebolla frita y salsa barbacoa ahumada.',
      precio: 14.90,
      categoria: 'Hamburguesas',
      ingredientes: [
        Ingrediente(id: 'i_01', nombre: 'Pan brioche'),
        Ingrediente(id: 'i_02', nombre: 'Carne de res'),
        Ingrediente(id: 'i_07', nombre: 'Bacon'),
        Ingrediente(id: 'i_06', nombre: 'Cebolla frita'),
        Ingrediente(id: 'i_08', nombre: 'Salsa BBQ'),
        Ingrediente(id: 'i_04', nombre: 'Lechuga'),
      ],
    ),
    Producto(
      id: 'b_03',
      nombre: 'Veggie Avocado',
      descripcion: 'Medallón de lentejas, aguacate fresco y alioli de ajo.',
      precio: 11.00,
      categoria: 'Hamburguesas',
      ingredientes: [
        Ingrediente(id: 'i_01', nombre: 'Pan brioche'),
        Ingrediente(id: 'i_09', nombre: 'Medallón de lentejas'),
        Ingrediente(id: 'i_10', nombre: 'Aguacate'),
        Ingrediente(id: 'i_11', nombre: 'Alioli de ajo'),
        Ingrediente(id: 'i_04', nombre: 'Lechuga'),
        Ingrediente(id: 'i_05', nombre: 'Tomate'),
      ],
    ),
    Producto(
      id: 'b_04',
      nombre: 'Trufa & Hongos',
      descripcion: 'Hongos salteados, aceite de trufa y queso suizo.',
      precio: 16.00,
      categoria: 'Hamburguesas',
      ingredientes: [
        Ingrediente(id: 'i_01', nombre: 'Pan brioche'),
        Ingrediente(id: 'i_02', nombre: 'Carne de res'),
        Ingrediente(id: 'i_12', nombre: 'Hongos'),
        Ingrediente(id: 'i_13', nombre: 'Aceite de trufa'),
        Ingrediente(id: 'i_14', nombre: 'Queso suizo'),
      ],
    ),

    // --- PIZZAS ---
    Producto(
      id: 'z_01',
      nombre: 'Margarita Especial',
      descripcion: 'Tomates cherry, albahaca fresca y mozzarella de búfala.',
      precio: 14.00,
      categoria: 'Pizzas',
      ingredientes: [
        Ingrediente(id: 'i_15', nombre: 'Masa'),
        Ingrediente(id: 'i_16', nombre: 'Salsa de tomate'),
        Ingrediente(id: 'i_17', nombre: 'Mozzarella de búfala'),
        Ingrediente(id: 'i_18', nombre: 'Tomates cherry'),
        Ingrediente(id: 'i_19', nombre: 'Albahaca'),
      ],
    ),
    Producto(
      id: 'z_02',
      nombre: 'Cuatro Quesos',
      descripcion: 'Mezcla premium de Gorgonzola, Parmesano y Mozzarella.',
      precio: 17.50,
      categoria: 'Pizzas',
      ingredientes: [
        Ingrediente(id: 'i_15', nombre: 'Masa'),
        Ingrediente(id: 'i_16', nombre: 'Salsa de tomate'),
        Ingrediente(id: 'i_20', nombre: 'Gorgonzola'),
        Ingrediente(id: 'i_21', nombre: 'Parmesano'),
        Ingrediente(id: 'i_17', nombre: 'Mozzarella'),
        Ingrediente(id: 'i_22', nombre: 'Queso de cabra'),
      ],
    ),
    Producto(
      id: 'z_03',
      nombre: 'Pepperoni Blast',
      descripcion: 'Doble porción de pepperoni crujiente con miel picante.',
      precio: 15.50,
      categoria: 'Pizzas',
      ingredientes: [
        Ingrediente(id: 'i_15', nombre: 'Masa'),
        Ingrediente(id: 'i_16', nombre: 'Salsa de tomate'),
        Ingrediente(id: 'i_17', nombre: 'Mozzarella'),
        Ingrediente(id: 'i_23', nombre: 'Pepperoni'),
        Ingrediente(id: 'i_24', nombre: 'Miel picante'),
      ],
    ),

    // --- BEBIDAS (sin ingredientes personalizables) ---
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
      ingredientes: [
        Ingrediente(id: 'i_25', nombre: 'Brownie'),
        Ingrediente(id: 'i_26', nombre: 'Helado de vainilla'),
        Ingrediente(id: 'i_27', nombre: 'Sirope de chocolate'),
        Ingrediente(id: 'i_28', nombre: 'Nata montada'),
      ],
    ),
    Producto(
      id: 'p_02',
      nombre: 'Cheesecake Frutos Rojos',
      descripcion: 'Base de galleta crujiente y coulis de frambuesa.',
      precio: 8.00,
      categoria: 'Postres',
      ingredientes: [
        Ingrediente(id: 'i_29', nombre: 'Base de galleta'),
        Ingrediente(id: 'i_30', nombre: 'Queso crema'),
        Ingrediente(id: 'i_31', nombre: 'Coulis de frambuesa'),
        Ingrediente(id: 'i_28', nombre: 'Nata montada'),
      ],
    ),
    Producto(
      id: 'p_03',
      nombre: 'Tiramisú',
      descripcion: 'Clásico italiano con mascarpone y café expreso.',
      precio: 8.50,
      categoria: 'Postres',
      ingredientes: [
        Ingrediente(id: 'i_32', nombre: 'Mascarpone'),
        Ingrediente(id: 'i_33', nombre: 'Café expreso'),
        Ingrediente(id: 'i_34', nombre: 'Bizcocho'),
        Ingrediente(id: 'i_35', nombre: 'Cacao en polvo'),
      ],
    ),

    // --- SNACKS ---
    Producto(
      id: 's_01',
      nombre: 'Papas Rústicas',
      descripcion: 'Papas cortadas a mano con romero y sal marina.',
      precio: 6.00,
      categoria: 'Snacks',
      ingredientes: [
        Ingrediente(id: 'i_36', nombre: 'Papas'),
        Ingrediente(id: 'i_37', nombre: 'Romero'),
        Ingrediente(id: 'i_38', nombre: 'Sal marina'),
      ],
    ),
    Producto(
      id: 's_02',
      nombre: 'Alitas Picantes',
      descripcion: '6 unidades de alitas bañadas en salsa Buffalo.',
      precio: 9.50,
      categoria: 'Snacks',
      ingredientes: [
        Ingrediente(id: 'i_39', nombre: 'Alitas de pollo'),
        Ingrediente(id: 'i_40', nombre: 'Salsa Buffalo'),
        Ingrediente(id: 'i_41', nombre: 'Salsa ranch'),
      ],
    ),
    Producto(
      id: 's_03',
      nombre: 'Nachos Supreme',
      descripcion: 'Con queso fundido, guacamole y pico de gallo.',
      precio: 11.00,
      categoria: 'Snacks',
      ingredientes: [
        Ingrediente(id: 'i_42', nombre: 'Nachos'),
        Ingrediente(id: 'i_43', nombre: 'Queso fundido'),
        Ingrediente(id: 'i_10', nombre: 'Guacamole'),
        Ingrediente(id: 'i_44', nombre: 'Pico de gallo'),
        Ingrediente(id: 'i_45', nombre: 'Jalapeños'),
        Ingrediente(id: 'i_46', nombre: 'Crema agria'),
      ],
    ),
  ];
}

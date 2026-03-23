import 'package:flutter/material.dart';
import '../core/colors_style.dart';
import '../data/mock_data.dart';
import '../components/producto_card.dart';
import '../models/producto_model.dart';

class MenuScreen extends StatefulWidget {
  const MenuScreen({super.key});

  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> {
  int selectedCategoryIndex = 0;

  // LÓGICA DEL CARRITO (Estado local por ahora)
 
  final Map<String, int> _cart = {};

  // Método para agregar al carrito
  void _addToCart(Producto product) {
    setState(() {
      if (_cart.containsKey(product.id)) {
        _cart[product.id] = _cart[product.id]! + 1;
      } else {
        _cart[product.id] = 1;
      }
    });

    // Feedback visual rápido para el usuario
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${product.nombre} añadido al carrito'),
        duration: const Duration(seconds: 1),
        backgroundColor: AppColors.button,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // Calculamos el total de items en el carrito sumando las cantidades
  int get _totalCartItems =>
      _cart.values.fold(0, (sum, quantity) => sum + quantity);

  @override
  Widget build(BuildContext context) {
    final currentCategory = MockData.categorias[selectedCategoryIndex];
    final filteredProducts = MockData.productos
        .where((p) => p.categoria == currentCategory)
        .toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: const Text(
          'MENÚ',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
        actions: [
          // ICONO DE CARRITO 
          Padding(
            padding: const EdgeInsets.only(right: 16, top: 8),
            child: Stack(
              children: [
                IconButton(
                  onPressed: () {
                    // Aquí navegaremos a la pantalla de Checkout
                    //TODO: Implementar navegación a Confirmar CArrito
                  },
                  icon: const Icon(
                    Icons.shopping_bag_outlined,
                    color: AppColors.gold,
                    size: 28,
                  ),
                ),
                if (_totalCartItems > 0)
                  Positioned(
                    right: 5,
                    top: 5,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 18,
                        minHeight: 18,
                      ),
                      child: Text(
                        '$_totalCartItems',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          const SizedBox(height: 10),
          _buildCategorySelector(),

          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: filteredProducts.isEmpty
                  ? const Center(
                      child: Text(
                        "No hay productos disponibles",
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                    )
                  : ListView.builder(
                      key: ValueKey<int>(
                        selectedCategoryIndex,
                      ), // Para que AnimatedSwitcher detecte el cambio
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      itemCount: filteredProducts.length,
                      itemBuilder: (context, index) {
                        final product = filteredProducts[index];
                        return ProductoCard(
                          product: product,
                          onAdd: () => _addToCart(product),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategorySelector() {
    return SizedBox(
      height: 55,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: MockData.categorias.length,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemBuilder: (context, index) {
          bool isSelected = selectedCategoryIndex == index;
          return GestureDetector(
            onTap: () => setState(() => selectedCategoryIndex = index),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(right: 10, bottom: 10),
              padding: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.button : AppColors.panel,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected
                      ? AppColors.gold.withOpacity(0.5)
                      : AppColors.line,
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: AppColors.gold.withOpacity(0.2),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ]
                    : null,
              ),
              alignment: Alignment.center,
              child: Text(
                MockData.categorias[index],
                style: TextStyle(
                  color: isSelected ? Colors.black : AppColors.textSecondary,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

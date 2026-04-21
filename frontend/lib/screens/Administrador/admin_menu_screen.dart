import 'package:flutter/material.dart';
import 'package:frontend/components/Cliente/producto_card.dart';
import 'package:frontend/core/colors_style.dart';
import 'package:frontend/models/producto_model.dart';
import 'package:frontend/providers/cart_provider.dart';
import 'package:frontend/screens/Administrador/admin_anadir_menu.dart';
import 'package:frontend/screens/Administrador/admin_editar_plato.dart';
import 'package:frontend/services/api_service.dart';
import 'package:provider/provider.dart';

class AdminMenuScreen extends StatefulWidget {
  const AdminMenuScreen({super.key});

  @override
  State<AdminMenuScreen> createState() => _AdminMenuScreenState();
}

class _AdminMenuScreenState extends State<AdminMenuScreen> {
  int selectedCategoryIndex = 0;
  List<String> _categorias = [];
  List<Producto> _productos = [];
  bool _cargando = true;


  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }


  
  Future<void> _cargarDatos() async {
    try {
      final categorias = await ApiService.obtenerCategorias();
      final productos = await ApiService.obtenerProductos();
      if (!mounted) return;
      setState(() {
        _categorias = categorias;
        _productos = productos;
        _cargando = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _cargando = false);
    }
  }




  @override
  Widget build(BuildContext context) {

    final currentCategory = _categorias.isNotEmpty
        ? _categorias[selectedCategoryIndex]
        : '';
    final filteredProducts = _productos
        .where((p) => p.categoria == currentCategory)
        .toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBarAdminMenu(),
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
                          onAdd: () => IrEditarPlato(context, product),
                          iconoEditar: true,
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
        itemCount: _categorias.length,
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
                _categorias[index],
                style: TextStyle(
                  color: isSelected ? Colors.white : AppColors.textSecondary,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
  

  AppBar AppBarAdminMenu(){
    return AppBar(
      backgroundColor: AppColors.background,
      centerTitle: true,
      elevation: 0,
      title: Text(
        "MENU",
        style: TextStyle(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ),
      ),
      actions: [
        Padding(
          padding: EdgeInsets.all(10),
          child: IconButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => AdminAnadirMenu()),
              );
            },
            icon: Icon(Icons.add, color: AppColors.gold, size: 28),
          ),
        ),
      ],
    );
  }

  Future<void> IrEditarPlato(contex, Producto producto) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => AdminEditarPlato(producto: producto)),
    );

    setState(() {});
  }
}



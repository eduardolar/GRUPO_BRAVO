import 'package:flutter/material.dart';
import 'package:frontend/core/colors_style.dart';
import 'package:frontend/data/mock_data.dart';
import 'package:frontend/models/ingrediente_model.dart';
import 'package:frontend/models/producto_model.dart';
import 'package:frontend/screens/Administrador/admin_editar_stock.dart';
import 'package:frontend/screens/Administrador/admin_nuevo_ingrediente.dart';
import 'package:frontend/services/api_service.dart';
import 'package:frontend/services/ingredientes_service.dart';

class AdminStockScreen extends StatefulWidget {
  const AdminStockScreen({super.key});

  @override
  State<AdminStockScreen> createState() => _AdminStockScreenState();
}

class _AdminStockScreenState extends State<AdminStockScreen> {
  List<String> _categorias = [];
  List<Ingrediente> _ingredientes = [];

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    try {
      final ingredientes = await ApiService.obtenerIngredientes();
      if (!mounted) return;
      setState(() {
        _ingredientes = ingredientes;
      });
    } catch (e) {
      if (!mounted) return;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBarStock(),
      body: BodyStockAdministrador(),
    );
  }

  Column BodyStockAdministrador() {
    return Column(
      children: [
        Text("INGREDIENTES"),
        Expanded(
          child: _ingredientes.isEmpty
              ? const Center(
                  child: Text(
                    "No hay ingredientes disponibles",
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  itemCount: _ingredientes.length,
                  itemBuilder: (context, index) {
                    final elemtoStock = _ingredientes[index];
                    return Padding(
                      padding: const EdgeInsets.all(15),
                      child: ElevatedButton(
                        onPressed: () {
                          EditarIngrediente();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              elemtoStock.cantidadActual >
                                  elemtoStock.stockMinimo
                              ? AppColors.disp
                              : AppColors
                                    .noDisp, // Hacer que cambie de color segun disponibilidad
                          foregroundColor: AppColors.textPrimary,
                        ),
                        child: Text("${elemtoStock.nombre}"),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  AppBar AppBarStock() {
    return AppBar(
      backgroundColor: AppColors.background,
      centerTitle: true,
      elevation: 0,
      title: Text(
        "STOCK",
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
                MaterialPageRoute(builder: (context) => NuevoIngrediente()),
              );
            },
            icon: Icon(Icons.add, color: AppColors.gold, size: 28),
          ),
        ),
      ],
    );
  }

  void EditarIngrediente() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => EditarIngredienteStock()),
    );

    setState(() {});
  }
}

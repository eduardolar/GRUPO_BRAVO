import 'package:flutter/material.dart';
import 'package:frontend/core/colors_style.dart';
import 'package:frontend/data/mock_data.dart';
import 'package:frontend/screens/Administrador/admin_editar_stock.dart';

class AdminStockScreen extends StatefulWidget {
  const AdminStockScreen({super.key});

  @override
  State<AdminStockScreen> createState() => _AdminStockScreenState();
}

class _AdminStockScreenState extends State<AdminStockScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBarStock(),
      body: BodyStockAdministrador(),
    );
  }

  Column BodyStockAdministrador() {
    final filteredStock = MockData.stock.toList();
    return Column(
      children: [
        Text("Productos"),
        Expanded(
          child: ListView.builder(
            itemCount: filteredStock.length,
            itemBuilder: (context, index) {
              final elemtoStock = filteredStock[index]; 
              return Padding(
                
                padding: const EdgeInsets.all(15),
                child: ElevatedButton(
                  onPressed: () {
                    EditarIngrediente();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: elemtoStock.estaDisponible ? AppColors.disp : AppColors.noDisp, // Hacer que cambie de color segun disponibilidad
                    foregroundColor: AppColors.textPrimary
                  ),
                  child: Text("${filteredStock[index].nombre}"),
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
        Padding(padding: EdgeInsets.all(10),
        child: IconButton(onPressed: (){}, icon: Icon(Icons.add, color: AppColors.gold, size: 28,)),
        )
      ],
    );
  }

  void EditarIngrediente() async{
    await Navigator.push(
      context, 
      MaterialPageRoute(builder: (context) => EditarStock()));

      setState(() {
        
      });
  }
}

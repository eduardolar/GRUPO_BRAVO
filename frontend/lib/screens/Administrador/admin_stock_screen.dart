import 'package:flutter/material.dart';
import '../../core/colors_style.dart';
import '../../models/ingrediente_model.dart';
import '../../services/ingredientes_service.dart';
import 'admin_editar_stock.dart';
import 'admin_nuevo_ingrediente.dart';

class AdminStockScreen extends StatefulWidget {
  const AdminStockScreen({super.key});

  @override
  State<AdminStockScreen> createState() => _AdminStockScreenState();
}

class _AdminStockScreenState extends State<AdminStockScreen> {
  String _busqueda = '';
  String _filtroCategoria = 'Todas';
  final List<String> _categorias = [
    'Todas',
    'Carnes',
    'Vegetales',
    'Lácteos',
    'Panadería',
    'Salsas',
    'Otras'
  ];

  void _recargarStock() {
    setState(() {}); 
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Control de Stock'),
        backgroundColor: AppColors.backgroundButton,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Buscar ingrediente...',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                    onChanged: (valor) => setState(() => _busqueda = valor.toLowerCase()),
                  ),
                ),
                const SizedBox(width: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _filtroCategoria,
                      items: _categorias.map((String cat) {
                        return DropdownMenuItem<String>(value: cat, child: Text(cat));
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => _filtroCategoria = val);
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: FutureBuilder<List<Ingrediente>>(
              // Usamos el nombre correcto de la clase y el método estático
              future: IngredienteService.obtenerIngredientes(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Text('Error al cargar:\n${snapshot.error}', style: const TextStyle(color: Colors.red)),
                  );
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(child: Text('No hay ingredientes registrados.'));
                }

                final List<Ingrediente> stockReal = snapshot.data!;
                final stockFiltrado = stockReal.where((item) {
                  final coincideBusqueda = item.nombre.toLowerCase().contains(_busqueda);
                  final coincideCategoria = _filtroCategoria == 'Todas' || item.categoria == _filtroCategoria;
                  return coincideBusqueda && coincideCategoria;
                }).toList();

                if (stockFiltrado.isEmpty) {
                   return const Center(child: Text('Ningún ingrediente coincide con los filtros.'));
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: stockFiltrado.length,
                  itemBuilder: (context, index) {
                    final item = stockFiltrado[index];
                    // Usamos las variables correctas
                    final estaBajo = item.cantidadActual <= item.stockMinimo;

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: estaBajo ? Colors.red.shade300 : Colors.transparent, width: estaBajo ? 2 : 0),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(16),
                        title: Row(
                          children: [
                            Text(item.nombre, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            if (estaBajo) ...[
                              const SizedBox(width: 8),
                              const Icon(Icons.warning, color: Colors.red, size: 20),
                            ],
                          ],
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 8),
                            Text('Categoría: ${item.categoria}'),
                            Text(
                              'Cantidad: ${item.cantidadActual} / Mínimo: ${item.stockMinimo} ${item.unidad}',
                              style: TextStyle(
                                color: estaBajo ? Colors.red : Colors.grey.shade700,
                                fontWeight: estaBajo ? FontWeight.bold : FontWeight.normal,
                              ),
                            ),
                          ],
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.edit, color: Colors.blue),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => AdminEditarStockScreen(ingrediente: item)),
                            ).then((_) => _recargarStock()); 
                          },
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AdminNuevoIngredienteScreen()),
          ).then((_) => _recargarStock()); 
        },
        backgroundColor: AppColors.button,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Nuevo Ingrediente', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }
}
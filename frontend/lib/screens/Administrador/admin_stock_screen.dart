import 'package:flutter/material.dart';
import 'package:frontend/components/Cliente/entrada_texto.dart';
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
  late Future<Map<String, List<Ingrediente>>> _future;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  void _cargar() {
    setState(() {
      _future = IngredienteService.obtenerIngredientesPorCategoria();
    });
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
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
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
          Expanded(
            child: FutureBuilder<Map<String, List<Ingrediente>>>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.red)),
                  );
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(child: Text('No hay ingredientes registrados.'));
                }

                final datos = snapshot.data!;

                if (_busqueda.isNotEmpty) {
                  final filtrados = datos.values
                      .expand((lista) => lista)
                      .where((i) => i.nombre.toLowerCase().contains(_busqueda))
                      .toList();
                  if (filtrados.isEmpty) {
                    return const Center(child: Text('Ningún ingrediente coincide.'));
                  }
                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    itemCount: filtrados.length,
                    itemBuilder: (_, i) => _tarjetaIngrediente(filtrados[i]),
                  );
                }

                final categorias = datos.keys.toList()..sort();
                final items = <Widget>[];
                for (final cat in categorias) {
                  final lista = datos[cat]!;
                  items.add(_cabeceraCategoria(cat, lista.length));
                  items.addAll(lista.map(_tarjetaIngrediente));
                }

                return ListView(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 80),
                  children: items,
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
            MaterialPageRoute(builder: (_) => const AdminNuevoIngredienteScreen()),
          ).then((_) => _cargar());
        },
        backgroundColor: AppColors.button,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Nuevo Ingrediente', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _cabeceraCategoria(String categoria, int total) {
    return Container(
      margin: const EdgeInsets.only(top: 16, bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.backgroundButton,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          const Icon(Icons.label_outline, color: Colors.white, size: 18),
          const SizedBox(width: 8),
          Text(
            categoria,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '$total',
              style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tarjetaIngrediente(Ingrediente item) {
    final estaBajo = item.cantidadActual <= item.stockMinimo;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: estaBajo ? Colors.red.shade300 : Colors.transparent,
          width: estaBajo ? 2 : 0,
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        title: Row(
          children: [
            Text(item.nombre, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            if (estaBajo) ...[
              const SizedBox(width: 8),
              const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 20),
            ],
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            'Stock: ${item.cantidadActual} ${item.unidad}  ·  Mín: ${item.stockMinimo} ${item.unidad}',
            style: TextStyle(
              color: estaBajo ? Colors.red : Colors.grey.shade700,
              fontWeight: estaBajo ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
        trailing: IconButton(
          icon: const Icon(Icons.edit_outlined, color: Colors.blue),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => AdminEditarStockScreen(ingrediente: item)),
            ).then((_) => _cargar());
          },
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import '../../core/colors_style.dart';
import '../../services/api_service.dart';
import '../../models/producto_model.dart';

class BloquearProducto extends StatefulWidget {
  const BloquearProducto({super.key});

  @override
  State<BloquearProducto> createState() => _BloquearProductoState();
}

class _BloquearProductoState extends State<BloquearProducto> {
  List<Producto> _productos = [];
  final Set<String> _seleccionados = {}; // Guardamos los IDs de los productos a bloquear
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
  try {
    print("Intentando conectar con la API..."); // Debug
    final productos = await ApiService.obtenerProductos();
    print("Productos recibidos: ${productos.length}"); // Debug
    
    if (mounted) {
      setState(() {
        _productos = productos;
        _cargando = false;
      });
    }
  } catch (e) {
    print("ERROR AL CARGAR: $e"); // Esto te dirá el error real en la consola
    if (mounted) {
      setState(() => _cargando = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error de conexión: $e")),
      );
    }
  }
}

  void _confirmarBloqueo() {
    // Aquí llamarías a tu API para bloquear los IDs en _seleccionados
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.panel,
        title: const Text("¿Bloquear productos?", style: TextStyle(color: Colors.white)),
        content: Text("Se anularán ${_seleccionados.length} productos del menú."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("CANCELAR")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              // Lógica API aquí
              Navigator.pop(context);
              setState(() {
                _productos.removeWhere((p) => _seleccionados.contains(p.id));
                _seleccionados.clear();
              });
            },
            child: const Text("BLOQUEAR"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text("BLOQUEAR PLATOS"), backgroundColor: AppColors.background),
      body: _cargando 
        ? const Center(child: CircularProgressIndicator()) 
        : Column(
            children: [
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _productos.length,
                  itemBuilder: (context, index) {
                    final p = _productos[index];
                    final esSeleccionado = _seleccionados.contains(p.id);
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          esSeleccionado ? _seleccionados.remove(p.id) : _seleccionados.add(p.id);
                        });
                      },
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        decoration: BoxDecoration(
                          color: AppColors.panel,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: esSeleccionado ? AppColors.gold : AppColors.line,
                            width: esSeleccionado ? 2 : 1,
                          ),
                        ),
                        child: ListTile(
                          title: Text(p.nombre, style: const TextStyle(color: Colors.white)),
                          trailing: Icon(
                            esSeleccionado ? Icons.check_circle : Icons.circle_outlined,
                            color: esSeleccionado ? AppColors.gold : AppColors.textSecondary,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              if (_seleccionados.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade900),
                      onPressed: _confirmarBloqueo,
                      child: Text("ANULAR ${_seleccionados.length} PRODUCTOS"),
                    ),
                  ),
                ),
            ],
          ),
    );
  }
}
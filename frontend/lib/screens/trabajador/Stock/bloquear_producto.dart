import 'package:flutter/material.dart';
import '../../../core/colors_style.dart';
import '../../../services/api_service.dart';
import '../../../models/ingrediente_model.dart';

class BloquearProducto extends StatefulWidget {
  const BloquearProducto({super.key});

  @override
  State<BloquearProducto> createState() => _BloquearProductoState();
}

class _BloquearProductoState extends State<BloquearProducto> {
  List<Ingrediente> _productos = [];
  final Set<String> _seleccionados = {}; // Guardamos los IDs de los ingredientes a bloquear
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
  try {
    print("Intentando conectar con la API..."); // Debug
    final productos = await ApiService.obtenerIngredientes();
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
        title: const Text("¿Bloquear ingredientes?", style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)),
        content: Text("Se anularán ${_seleccionados.length} ingredientes del menú."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("CANCELAR")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.backgroundButton),
            onPressed: () {
              // Lógica API aquí
              Navigator.pop(context);
              setState(() {
                _productos.removeWhere((p) => _seleccionados.contains(p.id));
                _seleccionados.clear();
              });
            },
            child: const Text("BLOQUEAR", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: _cargando
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
                                  color: AppColors.backgroundButton,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: esSeleccionado ? AppColors.background : AppColors.line,
                                    width: esSeleccionado ? 2 : 1,
                                  ),
                                ),
                                child: ListTile(
                                  title: Text(
                                    p.nombre,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  trailing: Icon(
                                    esSeleccionado ? Icons.check_circle : Icons.circle_outlined,
                                    color: esSeleccionado ? AppColors.background : AppColors.line,
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
                              style: ElevatedButton.styleFrom(backgroundColor: AppColors.backgroundButton),
                              onPressed: _confirmarBloqueo,
                              child: Text("ANULAR ${_seleccionados.length} INGREDIENTES", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                            ),
                          ),
          ],
                    
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      color: AppColors.backgroundButton,
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
      child: Column(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 1.5),
            ),
            child: const Icon(
              Icons.block_outlined,
              color: Colors.white,
              size: 24,
            ),
          ),

          const SizedBox(height: 12),

          const Text(
            "Bloquear Ingredientes",
            style: TextStyle(
              fontFamily: 'Playfair Display',
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),

          const SizedBox(height: 6),

          Text(
            "SELECCIONA LOS INGREDIENTES",
            style: TextStyle(
              color: Colors.white70,
              fontSize: 10,
              letterSpacing: 3,
              fontWeight: FontWeight.w400,
            ),
          ),

          const SizedBox(height: 16),

          Row(
            children: [
              const Expanded(child: Divider(color: Color(0xFFE0DBD3))),
              Container(
                width: 60,
                height: 1.5,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.transparent,
                      Colors.white,
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
              const Expanded(child: Divider(color: Color(0xFFE0DBD3))),
            ],
          ),
        ],
      ),
    );
  }
}
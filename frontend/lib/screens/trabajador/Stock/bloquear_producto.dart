import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/colors_style.dart';
import '../../../providers/auth_provider.dart';
import '../../../services/api_service.dart';
import '../../../models/ingrediente_model.dart';

class BloquearProducto extends StatefulWidget {
  const BloquearProducto({super.key});

  @override
  State<BloquearProducto> createState() => _BloquearProductoState();
}

class _BloquearProductoState extends State<BloquearProducto> {
  List<Ingrediente> _productos = [];
  final Set<String> _seleccionados =
      {}; // Guardamos los IDs de los ingredientes a bloquear
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    final restauranteId =
        context.read<AuthProvider>().usuarioActual?.restauranteId;
    try {
      final productos = await ApiService.obtenerIngredientes(
        restauranteId: restauranteId,
      );

      if (mounted) {
        setState(() {
          _productos = productos;
          _cargando = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _cargando = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error de conexión: $e")));
      }
    }
  }

  void _confirmarBloqueo() {
    // Aquí llamarías a tu API para bloquear los IDs en _seleccionados
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.panel,
        title: const Text(
          "¿Bloquear ingredientes?",
          style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
        ),
        content: Text(
          "Se anularán ${_seleccionados.length} ingredientes del menú.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("CANCELAR"),
          ),
          Tooltip(
            message: 'No disponible aún',
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.backgroundButton,
              ),
              onPressed: null,
              child: const Text(
                "BLOQUEAR",
                style: TextStyle(
                  color: Colors.white70,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBannerDesarrollo() {
    return Container(
      width: double.infinity,
      color: const Color(0xFFF59E0B),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('⚠', style: TextStyle(fontSize: 16)),
          SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Funcionalidad en desarrollo',
                  style: TextStyle(
                    color: Colors.black87,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Aún no se persiste al servidor. Usa el panel de admin si necesitas ejecutar esta acción.',
                  style: TextStyle(color: Colors.black87, fontSize: 12),
                ),
              ],
            ),
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
            _buildBannerDesarrollo(),
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
                              final esSeleccionado = _seleccionados.contains(
                                p.id,
                              );
                              return GestureDetector(
                                onTap: () {
                                  setState(() {
                                    esSeleccionado
                                        ? _seleccionados.remove(p.id)
                                        : _seleccionados.add(p.id);
                                  });
                                },
                                child: Container(
                                  margin: const EdgeInsets.only(bottom: 10),
                                  decoration: BoxDecoration(
                                    color: AppColors.backgroundButton,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: esSeleccionado
                                          ? AppColors.background
                                          : AppColors.line,
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
                                      esSeleccionado
                                          ? Icons.check_circle
                                          : Icons.circle_outlined,
                                      color: esSeleccionado
                                          ? AppColors.background
                                          : AppColors.line,
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
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.backgroundButton,
                                ),
                                onPressed: _confirmarBloqueo,
                                child: Text(
                                  "ANULAR ${_seleccionados.length} INGREDIENTES",
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
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
              const Expanded(child: Divider(color: AppColors.line)),
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
              const Expanded(child: Divider(color: AppColors.line)),
            ],
          ),
        ],
      ),
    );
  }
}

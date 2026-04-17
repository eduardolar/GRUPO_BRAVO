import 'package:flutter/material.dart';
import '../../models/restaurante_model.dart';
import '../../services/restaurante_service.dart';
import 'home_screen_super_admin.dart'; 
import '../../core/colors_style.dart';

class SeleccionarRestauranteScreen extends StatefulWidget {
  const SeleccionarRestauranteScreen({super.key});

  @override
  State<SeleccionarRestauranteScreen> createState() => _SeleccionarRestauranteScreenState();
}

class _SeleccionarRestauranteScreenState extends State<SeleccionarRestauranteScreen> {
  final RestauranteService _restauranteService = RestauranteService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Seleccionar Sucursal'),
        backgroundColor: AppColors.backgroundButton,
        centerTitle: true,
      ),
      body: FutureBuilder<List<Restaurante>>(
        future: _restauranteService.obtenerTodos(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No hay restaurantes registrados.'));
          }

          final restaurantes = snapshot.data!;

          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '¿Qué restaurante deseas gestionar hoy?',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 20),
                Expanded(
                  child: ListView.builder(
                    itemCount: restaurantes.length,
                    itemBuilder: (context, index) {
                      final res = restaurantes[index];
                      return Card(
                        elevation: 4,
                        margin: const EdgeInsets.only(bottom: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: ListTile(
                          contentPadding: const EdgeInsets.all(16),
                          leading: const Icon(Icons.restaurant, color: Colors.redAccent, size: 40),
                          title: Text(res.nombre, style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text(res.direccion),
                          trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                          onTap: () {
                            
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => HomeScreenSuperAdmin(
                                  restauranteId: res.id,
                                  restauranteNombre: res.nombre,
                                ),
                              ),
                            );
                          },
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
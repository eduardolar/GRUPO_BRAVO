import 'package:flutter/material.dart';
import '../../models/usuario_model.dart';
import '../../services/usuario_service.dart';
import '../../core/colors_style.dart';

class GestionUsuariosScreen extends StatefulWidget {
  final String rolAFiltrar;
  final String restauranteId;

  const GestionUsuariosScreen({
    super.key,
    required this.rolAFiltrar,
    required this.restauranteId
  });

  @override
  State<GestionUsuariosScreen> createState() => _GestionUsuariosScreenState();
}

class _GestionUsuariosScreenState extends State<GestionUsuariosScreen> {
  final UsuarioService _usuarioService = UsuarioService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          title: Text('Gestionar ${widget.rolAFiltrar}${widget.rolAFiltrar.endsWith('r') ? 'es' : 's'}'),
        backgroundColor: AppColors.backgroundButton,
      ),
      body: FutureBuilder<List<Usuario>>(
        future: _usuarioService.obtenerTodos(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return const Center(child: Text('Error al cargar datos'));
          }

          if (snapshot.hasData) {
            final listaFiltrada = snapshot.data!.where((u) {
              // 1. Limpiamos el ID del usuario y el ID del filtro (quitamos espacios)
                String idUsuarioEnDB = (u.restauranteId ?? '').toString().trim().toLowerCase();
              String idQueBuscamos = widget.restauranteId.trim().toLowerCase();

              // 2. Comprobamos si el restaurante coincide
              bool esMismoRestaurante = idUsuarioEnDB == idQueBuscamos;

              // 3. Comprobamos si el rol coincide
              final rolDelUsuario = u.rol.toString().split('.').last.toLowerCase();
              final filtroDePantalla = widget.rolAFiltrar.toLowerCase();

              bool esRolCorrecto;
              if (filtroDePantalla == 'trabajador') {
                esRolCorrecto = ['trabajador', 'cocinero', 'camarero', 'mesero'].contains(rolDelUsuario);
              } else {
                esRolCorrecto = rolDelUsuario == filtroDePantalla;
              }
              // Solo si coinciden AMBAS cosas, el usuario entra en la lista
              return esMismoRestaurante && esRolCorrecto;
            }).toList();

            if (listaFiltrada.isEmpty) {
              return Center(child: Text('No hay ${widget.rolAFiltrar}es en este restaurante'));
            }

            return ListView.builder(
              itemCount: listaFiltrada.length,
              itemBuilder: (context, index) {
                final user = listaFiltrada[index];
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
                  child: ListTile(
                    leading: const CircleAvatar(child: Icon(Icons.person)),
                    title: Text(user.nombre),
                    subtitle: Text(user.email),
                      trailing: IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () => _confirmarBorrado(context, user),
                    ),
                  ),
                );
              },
            );
          }
          return const Center(child: Text('No se encontraron datos'));
        },
      ),
    );
  }

  // Función para borrar usuarios
  void _confirmarBorrado(BuildContext context, Usuario user) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Eliminar usuario?'),
        content: Text('¿Estás segura de eliminar a ${user.nombre}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              bool borrado = await _usuarioService.eliminarUsuario(user.id);
              if (borrado) {
                if (!mounted) return;
                Navigator.pop(context);
                setState(() {}); // Esto refresca la pantalla
              }
            },
            child: const Text('Eliminar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
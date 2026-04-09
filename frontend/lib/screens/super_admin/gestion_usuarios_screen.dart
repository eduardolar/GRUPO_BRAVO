import 'package:flutter/material.dart';
import '../../models/usuario_model.dart';
import '../../services/usuario_service.dart';
import '../../core/colors_style.dart';

class GestionUsuariosScreen extends StatefulWidget {
  final String rolAFiltrar; // 'trabajador' o 'cliente'
  const GestionUsuariosScreen({super.key, required this.rolAFiltrar});

  @override
  State<GestionUsuariosScreen> createState() => _GestionUsuariosScreenState();
}

class _GestionUsuariosScreenState extends State<GestionUsuariosScreen> {
  final UsuarioService _usuarioService = UsuarioService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Gestionar ${widget.rolAFiltrar}es'),
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
            // Filtramos la lista antes de mostrarla
            final listaFiltrada = snapshot.data!.where((u) {
              // Sacamos el nombre limpio del Enum: 'trabajador', 'cliente', etc.
              final rolDelUsuario = u.rol
                  .toString()
                  .split('.')
                  .last
                  .toLowerCase();
              final filtroDePantalla = widget.rolAFiltrar.toLowerCase();

              return rolDelUsuario == filtroDePantalla;
            }).toList();
            if (listaFiltrada.isEmpty) {
              return Center(
                child: Text('No hay ${widget.rolAFiltrar}es registrados'),
              );
            }

            return ListView.builder(
              itemCount: listaFiltrada.length,
              itemBuilder: (context, index) {
                final user = listaFiltrada[index];
                return Card(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 15,
                    vertical: 8,
                  ),
                  child: ListTile(
                    leading: const CircleAvatar(child: Icon(Icons.person)),
                    title: Text(user.nombre),
                    subtitle: Text('${user.email} - Rol: ${user.rol}'),
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

  void _confirmarBorrado(BuildContext context, Usuario user) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Eliminar usuario?'),
        content: Text('¿Estás segura de eliminar a ${user.nombre}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              bool borrado = await _usuarioService.eliminarUsuario(user.id);
              if (borrado) {
                if (!mounted) return; // Verificación de seguridad en Flutter
                Navigator.pop(context); // Cierra el diálogo
                setState(() {}); // Refresca la lista
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Usuario eliminado con éxito')),
                );
              }
            },
            child: const Text(
              'Eliminar',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}

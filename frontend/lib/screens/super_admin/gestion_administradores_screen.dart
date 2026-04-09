import 'package:flutter/material.dart';
import '../../models/usuario_model.dart';
import '../../services/usuario_service.dart';
import '../../core/colors_style.dart';

class GestionAdministradorScreen extends StatefulWidget {
  final String rolAFiltrar; // 'trabajador', 'cliente' o 'administrador'
  const GestionAdministradorScreen({super.key, required this.rolAFiltrar});

  @override
  State<GestionAdministradorScreen> createState() =>
      _GestionAdministradorScreen();
}

class _GestionAdministradorScreen extends State<GestionAdministradorScreen> {
  final UsuarioService _usuarioService = UsuarioService();

  String _pluralizar(String rol) {
    if (rol.toLowerCase() == 'administrador') return 'administradores';
    return '${rol}es';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Gestionar ${_pluralizar(widget.rolAFiltrar)}'),
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
                child: Text(
                  'No hay ${_pluralizar(widget.rolAFiltrar)} registrados',
                ),
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
        content: Text('¿Confirmas la eliminación de ${user.nombre}?'),
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
                if (!mounted) return;
                Navigator.pop(context);
                setState(() {});
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

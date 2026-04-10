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
    if (rol.toLowerCase() == 'administrador' || rol.toLowerCase() == 'admin') {
      return 'administradores';
    }
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
            return Center(child: Text('Error al cargar datos: ${snapshot.error}'));
          }

          if (snapshot.hasData) {
            final listaFiltrada = snapshot.data!.where((u) {
              // Esto nos dará 'administrador', 'trabajador', 'cliente', etc. (basado en tu Enum)
              final rolDelUsuario = u.rol.toString().split('.').last.toLowerCase();
              
              // Leemos lo que nos pide la pantalla
              String filtroDePantalla = widget.rolAFiltrar.toLowerCase();
              
              // Si la pantalla nos pide 'admin', buscamos 'administrador'
              // para que coincida exactamente con el nombre de tu Enum
              if (filtroDePantalla == 'admin') {
                filtroDePantalla = 'administrador';
              } else if (filtroDePantalla == 'superadmin') {
                filtroDePantalla = 'superadministrador';
              }

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
                    // Como tu modelo usa "email" (no "correo"), esto ya no fallará
                    subtitle: Text('${user.email} - Rol: ${user.rol.name}'), 
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
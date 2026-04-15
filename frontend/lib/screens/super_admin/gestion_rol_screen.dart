import 'package:flutter/material.dart';
import '../../models/usuario_model.dart';
import '../../services/usuario_service.dart';
import '../../core/colors_style.dart';

class GestionRolesScreen extends StatefulWidget {
  final String rolAFiltrar;
  const GestionRolesScreen({super.key, required this.rolAFiltrar});

  @override
  State<GestionRolesScreen> createState() => _GestionRolesScreenState();
}

class _GestionRolesScreenState extends State<GestionRolesScreen> {
  final UsuarioService _usuarioService = UsuarioService();

  String _pluralizar(String rol) {
    final r = rol.toLowerCase();
    if (r == 'admin' || r == 'administrador') return 'administradores';
    if (r == 'superadmin' || r == 'superadministrador') return 'superadministradores';
    if (r == 'trabajador') return 'trabajadores';
    if (r == 'cliente') return 'clientes';
    if (r == 'todos') return 'todos los usuarios';
    return '${rol}s';
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
              final rolEnum = u.rol.name.toLowerCase(); 
              final filtro = widget.rolAFiltrar.toLowerCase().trim();
              
              if (filtro == 'todos' || filtro.isEmpty) return true;
              if (filtro.contains('super')) return rolEnum == 'superadministrador';
              if (filtro.contains('admin')) return rolEnum == 'administrador';
              if (filtro.contains('trabajador') || filtro.contains('cocinero')) return rolEnum == 'trabajador';
              if (filtro.contains('cliente')) return rolEnum == 'cliente';

              return rolEnum == filtro;
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
                
                // LÓGICA DE SEGURIDAD PARA BOTONES
                // Comprobamos qué rol tiene el usuario para decidir qué botones mostrar
                final bool esCliente = user.rol.name.toLowerCase() == 'cliente';
                final bool esSuperAdmin = user.rol.name.toLowerCase().contains('super');
                // ---------------------------------

                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
                  child: ListTile(
                    leading: const CircleAvatar(child: Icon(Icons.person)),
                    title: Text(user.nombre),
                    subtitle: Text('${user.email} - Rol: ${user.rol.name}'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // El if solo dibuja el lapiz si NO es cliente y NO es superadmin
                        if (!esCliente && !esSuperAdmin)
                          IconButton(
                            icon: const Icon(Icons.edit, color: Colors.blue),
                            onPressed: () => _mostrarDialogoCambiarRol(context, user),
                          ),
                        
                        // Botón de BORRAR USUARIO
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () => _confirmarBorrado(context, user),
                        ),
                      ],
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

  void _mostrarDialogoCambiarRol(BuildContext context, Usuario user) {
    String rolSeleccionado = 'trabajador'; 
    if (user.rol.name == 'administrador') rolSeleccionado = 'admin';

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text('Cambiar Rol'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Selecciona el nuevo rol para ${user.nombre}:'),
                  const SizedBox(height: 15),
                  DropdownButton<String>(
                    value: rolSeleccionado,
                    isExpanded: true,
                    // Nuevas opciones de la lista
                    items: const [
                      DropdownMenuItem(value: 'cocinero', child: Text('Cocinero')),
                      DropdownMenuItem(value: 'camarero', child: Text('Camarero')),
                      DropdownMenuItem(value: 'mesero', child: Text('Mesero')),
                      DropdownMenuItem(value: 'trabajador', child: Text('Trabajador')),
                      DropdownMenuItem(value: 'admin', child: Text('Administrador')),
                    ],
                    onChanged: (String? newValue) {
                      if (newValue != null) {
                        setStateDialog(() {
                          rolSeleccionado = newValue;
                        });
                      }
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                  onPressed: () async {
                    try {
                      bool actualizado = await _usuarioService.cambiarRol(user.id, rolSeleccionado);
                      if (actualizado) {
                        if (!mounted) return;
                        Navigator.pop(context);
                        setState(() {});
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Rol actualizado con éxito')),
                        );
                      }
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                      );
                    }
                  },
                  child: const Text('Guardar', style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          }
        );
      },
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
            child: const Text('Eliminar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
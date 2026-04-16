import 'package:flutter/material.dart';
import '../../models/usuario_model.dart';
import '../../services/usuario_service.dart';
import '../../core/colors_style.dart';

class GestionRolesScreen extends StatefulWidget {
  final String restauranteId; // <-- Ahora sí pedimos el ID del restaurante

  const GestionRolesScreen({super.key, required this.restauranteId});

  @override
  State<GestionRolesScreen> createState() => _GestionRolesScreenState();
}

class _GestionRolesScreenState extends State<GestionRolesScreen> {
  final UsuarioService _usuarioService = UsuarioService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cambiar Roles en la Sucursal'),
        backgroundColor: AppColors.backgroundButton,
      ),
      body: FutureBuilder<List<Usuario>>(
        future: _usuarioService.obtenerTodos(),
       builder: (context, snapshot) {
  if (snapshot.connectionState == ConnectionState.waiting) {
    return const Center(child: CircularProgressIndicator());
  }

  if (snapshot.hasData) {
    final listaFiltrada = snapshot.data!.where((u) {
      // Usamos .toLowerCase() y .trim() en ambos lados para que coincidan sí o sí
      String idUsuario = (u.restauranteId ?? '').toString().trim().toLowerCase();
      String idFiltro = widget.restauranteId.trim().toLowerCase();
      
      return idUsuario == idFiltro;
    }).toList();

    if (listaFiltrada.isEmpty) {
      return const Center(child: Text('No hay usuarios en esta sucursal'));
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
            subtitle: Text('Rol actual: ${user.rol.name}'),
            trailing: IconButton(
              icon: const Icon(Icons.edit, color: Colors.blue),
              onPressed: () => _mostrarDialogoCambiarRol(context, user),
            ),
          ),
        );
      },
    );
  }
  return const Center(child: Text('Error al cargar datos'));
},
      ),
    );
  }

  void _mostrarDialogoCambiarRol(BuildContext context, Usuario user) {
    String rolSeleccionado = 'camarero'; // Valor por defecto
   void _mostrarDialogoCambiarRol(BuildContext context, Usuario user) {

    String rolSeleccionado = 'cliente'; // Resguardo de seguridad

    if (user.rol.name == 'administrador') rolSeleccionado = 'admin';

    showDialog(

    else if (user.rol.name == 'trabajador') rolSeleccionado = 'trabajador';
  
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

                    // Quitamos la opción de 'super_admin' para que nadie lo cree desde la app

                    items: const [
                      DropdownMenuItem(value: 'cocinero', child: Text('Cocinero')),
                      DropdownMenuItem(value: 'camarero', child: Text('Camarero')),
                      DropdownMenuItem(value: 'mesero', child: Text('Mesero')),

                      DropdownMenuItem(value: 'cliente', child: Text('Cliente')),

                      DropdownMenuItem(value: 'trabajador', child: Text('Trabajador')),

                      DropdownMenuItem(value: 'admin', child: Text('Administrador')),
                    ], //Trabajador ya no es un rol, ahora se divide en camarero, cocinero y mesero.

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
  

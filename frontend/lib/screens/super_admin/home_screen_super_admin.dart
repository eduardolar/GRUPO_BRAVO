import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:frontend/core/colors_style.dart';
import 'package:frontend/providers/auth_provider.dart';
import 'gestion_usuarios_screen.dart';
import 'gestion_rol_screen.dart'; 
import 'crear_usuario_screen.dart'; 

class HomeScreenSuperAdmin extends StatelessWidget {
  final String restauranteId;
  final String restauranteNombre; 

  const HomeScreenSuperAdmin({
    super.key, 
    required this.restauranteId, 
    required this.restauranteNombre
  });

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundButton,
        title: Text('Gestión: $restauranteNombre'),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // 1. TRABAJADORES
          _buildOpcion(
            context: context,
            titulo: 'Gestionar Trabajadores',
            icono: Icons.people,
            onTap: () => Navigator.push(context, MaterialPageRoute(
              builder: (context) => GestionUsuariosScreen(rolAFiltrar: 'trabajador', restauranteId: restauranteId)
            )),
          ),
          const SizedBox(height: 10),

          // 2. ADMINISTRADORES
          _buildOpcion(
            context: context,
            titulo: 'Gestionar Administradores',
            icono: Icons.admin_panel_settings,
            onTap: () => Navigator.push(context, MaterialPageRoute(
              builder: (context) => GestionUsuariosScreen(rolAFiltrar: 'administrador', restauranteId: restauranteId)
            )),
          ),
          const SizedBox(height: 10),

          // 3. ROLES (Ahora le pasamos el restauranteId para que no mezcle gente)
          _buildOpcion(
            context: context,
            titulo: 'Gestión de Roles',
            icono: Icons.vpn_key,
            onTap: () => Navigator.push(context, MaterialPageRoute(
              builder: (context) => GestionRolesScreen(restauranteId: restauranteId)
            )),
          ),
          const SizedBox(height: 10),

          // 4. CLIENTES (Ahora sí, dentro de la lista)
          _buildOpcion(
            context: context,
            titulo: 'Gestionar Clientes',
            icono: Icons.person_outline,
            onTap: () => Navigator.push(context, MaterialPageRoute(
              builder: (context) => GestionUsuariosScreen(rolAFiltrar: 'cliente', restauranteId: restauranteId)
            )),
          ),
        ],
      ),
       
  // Boton flotante para crear un nuevo usuario (administrador o trabajador)
  floatingActionButton: FloatingActionButton.extended(
    onPressed: () {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => CrearUsuarioScreen(restauranteId: restauranteId),
        ),
      );
    },
    label: const Text('Nuevo Usuario', style: TextStyle(color: Colors.white)),
    icon: const Icon(Icons.add, color: Colors.white),
    backgroundColor: AppColors.backgroundButton,
  ),

     );
  }

  Widget _buildOpcion({
    required BuildContext context,
    required String titulo,
    required IconData icono,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: ListTile(
        leading: Icon(icono, color: AppColors.backgroundButton),
        title: Text(titulo, style: const TextStyle(fontWeight: FontWeight.bold)),
        trailing: const Icon(Icons.arrow_forward_ios),
        onTap: onTap,
      ),
    );
  }
}
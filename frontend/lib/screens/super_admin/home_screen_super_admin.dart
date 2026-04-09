import 'package:flutter/material.dart';
import 'package:frontend/screens/super_admin/gestion_administradores_screen.dart';
import 'package:frontend/screens/super_admin/gestion_administradores_screen.dart';
import 'package:frontend/screens/super_admin/gestion_rol_screen.dart';
import 'package:provider/provider.dart';
import 'package:frontend/core/colors_style.dart';
import 'package:frontend/providers/auth_provider.dart';
import 'package:frontend/screens/Cliente/home_screen.dart';
import 'package:frontend/screens/Cliente/perfil_screen.dart';
import 'package:frontend/screens/super_admin/gestion_usuarios_screen.dart';

class HomeScreenSuperAdmin extends StatelessWidget {
  const HomeScreenSuperAdmin({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final usuario = auth.usuarioActual;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundButton,
        elevation: 0,
        automaticallyImplyLeading: false,
        centerTitle: true,
        title: const Text(
          'Panel de Super Administrador',
          style: TextStyle(
            fontFamily: 'Playfair Display',
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: () {
              auth.cerrarSesion();
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const HomeScreen()),
                (route) => false,
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: AppColors.panel,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.line),
                boxShadow: const [
                  BoxShadow(
                    color: AppColors.shadow,
                    blurRadius: 10,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Container(
                    width: 84,
                    height: 84,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.background,
                      border: Border.all(
                        color: AppColors.backgroundButton,
                        width: 2,
                      ),
                    ),
                    child: const Icon(
                      Icons.admin_panel_settings,
                      size: 40,
                      color: AppColors.backgroundButton,
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'Bienvenido, Super Administrador',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    usuario?.nombre ?? 'Usuario sin nombre',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppColors.backgroundButton,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    usuario?.email ?? '',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 26),

            _buildSeccionTitulo('Gestión'),
            const SizedBox(height: 10),
            const SizedBox(height: 10),

            // BOTÓN TRABAJADORES
            _buildOpcion(
              icon: Icons.manage_accounts,
              titulo: 'Gestionar trabajadores',
              subtitulo: 'Administrar cocineros y camareros',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        const GestionUsuariosScreen(rolAFiltrar: 'trabajador'),
                  ),
                );
              },
            ),
            // BOTÓN TRABAJADORES
            _buildOpcion(
              icon: Icons.manage_accounts,
              titulo: 'Gestionar trabajadores',
              subtitulo: 'Administrar cocineros y camareros',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        const GestionUsuariosScreen(rolAFiltrar: 'trabajador'),
                  ),
                );
              },
            ),

            const SizedBox(height: 10),
            const SizedBox(height: 10),

            // NUEVO BOTÓN CLIENTES
            _buildOpcion(
              icon: Icons.people_alt,
              titulo: 'Gestionar clientes',
              subtitulo: 'Ver base de datos de clientes',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        const GestionUsuariosScreen(rolAFiltrar: 'cliente'),
                  ),
                );
              },
            ),
            // NUEVO BOTÓN CLIENTES
            _buildOpcion(
              icon: Icons.people_alt,
              titulo: 'Gestionar clientes',
              subtitulo: 'Ver base de datos de clientes',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        const GestionUsuariosScreen(rolAFiltrar: 'cliente'),
                  ),
                );
              },
            ),

            const SizedBox(height: 10),

            _buildOpcion(
              icon: Icons.admin_panel_settings,
              titulo: 'Gestionar administradores',
              subtitulo: 'Controlar privilegios y accesos',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        const GestionAdministradorScreen(rolAFiltrar: 'admin'),
                  ),
                );
              },
            ),

            const SizedBox(height: 10),

            _buildOpcion(
              icon: Icons.supervisor_account,
              titulo: 'Gestionar roles',
              subtitulo: 'Quitar o actualizar roles',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        const GestionRolesScreen(rolAFiltrar: ''),
                  ),
                );
              },
            ),

            const SizedBox(height: 22),
            const Divider(color: AppColors.line),
            const SizedBox(height: 10),

            _buildSeccionTitulo('Cuenta'),
            const SizedBox(height: 10),

            _buildOpcion(
              icon: Icons.person_outline,
              titulo: 'Mi perfil',
              subtitulo: 'Ver y editar datos',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const PerfilScreen()),
                );
              },
            ),

            const SizedBox(height: 10),

            _buildOpcion(
              icon: Icons.logout,
              titulo: 'Cerrar sesión',
              subtitulo: 'Salir de la cuenta actual',
              color: AppColors.error,
              onTap: () {
                auth.cerrarSesion();
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const HomeScreen()),
                  (route) => false,
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSeccionTitulo(String titulo) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        titulo,
        style: const TextStyle(
          color: AppColors.textPrimary,
          fontSize: 17,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildOpcion({
    required IconData icon,
    required String titulo,
    required String subtitulo,
    required VoidCallback onTap,
    Color color = AppColors.backgroundButton,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.panel,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.line),
        boxShadow: const [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        dense: true,
        visualDensity: const VisualDensity(horizontal: -2, vertical: -2),
        minLeadingWidth: 8,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        leading: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: AppColors.background,
            shape: BoxShape.circle,
            border: Border.all(color: color.withOpacity(0.25)),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
        title: Text(
          titulo,
          style: TextStyle(
            color: color == AppColors.error
                ? AppColors.error
                : AppColors.textPrimary,
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Text(
            subtitulo,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 11.5,
            ),
          ),
        ),
        trailing: Icon(
          Icons.chevron_right,
          size: 18,
          color: color == AppColors.error
              ? AppColors.error
              : AppColors.iconPrimary,
        ),
        onTap: onTap,
      ),
    );
  }
}

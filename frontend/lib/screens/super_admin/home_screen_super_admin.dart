import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:frontend/core/colors_style.dart';
import 'package:frontend/providers/auth_provider.dart';
import 'package:frontend/screens/cliente/home_screen.dart';
import 'gestion_usuarios_screen.dart';
import 'gestion_rol_screen.dart';
import 'crear_usuario_screen.dart';
import 'seleccionar_restaurante_screen.dart';

class HomeScreenSuperAdmin extends StatelessWidget {
  final String restauranteId;
  final String restauranteNombre;

  const HomeScreenSuperAdmin({
    super.key,
    required this.restauranteId,
    required this.restauranteNombre,
  });

  void _navigateTo(BuildContext context, Widget screen) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }

  void _cambiarSucursal(BuildContext context) {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const SeleccionarRestauranteScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: AppColors.background,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _navigateTo(context, CrearUsuarioScreen(restauranteId: restauranteId)),
        backgroundColor: AppColors.button,
        elevation: 4,
        shape: const RoundedRectangleBorder(),
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: Text(
          'NUEVO USUARIO',
          style: GoogleFonts.manrope(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.5,
          ),
        ),
      ),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverAppBar(
            expandedHeight: screenHeight * 0.42,
            pinned: true,
            backgroundColor: AppColors.button,
            automaticallyImplyLeading: false,
            actions: [
              IconButton(
                icon: const Icon(Icons.store_outlined, color: Colors.white, size: 22),
                tooltip: 'Cambiar sucursal',
                onPressed: () => _cambiarSucursal(context),
              ),
              IconButton(
                icon: const Icon(Icons.logout, color: Colors.white, size: 22),
                tooltip: 'Cerrar sesión',
                onPressed: () async {
                  await context.read<AuthProvider>().cerrarSesion();
                  if (!context.mounted) return;
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (_) => const HomeScreen()),
                    (route) => false,
                  );
                },
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              collapseMode: CollapseMode.parallax,
              background: _HomeHero(nombre: restauranteNombre),
              centerTitle: true,
              title: Text(
                restauranteNombre,
                style: const TextStyle(
                  fontFamily: 'Playfair Display',
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Colors.white,
                ),
              ),
            ),
          ),

          // ── Tarjeta sucursal activa ──
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 0),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 640),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: AppColors.line),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.shadow.withValues(alpha: 0.10),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          color: AppColors.button.withValues(alpha: 0.08),
                          child: const Icon(Icons.storefront_outlined,
                              color: AppColors.button, size: 20),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'SUCURSAL ACTIVA',
                                style: GoogleFonts.manrope(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.textSecondary,
                                  letterSpacing: 2,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                restauranteNombre,
                                style: GoogleFonts.manrope(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        TextButton.icon(
                          onPressed: () => _cambiarSucursal(context),
                          icon: const Icon(Icons.swap_horiz_rounded,
                              size: 16, color: AppColors.button),
                          label: Text(
                            'CAMBIAR',
                            style: GoogleFonts.manrope(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppColors.button,
                              letterSpacing: 1,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
              child: Row(
                children: [
                  Container(width: 3, height: 18, color: AppColors.button),
                  const SizedBox(width: 10),
                  Text(
                    'GESTIÓN DEL PERSONAL',
                    style: GoogleFonts.manrope(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textSecondary,
                      letterSpacing: 2,
                    ),
                  ),
                ],
              ),
            ),
          ),

          SliverPadding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 120),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                Center(child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 640),
                  child: Column(
                    children: [
                      _DashboardTile(
                        icon: Icons.people_outline_rounded,
                        titulo: 'Trabajadores',
                        subtitulo: 'Cocineros, camareros y meseros',
                        onTap: () => _navigateTo(context, GestionUsuariosScreen(
                          rolAFiltrar: 'trabajador',
                          restauranteId: restauranteId,
                        )),
                      ),
                      const SizedBox(height: 12),
                      _DashboardTile(
                        icon: Icons.admin_panel_settings_outlined,
                        titulo: 'Administradores',
                        subtitulo: 'Gestores de sucursal',
                        onTap: () => _navigateTo(context, GestionUsuariosScreen(
                          rolAFiltrar: 'administrador',
                          restauranteId: restauranteId,
                        )),
                      ),
                      const SizedBox(height: 12),
                      _DashboardTile(
                        icon: Icons.security_outlined,
                        titulo: 'Permisos y Roles',
                        subtitulo: 'Configuración de accesos del personal',
                        onTap: () => _navigateTo(context, GestionRolesScreen(restauranteId: restauranteId)),
                      ),
                      const SizedBox(height: 12),
                      _DashboardTile(
                        icon: Icons.assignment_ind_outlined,
                        titulo: 'Clientes',
                        subtitulo: 'Base de datos y cuentas de clientes',
                        onTap: () => _navigateTo(context, GestionUsuariosScreen(
                          rolAFiltrar: 'cliente',
                          restauranteId: restauranteId,
                        )),
                      ),
                    ],
                  ),
                )),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

class _HomeHero extends StatelessWidget {
  final String nombre;
  const _HomeHero({required this.nombre});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: Image.asset(
            'assets/images/Bravo restaurante.jpg',
            fit: BoxFit.cover,
          ),
        ),
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: const [0.0, 0.35, 0.70, 1.0],
                colors: [
                  Colors.black.withValues(alpha: 0.50),
                  Colors.black.withValues(alpha: 0.10),
                  Colors.black.withValues(alpha: 0.55),
                  AppColors.background,
                ],
              ),
            ),
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.white60, width: 1.2),
                  ),
                  child: Text(
                    'PANEL DE GESTIÓN',
                    style: GoogleFonts.manrope(
                      color: AppColors.button,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 4,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  nombre.toUpperCase(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: 'Playfair Display',
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                    shadows: [Shadow(color: Colors.black54, blurRadius: 16)],
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Grupo Bravo',
                  style: GoogleFonts.manrope(
                    color: Colors.white70,
                    fontSize: 13,
                    letterSpacing: 1.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 28),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(width: 32, height: 1, color: Colors.white30),
                    const SizedBox(width: 12),
                    const Icon(Icons.admin_panel_settings_outlined, color: Colors.white54, size: 18),
                    const SizedBox(width: 12),
                    Container(width: 32, height: 1, color: Colors.white30),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _DashboardTile extends StatelessWidget {
  final IconData icon;
  final String titulo;
  final String subtitulo;
  final VoidCallback onTap;

  const _DashboardTile({
    required this.icon,
    required this.titulo,
    required this.subtitulo,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: AppColors.line),
          boxShadow: [
            BoxShadow(
              color: AppColors.shadow.withValues(alpha: 0.18),
              blurRadius: 14,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              color: AppColors.button.withValues(alpha: 0.08),
              child: Icon(icon, color: AppColors.button, size: 22),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    titulo,
                    style: GoogleFonts.manrope(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitulo,
                    style: GoogleFonts.manrope(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.textSecondary, size: 20),
          ],
        ),
      ),
    );
  }
}

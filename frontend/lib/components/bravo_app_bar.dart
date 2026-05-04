import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:frontend/core/app_routes.dart';
import 'package:frontend/providers/auth_provider.dart';
import 'package:frontend/screens/cliente/home_screen.dart';
import 'package:frontend/screens/cliente/login_screen.dart';
import 'package:frontend/screens/cliente/perfil_screen.dart';

/// AppBar compartida entre Home, Admin, Trabajador y cualquier pantalla nueva.
///
/// [title]  — texto que aparece centrado.
/// [isRoot] — true sólo en HomeScreen: el logout no redirige (ya estás en home).
class BravoAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final bool isRoot;

  const BravoAppBar({
    super.key,
    required this.title,
    this.isRoot = false,
  });

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      centerTitle: true,
      iconTheme: const IconThemeData(color: Colors.white),
      title: Text(title),
      actions: [
        Padding(
          padding: EdgeInsets.only(right: auth.estaAutenticado ? 0 : 16.0),
          child: IconButton(
            icon: CircleAvatar(
              backgroundColor: Colors.white24,
              radius: 18,
              child: Icon(
                auth.estaAutenticado ? Icons.person : Icons.person_outline,
                color: Colors.white,
                size: 20,
              ),
            ),
            onPressed: () {
              if (auth.estaAutenticado) {
                Navigator.push(context, AppRoute.slideUp(const PerfilScreen()));
              } else {
                Navigator.push(
                  context,
                  AppRoute.slideUp(const LoginScreen(mostrarActivarCuenta: true)),
                );
              }
            },
          ),
        ),
        if (auth.estaAutenticado)
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: IconButton(
              icon: const Icon(Icons.logout, color: Colors.white, size: 22),
              tooltip: 'Cerrar sesión',
              onPressed: () async {
                await context.read<AuthProvider>().cerrarSesion();
                if (!context.mounted) return;
                if (!isRoot) {
                  Navigator.of(context).pushAndRemoveUntil(
                    AppRoute.reveal(const HomeScreen()),
                    (route) => false,
                  );
                }
              },
            ),
          ),
      ],
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}

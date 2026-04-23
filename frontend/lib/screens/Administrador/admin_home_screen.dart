import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:frontend/core/colors_style.dart';
import 'package:frontend/screens/Administrador/admin_contabilidad_screen.dart';
import 'package:frontend/screens/Administrador/admin_menu_screen.dart';
import 'package:frontend/screens/Administrador/admin_mesas_screen.dart';
import 'package:frontend/screens/Administrador/admin_stock_screen.dart';
import 'package:frontend/screens/Administrador/admin_usuarios_screen.dart';

class MenuAdministrador extends StatefulWidget {
  const MenuAdministrador({super.key});

  @override
  State<MenuAdministrador> createState() => _MenuAdministradorState();
}

class _MenuAdministradorState extends State<MenuAdministrador> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black, // Color base
      extendBodyBehindAppBar: true, // Para que la imagen pase por debajo del AppBar
      appBar: AppBar(
        centerTitle: true,
        title: const Text(
          "PANEL DE CONTROL",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            letterSpacing: 2.0,
            fontSize: 20,
            color: Colors.white,
          ),
        ),
        backgroundColor: Colors.transparent, // AppBar transparente
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      // --- FONDO FIJO A PANTALLA COMPLETA ---
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/images/Bravo restaurante.jpg'),
            fit: BoxFit.cover, // Cubre toda la pantalla sin importar el tamaño
          ),
        ),
        // --- FILTRO OSCURO (Gradiente) ---
        child: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withOpacity(0.5), // Más claro arriba
                Colors.black.withOpacity(0.85), // Oscuro abajo, pero deja ver la foto
              ],
            ),
          ),
          // --- CONTENIDO CON SCROLL ---
          child: SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // --- CABECERA DE BIENVENIDA ---
                    const Text(
                      "¡Hola, Administrador!",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "¿Qué te gustaría gestionar hoy?",
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 32),

                    // --- CUADRÍCULA DE OPCIONES (2x2) ---
                    Row(
                      children: [
                        Expanded(
                          child: _buildAdminCard(
                            context: context,
                            title: "La Carta",
                            subtitle: "Editar platos",
                            icon: Icons.restaurant_menu,
                            destination: const AdminMenuScreen(),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildAdminCard(
                            context: context,
                            title: "Mesas",
                            subtitle: "Plano interactivo",
                            icon: Icons.table_restaurant_outlined,
                            destination: const AdminMesasScreen(),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _buildAdminCard(
                            context: context,
                            title: "Inventario",
                            subtitle: "Control de stock",
                            icon: Icons.inventory_2_outlined,
                            destination: const AdminStockScreen(),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildAdminCard(
                            context: context,
                            title: "Usuarios",
                            subtitle: "Cuentas y roles",
                            icon: Icons.people_outline,
                            destination: const AdminUsuariosScreen(),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // --- TARJETA DESTACADA (Ancho completo) ---
                    _buildAdminCard(
                      context: context,
                      title: "Contabilidad",
                      subtitle: "Informes y finanzas",
                      icon: Icons.account_balance_wallet_outlined,
                      destination: const AdminContabilidadScreen(),
                      isFullWidth: true,
                    ),
                    const SizedBox(height: 30),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // --- WIDGET PERSONALIZADO EFECTO CRISTAL ---
  Widget _buildAdminCard({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required Widget destination,
    bool isFullWidth = false,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          height: isFullWidth ? 120 : 160,
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.45),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Colors.white.withOpacity(0.15),
              width: 1.5,
            ),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              highlightColor: AppColors.button.withOpacity(0.1),
              splashColor: AppColors.button.withOpacity(0.2),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => destination),
                );
              },
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: isFullWidth
                    ? Row(
                        children: [
                          _buildIconContainer(icon),
                          const SizedBox(width: 20),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  title,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  subtitle,
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.6),
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            Icons.arrow_forward_ios,
                            color: Colors.white.withOpacity(0.3),
                            size: 20,
                          )
                        ],
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildIconContainer(icon),
                          const Spacer(),
                          Text(
                            title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.6),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildIconContainer(IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.button.withOpacity(0.2),
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.button.withOpacity(0.5), width: 1),
      ),
      child: Icon(icon, color: AppColors.button, size: 30),
    );
  }
}
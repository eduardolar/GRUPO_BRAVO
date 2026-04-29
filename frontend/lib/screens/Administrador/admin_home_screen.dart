import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:frontend/components/bravo_app_bar.dart';
import 'package:frontend/core/colors_style.dart';
import 'package:frontend/providers/auth_provider.dart';
import 'package:frontend/screens/Administrador/admin_contabilidad_screen.dart';
import 'package:frontend/screens/Administrador/admin_menu_screen.dart';
import 'package:frontend/screens/Administrador/admin_mesas_screen.dart';
import 'package:frontend/screens/Administrador/admin_stock_screen.dart';
import 'package:frontend/screens/Administrador/admin_usuarios_screen.dart';
import 'package:frontend/services/api_service.dart';
import 'package:provider/provider.dart';

class MenuAdministrador extends StatefulWidget {
  const MenuAdministrador({super.key});

  @override
  State<MenuAdministrador> createState() => _MenuAdministradorState();
}

class _MenuAdministradorState extends State<MenuAdministrador> {
  int _stockBajoCount = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _cargarStockBajo());
  }

  Future<void> _cargarStockBajo() async {
    if (!mounted) return;
    try {
      final restauranteId =
          context.read<AuthProvider>().usuarioActual?.restauranteId;
      final lista = await ApiService.obtenerIngredientesStockBajo(
        restauranteId: restauranteId,
      );
      if (mounted) setState(() => _stockBajoCount = lista.length);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: const BravoAppBar(title: "PANEL DE CONTROL"),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/images/Bravo restaurante.jpg'),
            fit: BoxFit.cover,
          ),
        ),
        child: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withValues(alpha: 0.5),
                Colors.black.withValues(alpha: 0.85),
              ],
            ),
          ),
          child: SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
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
                    if (_stockBajoCount > 0) ...[
                      const SizedBox(height: 16),
                      _buildAlertaBanner(),
                    ],
                    const SizedBox(height: 32),
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
                            badge: _stockBajoCount,
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

  Widget _buildAlertaBanner() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.red.shade900.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.red.shade400.withValues(alpha: 0.5), width: 1.5),
          ),
          child: Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.red.shade200, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '$_stockBajoCount ingrediente${_stockBajoCount == 1 ? '' : 's'} '
                  'por debajo del stock mínimo',
                  style: TextStyle(
                    color: Colors.red.shade100,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AdminStockScreen()),
                ).then((_) => _cargarStockBajo()),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.red.shade200,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                ),
                child: const Text('Ver'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAdminCard({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required Widget destination,
    bool isFullWidth = false,
    int badge = 0,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          height: isFullWidth ? 120 : 160,
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.45),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.15),
              width: 1.5,
            ),
          ),
          child: Stack(
            children: [
              Positioned.fill(
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(20),
                    highlightColor: AppColors.button.withValues(alpha: 0.1),
                    splashColor: AppColors.button.withValues(alpha: 0.2),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => destination),
                    ).then((_) => _cargarStockBajo()),
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
                                          color: Colors.white.withValues(alpha: 0.6),
                                          fontSize: 14,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Icon(
                                  Icons.arrow_forward_ios,
                                  color: Colors.white.withValues(alpha: 0.3),
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
                                    color: Colors.white.withValues(alpha: 0.6),
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                ),
              ),
              if (badge > 0)
                Positioned(
                  top: 10,
                  right: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.red.shade700,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.3),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      '$badge',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIconContainer(IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.button.withValues(alpha: 0.2),
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.button.withValues(alpha: 0.5), width: 1),
      ),
      child: Icon(icon, color: AppColors.button, size: 30),
    );
  }
}

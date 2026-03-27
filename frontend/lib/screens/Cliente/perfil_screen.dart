import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/colors_style.dart';
import '../../providers/auth_provider.dart';
import 'historial_pedidos_screen.dart';

class PerfilScreen extends StatefulWidget {
  const PerfilScreen({super.key});

  @override
  State<PerfilScreen> createState() => _PerfilScreenState();
}

class _PerfilScreenState extends State<PerfilScreen> {
  late TextEditingController _nombreController;
  late TextEditingController _emailController;
  late TextEditingController _telefonoController;
  late TextEditingController _direccionController;
  bool _hayCambios = false;

  @override
  void initState() {
    super.initState();
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final usuario = auth.usuarioActual;
    _nombreController = TextEditingController(text: usuario?.nombre ?? '');
    _emailController = TextEditingController(text: usuario?.email ?? '');
    _telefonoController = TextEditingController(text: usuario?.telefono ?? '');
    _direccionController = TextEditingController(text: usuario?.direccion ?? '');

    _nombreController.addListener(_detectarCambios);
    _emailController.addListener(_detectarCambios);
    _telefonoController.addListener(_detectarCambios);
    _direccionController.addListener(_detectarCambios);
  }

  void _detectarCambios() {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final usuario = auth.usuarioActual;
    final cambio = _nombreController.text != (usuario?.nombre ?? '') ||
        _emailController.text != (usuario?.email ?? '') ||
        _telefonoController.text != (usuario?.telefono ?? '') ||
        _direccionController.text != (usuario?.direccion ?? '');
    if (cambio != _hayCambios) {
      setState(() => _hayCambios = cambio);
    }
  }

  @override
  void dispose() {
    _nombreController.removeListener(_detectarCambios);
    _emailController.removeListener(_detectarCambios);
    _telefonoController.removeListener(_detectarCambios);
    _direccionController.removeListener(_detectarCambios);
    _nombreController.dispose();
    _emailController.dispose();
    _telefonoController.dispose();
    _direccionController.dispose();
    super.dispose();
  }

  void _guardarCambios() {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    auth.actualizarPerfil(
      nombre: _nombreController.text.trim(),
      email: _emailController.text.trim(),
      telefono: _telefonoController.text.trim(),
      direccion: _direccionController.text.trim(),
    );
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Datos actualizados correctamente'),
        backgroundColor: AppColors.button,
        behavior: SnackBarBehavior.floating,
      ),
    );
    setState(() => _hayCambios = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.gold),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'MI PERFIL',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),

      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Avatar
            const CircleAvatar(
              radius: 50,
              backgroundColor: AppColors.panel,
              child: Icon(
                Icons.person,
                size: 50,
                color: AppColors.gold,
              ),
            ),
            const SizedBox(height: 24),

            // Campos de datos personales
            _buildCampo('Nombre', _nombreController, Icons.person_outline),
            const SizedBox(height: 16),
            _buildCampo('Email', _emailController, Icons.email_outlined),
            const SizedBox(height: 16),
            _buildCampo('Teléfono', _telefonoController, Icons.phone_outlined),
            const SizedBox(height: 16),
            _buildCampo('Dirección', _direccionController, Icons.location_on_outlined),
            const SizedBox(height: 24),

            // Botón guardar cambios
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _hayCambios ? _guardarCambios : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _hayCambios ? AppColors.button : AppColors.panel,
                  foregroundColor: _hayCambios ? Colors.black : AppColors.textSecondary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Guardar cambios',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 20),
            const Divider(color: AppColors.line),
            const SizedBox(height: 10),

            // Opción: Historial de pedidos
            _buildOpcion(
              icon: Icons.receipt_long,
              titulo: 'Historial de pedidos',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const HistorialPedidosScreen(),
                  ),
                );
              },
            ),

            const SizedBox(height: 10),

            // Opción: Cerrar sesión
            _buildOpcion(
              icon: Icons.logout,
              titulo: 'Cerrar sesión',
              color: AppColors.error,
              onTap: () {
                final auth = Provider.of<AuthProvider>(context, listen: false);
                auth.cerrarSesion();
                Navigator.of(context).popUntil((route) => route.isFirst);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCampo(String label, TextEditingController controller, IconData icon) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.panel,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.line),
      ),
      child: TextField(
        controller: controller,
        style: const TextStyle(color: AppColors.textPrimary),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(
            color: AppColors.textSecondary.withOpacity(0.7),
          ),
          prefixIcon: Icon(icon, color: AppColors.gold),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
  }

  Widget _buildOpcion({
    required IconData icon,
    required String titulo,
    required VoidCallback onTap,
    Color color = AppColors.gold,
  }) {
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(
        titulo,
        style: TextStyle(
          color: color == AppColors.error ? color : AppColors.textPrimary,
          fontWeight: FontWeight.w500,
        ),
      ),
      trailing: Icon(Icons.chevron_right, color: color),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      tileColor: AppColors.panel,
      onTap: onTap,
    );
  }
}

import 'package:flutter/material.dart';
import '../../core/colors_style.dart';
import '../../services/usuario_service.dart';

class CrearUsuarioScreen extends StatefulWidget {
  final String restauranteId;

  const CrearUsuarioScreen({super.key, required this.restauranteId});

  @override
  State<CrearUsuarioScreen> createState() => _CrearUsuarioScreenState();
}

class _CrearUsuarioScreenState extends State<CrearUsuarioScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usuarioService = UsuarioService();

  // Controladores para capturar lo que se escribe
  final _nombreCtrl = TextEditingController();
  final _correoCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  
  String _rolSeleccionado = 'trabajador'; // Rol por defecto
  bool _cargando = false;

  void _guardar() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _cargando = true);

    bool exito = await _usuarioService.crearUsuario(
      nombre: _nombreCtrl.text.trim(),
      correo: _correoCtrl.text.trim(),
      password: _passCtrl.text.trim(),
      rol: _rolSeleccionado,
      restauranteId: widget.restauranteId,
    );

    setState(() => _cargando = false);

    if (exito) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('¡Usuario creado con éxito!'), backgroundColor: Colors.green),
      );
      Navigator.pop(context); // Volver atrás al terminar
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error al crear el usuario. ¿Correo repetido?'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Registrar Personal')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(25),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              const Icon(Icons.person_add_alt_1, size: 80, color: AppColors.backgroundButton),
              const SizedBox(height: 20),
              
              // CAMPO NOMBRE
              _buildTextField(label: 'Nombre Completo', controller: _nombreCtrl, icon: Icons.badge),
              const SizedBox(height: 15),

              // CAMPO CORREO
              _buildTextField(label: 'Correo Electrónico', controller: _correoCtrl, icon: Icons.email, type: TextInputType.emailAddress),
              const SizedBox(height: 15),

              // CAMPO PASSWORD
              _buildTextField(label: 'Contraseña Temporal', controller: _passCtrl, icon: Icons.lock, isPassword: true),
              const SizedBox(height: 20),

              // SELECTOR DE ROL (Dropdown)
              DropdownButtonFormField<String>(
                value: _rolSeleccionado,
                decoration: InputDecoration(
                  labelText: 'Asignar Rol',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
                  prefixIcon: const Icon(Icons.settings_accessibility),
                ),
                items: const [
                  DropdownMenuItem(value: 'trabajador', child: Text('Trabajador (Cocinero/Mesero)')),
                  DropdownMenuItem(value: 'administrador', child: Text('Administrador de Sucursal')),
                  DropdownMenuItem(value: 'cliente', child: Text('Cliente')),
                ],
                onChanged: (val) => setState(() => _rolSeleccionado = val!),
              ),

              const SizedBox(height: 40),

              // BOTÓN GUARDAR
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.backgroundButton,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  ),
                  onPressed: _cargando ? null : _guardar,
                  child: _cargando 
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('CREAR USUARIO', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Widget auxiliar para los inputs (mismo estilo que el login)
  Widget _buildTextField({
    required String label, 
    required TextEditingController controller, 
    required IconData icon,
    bool isPassword = false,
    TextInputType type = TextInputType.text,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: isPassword,
      keyboardType: type,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
      ),
      validator: (val) => val == null || val.isEmpty ? 'Este campo es obligatorio' : null,
    );
  }
}
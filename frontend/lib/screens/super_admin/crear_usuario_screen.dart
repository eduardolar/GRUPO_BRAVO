import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/colors_style.dart';
import '../../services/usuario_service.dart';
import '../../components/Cliente/entrada_texto.dart';

class CrearUsuarioScreen extends StatefulWidget {
  final String restauranteId;
  final String? rolFijo; // Si se pasa, el rol queda fijo y no se muestra el dropdown
  const CrearUsuarioScreen({super.key, required this.restauranteId, this.rolFijo});

  @override
  State<CrearUsuarioScreen> createState() => _CrearUsuarioScreenState();
}

class _CrearUsuarioScreenState extends State<CrearUsuarioScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usuarioService = UsuarioService();

  final _nombreCtrl = TextEditingController();
  final _correoCtrl = TextEditingController();

  late String _rolSeleccionado;
  bool _cargando = false;

  @override
  void initState() {
    super.initState();
    _rolSeleccionado = widget.rolFijo ?? 'trabajador';
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _correoCtrl.dispose();
    super.dispose();
  }

  void _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _cargando = true);

    final correo = _correoCtrl.text.trim();
    final exito = await _usuarioService.crearUsuario(
      nombre: _nombreCtrl.text.trim(),
      correo: correo,
      password: '',
      rol: _rolSeleccionado,
      restauranteId: widget.restauranteId,
    );

    setState(() => _cargando = false);
    if (!mounted) return;

    if (exito) {
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppColors.background,
          shape: const RoundedRectangleBorder(),
          title: Row(
            children: [
              const Icon(Icons.mark_email_read_outlined, color: AppColors.button),
              const SizedBox(width: 10),
              Text(
                widget.rolFijo == 'administrador' ? '¡Administrador creado!' : '¡Personal registrado!',
                style: GoogleFonts.manrope(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.rolFijo == 'administrador'
                    ? 'Se ha enviado un correo de activación al nuevo administrador:'
                    : 'Se ha enviado un correo de activación al nuevo empleado:',
                style: GoogleFonts.manrope(color: AppColors.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                color: AppColors.panel,
                child: Text(
                  correo,
                  style: GoogleFonts.manrope(fontWeight: FontWeight.w700, color: AppColors.button, fontSize: 13),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                widget.rolFijo == 'administrador'
                    ? 'El administrador debe abrir la app, ir a "Activar mi cuenta" e ingresar el código recibido para establecer su contraseña.'
                    : 'El empleado debe abrir la app, ir a "Activar mi cuenta" e ingresar el código que recibió para establecer su contraseña definitiva.',
                style: GoogleFonts.manrope(color: AppColors.textSecondary, fontSize: 12, height: 1.5),
              ),
            ],
          ),
          actions: [
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.button,
                  foregroundColor: Colors.white,
                  shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                  elevation: 0,
                ),
                onPressed: () => Navigator.pop(ctx),
                child: Text('ENTENDIDO', style: GoogleFonts.manrope(fontWeight: FontWeight.w700, letterSpacing: 1.5)),
              ),
            ),
          ],
        ),
      );
      if (mounted) Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al crear el usuario. ¿Correo repetido?', style: GoogleFonts.manrope()),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Imagen de fondo
          Positioned.fill(
            child: Image.asset(
              'assets/images/Bravo restaurante.jpg',
              fit: BoxFit.cover,
            ),
          ),

          // Overlay oscuro
          Positioned.fill(
            child: Container(
              color: AppColors.shadow.withValues(alpha: 0.85),
            ),
          ),

          // Formulario
          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 500),
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 20),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        _buildHeader(),
                        const SizedBox(height: 30),
                        _buildInputs(),
                        const SizedBox(height: 24),
                        _buildButton(),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Botón volver
          Positioned(
            top: 20,
            left: 10,
            child: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        const SizedBox(height: 40),
        Text(
          widget.rolFijo == 'administrador' ? 'Nuevo Administrador' : 'Nuevo Personal',
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontFamily: 'Playfair Display',
            color: Colors.white,
            fontSize: 36,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 10),
        Container(height: 2, width: 40, color: AppColors.button),
        const SizedBox(height: 15),
        Text(
          widget.rolFijo == 'administrador'
              ? 'Registra un administrador para esta sucursal'
              : 'Registra al personal de esta sucursal',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.7),
            fontSize: 15,
          ),
        ),
      ],
    );
  }

  Widget _buildInputs() {
    return Column(
      children: [
        EntradaTexto(
          etiqueta: 'Nombre Completo',
          icono: Icons.badge_outlined,
          controlador: _nombreCtrl,
          validador: (v) => v == null || v.isEmpty ? 'Este campo es obligatorio' : null,
        ),
        EntradaTexto(
          etiqueta: 'Correo Electrónico',
          icono: Icons.email_outlined,
          tipoTeclado: TextInputType.emailAddress,
          controlador: _correoCtrl,
          validador: (v) => v == null || v.isEmpty ? 'Este campo es obligatorio' : null,
        ),
        if (widget.rolFijo == null)
          Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: DropdownButtonFormField<String>(
              initialValue: _rolSeleccionado,
              style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
              decoration: InputDecoration(
                labelText: 'Asignar Rol',
                labelStyle: const TextStyle(color: AppColors.textSecondary),
                prefixIcon: const Icon(Icons.settings_accessibility_outlined, color: AppColors.gold),
                filled: true,
                fillColor: AppColors.panel,
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                  borderSide: const BorderSide(color: AppColors.line),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                  borderSide: const BorderSide(color: AppColors.button, width: 2),
                ),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
              ),
              items: const [
                DropdownMenuItem(value: 'cocinero', child: Text('Cocinero')),
                DropdownMenuItem(value: 'camarero', child: Text('Camarero')),
                DropdownMenuItem(value: 'mesero', child: Text('Mesero')),
                DropdownMenuItem(value: 'trabajador', child: Text('Trabajador (general)')),
                DropdownMenuItem(value: 'administrador', child: Text('Administrador')),
              ],
              onChanged: (val) => setState(() => _rolSeleccionado = val!),
            ),
          ),
      ],
    );
  }

  Widget _buildButton() {
    return SizedBox(
      width: double.infinity,
      height: 55,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.button,
          foregroundColor: Colors.white,
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
          elevation: 0,
        ),
        onPressed: _cargando ? null : _guardar,
        child: _cargando
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
              )
            : const Text(
                'CREAR USUARIO',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                ),
              ),
      ),
    );
  }
}

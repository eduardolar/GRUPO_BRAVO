import 'package:flutter/material.dart';
import '../core/colors_style.dart'; // Asegúrate de que la ruta a AppColors sea correcta
import 'home_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _obscureText = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Aplicando el color de fondo base (Negro)
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.iconPrimary),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 30),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Título principal en Blanco
                const Center(
                  child: Text(
                    "Registrate",
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                // Subtítulo en Gris claro
                const Center(
                  child: Text(
                    "Completa tus datos para continuar",
                    style: TextStyle(
                      color: AppColors.textSecundary,
                      fontSize: 16,
                    ),
                  ),
                ),
                const SizedBox(height: 40),

                // Inputs con el estilo de panel oscuro y detalles dorados
                _customInput(label: "Nombre", icon: Icons.person_outline),
                _customPasswordInput(label: "Contraseña"),
                _customInput(
                  label: "Correo electrónico",
                  icon: Icons.email_outlined,
                  keyboardType: TextInputType.emailAddress,
                ),
                _customInput(
                  label: "Teléfono",
                  icon: Icons.phone_android_outlined,
                  keyboardType: TextInputType.phone,
                ),
                _customInput(label: "Dirección", icon: Icons.map_outlined),

                const SizedBox(height: 40),

                // Botón principal con color Dorado (Gold)
                Container(
                  height: 55,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(15),
                    boxShadow: const [
                      BoxShadow(
                        color: AppColors.shadow,
                        blurRadius: 10,
                        offset: Offset(0, 5),
                      ),
                    ],
                  ),
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.button,
                      foregroundColor: AppColors
                          .background, // Texto oscuro sobre fondo dorado
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                    ),
                    onPressed: () {
                      if (_formKey.currentState!.validate()) {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const HomeScreen(),
                          ),
                        );
                      }
                    },
                    child: const Text(
                      "CREAR CUENTA",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // Botón de volver con color secundario
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    "¿Ya tienes cuenta? Volver",
                    style: TextStyle(color: AppColors.textSecundary),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Widget para inputs normales con tu paleta de colores
  Widget _customInput({
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: TextFormField(
        keyboardType: keyboardType,
        style: const TextStyle(color: AppColors.textPrimary),
        decoration: InputDecoration(
          prefixIcon: Icon(icon, color: AppColors.iconDetail), // Icono Dorado
          labelText: label,
          labelStyle: const TextStyle(color: AppColors.textSecundary),
          filled: true,
          fillColor: AppColors.panel, // Fondo Gris muy oscuro
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: const BorderSide(color: AppColors.line), // Borde sutil
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: const BorderSide(
              color: AppColors.button,
              width: 2,
            ), // Borde dorado al escribir
          ),
          errorStyle: const TextStyle(color: AppColors.error),
        ),
      ),
    );
  }

  // Widget para contraseña con lógica de visibilidad
  Widget _customPasswordInput({required String label}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: TextFormField(
        obscureText: _obscureText,
        style: const TextStyle(color: AppColors.textPrimary),
        decoration: InputDecoration(
          prefixIcon: const Icon(
            Icons.lock_outline,
            color: AppColors.iconDetail,
          ),
          suffixIcon: IconButton(
            icon: Icon(
              _obscureText
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined,
              color: AppColors.iconPrimary,
            ),
            onPressed: () => setState(() => _obscureText = !_obscureText),
          ),
          labelText: label,
          labelStyle: const TextStyle(color: AppColors.textSecundary),
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
          errorStyle: const TextStyle(color: AppColors.error),
        ),
      ),
    );
  }
}

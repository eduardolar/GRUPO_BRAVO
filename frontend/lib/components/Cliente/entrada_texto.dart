import 'package:flutter/material.dart';
import '../../core/colors_style.dart';

class EntradaTexto extends StatelessWidget {
  final String etiqueta; // El texto que flota (Label)
  final IconData? icono; // El icono de la izquierda
  final bool esContrasena; // Si debe ocultar el texto
  final bool? mostrarTexto; // Controla el ojo (obscureText)
  final VoidCallback? alPresionarIcono; // Acción al tocar el ojo
  final TextInputType tipoTeclado; // Si es email, números, etc.
  final String? Function(String?)? validador;
  final TextEditingController? controlador;
  final bool readOnly;

  const EntradaTexto({
    super.key,
    required this.etiqueta,
    this.icono,
    this.esContrasena = false,
    this.mostrarTexto,
    this.alPresionarIcono,
    this.tipoTeclado = TextInputType.text,
    this.validador,
    this.controlador,
    this.readOnly = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: TextFormField(
        controller: controlador,
        validator: validador,
        // Si es contraseña y mostrarTexto es false, oculta los caracteres
        obscureText: esContrasena ? (mostrarTexto ?? true) : false,
        keyboardType: tipoTeclado,
        style: const TextStyle(color: AppColors.textPrimary),
        readOnly: readOnly,
        decoration: InputDecoration(
          prefixIcon: Icon(icono, color: AppColors.gold),
          // Solo muestra el botón del ojo si el campo se marcó como contraseña
          suffixIcon: esContrasena
              ? IconButton(
                  icon: Icon(
                    mostrarTexto!
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    color: AppColors.iconPrimary,
                  ),
                  onPressed: alPresionarIcono,
                )
              : null,
          labelText: etiqueta,
          labelStyle: const TextStyle(color: AppColors.textSecondary),
          filled: true,
          fillColor: AppColors.panel,
          // Bordes redondeados
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: const BorderSide(color: AppColors.line),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: const BorderSide(color: AppColors.button, width: 2),
          ),
          // Estilo para cuando hay un error
          errorStyle: const TextStyle(color: AppColors.error),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
        ),
      ),
    );
  }
}

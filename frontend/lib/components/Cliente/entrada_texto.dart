import 'package:flutter/material.dart';
import '../../core/colors_style.dart';

class EntradaTexto extends StatelessWidget {
  final String etiqueta;
  final IconData? icono;
  final bool esContrasena;
  final bool? mostrarTexto;
  final VoidCallback? alPresionarIcono;
  final TextInputType tipoTeclado;
  final String? Function(String?)? validador;
  final TextEditingController? controlador;
  final List<String>? autofillHints;
  final TextInputAction textInputAction;

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
    this.autofillHints,
    this.textInputAction = TextInputAction.next,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: TextFormField(
        controller: controlador,
        validator: validador,
        obscureText: esContrasena ? (mostrarTexto ?? true) : false,
        keyboardType: tipoTeclado,
        autofillHints: autofillHints,
        textInputAction: textInputAction,
        style: const TextStyle(color: AppColors.textPrimary),
        readOnly: readOnly,
        decoration: InputDecoration(
          prefixIcon: Icon(icono, color: AppColors.gold),
          // Solo muestra el botón del ojo si el campo se marcó como contraseña
          suffixIcon: esContrasena
              ? IconButton(
                  tooltip: mostrarTexto! ? 'Ocultar contraseña' : 'Mostrar contraseña',
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

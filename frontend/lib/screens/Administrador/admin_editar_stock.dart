import 'package:flutter/material.dart';
import 'package:frontend/components/Cliente/entrada_texto.dart';
import 'package:frontend/core/colors_style.dart';
import 'package:frontend/models/ingrediente_model.dart';

class EditarIngredienteStock extends StatefulWidget {
  final Ingrediente ingredienteEdit;

  const EditarIngredienteStock({super.key, required this.ingredienteEdit});

  @override
  State<EditarIngredienteStock> createState() => _EditarIngredienteStockState();
}

/// ╔══════════════════════════════════════════════════════════════╗
/// ║  NO ESTA CONECTADO CON LA BASE DE DATOS EN ESTA PRUEBA       ║
/// ╚══════════════════════════════════════════════════════════════╝

class _EditarIngredienteStockState extends State<EditarIngredienteStock> {
  // Key para el formulario
  final _formKeyStock = GlobalKey<FormState>();

  // Controladores para guardar los valores de las variables
  final TextEditingController _nombreIngrediente = TextEditingController();
  final TextEditingController _cantidadIngrediente = TextEditingController();
  final TextEditingController _cantidadIngredienteMin = TextEditingController();

  @override
  void dispose() {
    // Limpiamos el controlador al eliminar la ventana
    _nombreIngrediente.dispose();
    _cantidadIngrediente.dispose();
    _cantidadIngredienteMin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppbarEditarIngrediente(),
      body: BodyEditarIngrediente(),
    );
  }

  AppBar AppbarEditarIngrediente() {
    return AppBar(
      centerTitle: true,
      title: Text("EDITAR INGREDIENTE"),
      backgroundColor: AppColors.background,
    );
  }

  Padding BodyEditarIngrediente() {
    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: Form(
        key: _formKeyStock,
        child: Column(
          children: [
            Spacer(),
            Text(
              "${widget.ingredienteEdit.nombre}",
              style: TextStyle(fontSize: 50),
            ),
            SizedBox(height: 30),

            Row(
              children: [
                Expanded(
                  child: EntradaTexto(
                    etiqueta: "Cantidad a añadir",
                    icono: Icons.face,
                    controlador: _cantidadIngrediente,
                    validador: (valor) {
                      if (valor == null || valor.isEmpty) {
                        return "Campo obligatorio";
                      }
                      if (int.tryParse(valor) == null) {
                        return "Tiene que ser un número";
                      }
                      return null;
                    },
                  ),
                ),
                SizedBox(width: 16),
                Text("${widget.ingredienteEdit.unidad}"),
              ],
            ),
            SizedBox(height: 30),
            EntradaTexto(
              etiqueta:
                  "Cantidad mínima avisar. Act: ${widget.ingredienteEdit.stockMinimo} ${widget.ingredienteEdit.unidad}",
              icono: Icons.mail,
              controlador: _cantidadIngredienteMin,
              validador: (valor) {
                if (valor == null || valor.isEmpty) {
                  return "Campo obligatorio";
                }
                if (int.tryParse(valor) == null) {
                  return "Tiene que ser un número";
                }
                return null;
              },
            ),
            Spacer(),
            botonEliminar(),
            SizedBox(height: 15),
            botonGuardar(),
          ],
        ),
      ),
    );
  }

  Widget botonGuardar() {
    return Container(
      width: double.infinity,
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
        onPressed: () {
          if (_formKeyStock.currentState!.validate()) {
            // Añadir lógica para enviar este nuevo ingrediente al servidor
            print("guardando nuevo plato...");
            Navigator.pop(context);
          } else {
            print("Formulario no válido");
          }
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.button,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          elevation: 0,
        ),
        child: Text("ACTUALIZAR INGREDIENTE"),
      ),
    );
  }

  Widget botonEliminar() {
    return Container(
      width: double.infinity,
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
        onPressed: () {
          // Añadir logica para borrar registro en el servidor
          Navigator.pop(context);
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.backgroundButton,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadiusGeometry.circular(15),
          ),
          elevation: 0,
        ),
        child: Text("ELIMINAR INGREDIENTE"),
      ),
    );
  }
}

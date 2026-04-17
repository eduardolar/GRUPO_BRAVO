import 'package:flutter/material.dart';
import 'package:frontend/components/Cliente/entrada_texto.dart';
import 'package:frontend/core/colors_style.dart';

class NuevoIngrediente extends StatefulWidget {
  const NuevoIngrediente({super.key});

  @override
  State<NuevoIngrediente> createState() => _NuevoIngredienteState();
}

class _NuevoIngredienteState extends State<NuevoIngrediente> {

  // Elementos para la creacion de la lista desplegable
  String? _unidadSeleccionada;
  final List<String> _unidades = ["Kg", "Litros", "Unidades"];

  // Controladores para guardar los valores de las variables
  final TextEditingController _nombreIngrediente = TextEditingController();
  final TextEditingController _cantidadIngrediente = TextEditingController();
  final TextEditingController _cantidadIngredienteMin = TextEditingController();

  @override
  void dispose(){ // Limpiamos el controlador al eliminar la ventana
    _nombreIngrediente.dispose();
    _cantidadIngrediente.dispose();
    _cantidadIngredienteMin.dispose();
    super.dispose();
  }



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBarNuevoIngrediente(),
      body: BodyNuevoIngrediente(),
    );
  }

  AppBar AppBarNuevoIngrediente() {
    return AppBar(centerTitle: true, title: Text("NUEVO INGREDIENTE"), backgroundColor: AppColors.background,);
  }

  Padding BodyNuevoIngrediente() {
    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: Column(
        children: [
          Spacer(),
          EntradaTexto(
            etiqueta: "Nombre del ingrediente",
            icono: Icons.abc_outlined,
            controlador: _nombreIngrediente,
          ),
          SizedBox(height: 30),

          Row(
            children: [
              Expanded(child: EntradaTexto(etiqueta: "Cantidad", icono: Icons.face, controlador: _cantidadIngrediente,)),
              SizedBox(width: 16),
              DropdownButton(
                value: _unidadSeleccionada,
                hint: const Text("Unidades"),
                items: _unidades.map((String valor) {
                  return DropdownMenuItem<String>(
                    value: valor,
                    child: Text(valor),
                  );
                }).toList(),
                onChanged: (String? nuevoValor) {
                  setState(() {
                    _unidadSeleccionada = nuevoValor;
                  });
                },
              ),
            ],
          ),
          SizedBox(height: 30),
          EntradaTexto(etiqueta: "Cantidad mínima para avisar", icono: Icons.mail, controlador: _cantidadIngredienteMin,),
          Spacer(),
          botonGuardar()
        ],
      ),
    );
  }

  Widget botonGuardar(){
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
        onPressed: (){
          // Añadir lógica para enviar este nuevo ingrediente al servidor
          Navigator.pop(context);
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.button,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          elevation: 0,
        ), 
        child: Text("CREAR INGREDIENTE"),
      ),

    );

  }
}

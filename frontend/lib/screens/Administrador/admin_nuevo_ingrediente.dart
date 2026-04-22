import 'package:flutter/material.dart';
import '../../core/colors_style.dart';
import '../../services/ingredientes_service.dart';

class AdminNuevoIngredienteScreen extends StatefulWidget {
  const AdminNuevoIngredienteScreen({super.key});

  @override
  State<AdminNuevoIngredienteScreen> createState() => _AdminNuevoIngredienteScreenState();
}

class _AdminNuevoIngredienteScreenState extends State<AdminNuevoIngredienteScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _estaGuardando = false;

  final _nombreCtrl = TextEditingController();
  final _cantidadCtrl = TextEditingController();
  final _minimoCtrl = TextEditingController();
  
  String _categoriaSeleccionada = 'Vegetales';
  String _unidadSeleccionada = 'kg';

  final List<String> _categorias = [
    'Carnes', 'Vegetales', 'Lácteos', 'Panadería', 'Salsas', 'Otras'
  ];
  final List<String> _unidades = ['kg', 'L', 'ud', 'unidades'];

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _cantidadCtrl.dispose();
    _minimoCtrl.dispose();
    super.dispose();
  }

  void _crearIngrediente() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _estaGuardando = true);
      try {
        await IngredienteService.crearIngrediente({
          'nombre': _nombreCtrl.text.trim(),
          'categoria': _categoriaSeleccionada,
          'cantidad_actual': double.parse(_cantidadCtrl.text),
          'unidad': _unidadSeleccionada,
          'stock_minimo': double.parse(_minimoCtrl.text),
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Creado con éxito')));
          Navigator.pop(context); 
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
        }
      } finally {
        if (mounted) setState(() => _estaGuardando = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Nuevo Ingrediente'), backgroundColor: AppColors.backgroundButton),
      body: _estaGuardando
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    TextFormField(
                      controller: _nombreCtrl,
                      decoration: const InputDecoration(labelText: 'Nombre del Ingrediente'),
                      validator: (v) => v!.isEmpty ? 'Requerido' : null,
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: _categoriaSeleccionada,
                      decoration: const InputDecoration(labelText: 'Categoría'),
                      items: _categorias.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                      onChanged: (val) => setState(() => _categoriaSeleccionada = val!),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: TextFormField(
                            controller: _cantidadCtrl,
                            decoration: const InputDecoration(labelText: 'Cantidad Inicial'),
                            keyboardType: TextInputType.number,
                            validator: (v) => v!.isEmpty ? 'Requerido' : null,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          flex: 1,
                          child: DropdownButtonFormField<String>(
                            value: _unidadSeleccionada,
                            decoration: const InputDecoration(labelText: 'Unidad'),
                            items: _unidades.map((u) => DropdownMenuItem(value: u, child: Text(u))).toList(),
                            onChanged: (val) => setState(() => _unidadSeleccionada = val!),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _minimoCtrl,
                      decoration: const InputDecoration(labelText: 'Stock Mínimo de Alerta'),
                      keyboardType: TextInputType.number,
                      validator: (v) => v!.isEmpty ? 'Requerido' : null,
                    ),
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity, height: 50,
                      child: ElevatedButton(
                        onPressed: _crearIngrediente,
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                        child: const Text('CREAR INGREDIENTE', style: TextStyle(color: Colors.white)),
                      ),
                    ),
                  ],
                ),
              ),
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
          if (_formKey.currentState!.validate()) {
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
        child: Text("CREAR INGREDIENTE"),
      ),

    );
  }
}
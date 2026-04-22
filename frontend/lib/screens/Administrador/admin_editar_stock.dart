import 'package:flutter/material.dart';
import '../../core/colors_style.dart';
import '../../models/ingrediente_model.dart';
import '../../services/ingredientes_service.dart';

class AdminEditarStockScreen extends StatefulWidget {
  final Ingrediente ingrediente;

  const AdminEditarStockScreen({super.key, required this.ingrediente});

  @override
  State<AdminEditarStockScreen> createState() => _AdminEditarStockScreenState();
}

class _AdminEditarStockScreenState extends State<AdminEditarStockScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _estaGuardando = false;

  late TextEditingController _nombreCtrl;
  late TextEditingController _cantidadCtrl;
  late TextEditingController _minimoCtrl;
  String _categoriaSeleccionada = 'Otros';
  String _unidadSeleccionada = 'kg';

  final List<String> _categorias = IngredienteService.categorias;
  final List<String> _unidades = IngredienteService.unidades;

  @override
  void initState() {
    super.initState();
    _nombreCtrl = TextEditingController(text: widget.ingrediente.nombre);
    _cantidadCtrl = TextEditingController(text: widget.ingrediente.cantidadActual.toString());
    _minimoCtrl = TextEditingController(text: widget.ingrediente.stockMinimo.toString());
    
    _categoriaSeleccionada = _categorias.contains(widget.ingrediente.categoria)
        ? widget.ingrediente.categoria
        : 'Otros';
    _unidadSeleccionada = _unidades.contains(widget.ingrediente.unidad)
        ? widget.ingrediente.unidad
        : 'kg';
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _cantidadCtrl.dispose();
    _minimoCtrl.dispose();
    super.dispose();
  }

  void _guardarCambios() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _estaGuardando = true);
      try {
        await IngredienteService.actualizarIngrediente(
          widget.ingrediente.id,
          {
            'nombre': _nombreCtrl.text.trim(),
            'categoria': _categoriaSeleccionada,
            'cantidad_actual': double.parse(_cantidadCtrl.text),
            'unidad': _unidadSeleccionada,
            'stock_minimo': double.parse(_minimoCtrl.text),
          },
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Stock actualizado')));
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
      appBar: AppBar(title: const Text('Editar Stock'), backgroundColor: AppColors.backgroundButton),
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
                            decoration: const InputDecoration(labelText: 'Cantidad Actual'),
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
                      decoration: const InputDecoration(labelText: 'Stock Mínimo'),
                      keyboardType: TextInputType.number,
                      validator: (v) => v!.isEmpty ? 'Requerido' : null,
                    ),
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity, height: 50,
                      child: ElevatedButton(
                        onPressed: _guardarCambios,
                        style: ElevatedButton.styleFrom(backgroundColor: AppColors.button),
                        child: const Text('GUARDAR CAMBIOS', style: TextStyle(color: Colors.white)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
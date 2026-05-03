import 'package:flutter/material.dart';
import 'package:frontend/components/Cliente/entrada_texto.dart';
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
    _cantidadCtrl = TextEditingController(
        text: widget.ingrediente.cantidadActual.toString());
    _minimoCtrl =
        TextEditingController(text: widget.ingrediente.stockMinimo.toString());

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

  String? _validarNumero(String? v) {
    if (v == null || v.trim().isEmpty) return 'Requerido';
    if (double.tryParse(v.trim()) == null) return 'Debe ser un número';
    return null;
  }

  Future<void> _guardarCambios() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _estaGuardando = true);
    try {
      await IngredienteService.actualizarIngrediente(
        widget.ingrediente.id,
        {
          'nombre': _nombreCtrl.text.trim(),
          'cantidadActual': double.parse(_cantidadCtrl.text.trim()),
          'unidad': _unidadSeleccionada,
          'stockMinimo': double.parse(_minimoCtrl.text.trim()),
          'categoria': _categoriaSeleccionada,
        },
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Stock actualizado')),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _estaGuardando = false);
    }
  }

  Future<void> _eliminarIngrediente() async {
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar ingrediente'),
        content: Text(
            '¿Seguro que quieres eliminar "${widget.ingrediente.nombre}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmado != true) return;

    setState(() => _estaGuardando = true);
    try {
      await IngredienteService.eliminarIngrediente(widget.ingrediente.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ingrediente eliminado')),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al eliminar: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _estaGuardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Editar Stock'),
        backgroundColor: AppColors.backgroundButton,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              EntradaTexto(
                icono: Icons.abc,
                controlador: _nombreCtrl,
                etiqueta: 'Nombre del Ingrediente',
                validador: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Requerido' : null,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: EntradaTexto(
                      icono: Icons.filter_9_plus,
                      controlador: _cantidadCtrl,
                      etiqueta: 'Cantidad Actual',
                      tipoTeclado: TextInputType.number,
                      validador: _validarNumero,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 1,
                    child: DropdownButtonFormField<String>(
                      initialValue: _unidadSeleccionada,
                      decoration:
                          const InputDecoration(labelText: 'Unidad'),
                      items: _unidades
                          .map((u) =>
                              DropdownMenuItem(value: u, child: Text(u)))
                          .toList(),
                      onChanged: (val) =>
                          setState(() => _unidadSeleccionada = val!),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              EntradaTexto(
                icono: Icons.warning,
                controlador: _minimoCtrl,
                etiqueta: 'Stock Mínimo',
                tipoTeclado: TextInputType.number,
                validador: _validarNumero,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _categoriaSeleccionada,
                decoration: const InputDecoration(labelText: 'Categoría'),
                items: _categorias
                    .map((c) =>
                        DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: (val) =>
                    setState(() => _categoriaSeleccionada = val!),
              ),
              const SizedBox(height: 32),
              _botonEliminar(),
              const SizedBox(height: 16),
              _botonGuardar(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _botonGuardar() {
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
        onPressed: _estaGuardando ? null : _guardarCambios,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.button,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          elevation: 0,
        ),
        child: _estaGuardando
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white),
              )
            : const Text("GUARDAR CAMBIOS"),
      ),
    );
  }

  Widget _botonEliminar() {
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
        onPressed: _estaGuardando ? null : _eliminarIngrediente,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.backgroundButton,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          elevation: 0,
        ),
        child: const Text("ELIMINAR INGREDIENTE"),
      ),
    );
  }
}

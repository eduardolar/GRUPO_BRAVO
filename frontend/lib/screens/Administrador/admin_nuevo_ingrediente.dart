import 'package:flutter/material.dart';
import 'package:frontend/components/Cliente/entrada_texto.dart';
import '../../core/colors_style.dart';
import '../../services/ingredientes_service.dart';

class AdminNuevoIngredienteScreen extends StatefulWidget {
  const AdminNuevoIngredienteScreen({super.key});

  @override
  State<AdminNuevoIngredienteScreen> createState() =>
      _AdminNuevoIngredienteScreenState();
}

class _AdminNuevoIngredienteScreenState
    extends State<AdminNuevoIngredienteScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _estaGuardando = false;

  final _nombreCtrl = TextEditingController();
  final _cantidadCtrl = TextEditingController();
  final _minimoCtrl = TextEditingController();

  String _categoriaSeleccionada = IngredienteService.categorias.first;
  String _unidadSeleccionada = IngredienteService.unidades.first;

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _cantidadCtrl.dispose();
    _minimoCtrl.dispose();
    super.dispose();
  }

  Future<void> _crearIngrediente() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _estaGuardando = true);
    try {
      await IngredienteService.crearIngrediente({
        'nombre': _nombreCtrl.text.trim(),
        'categoria': _categoriaSeleccionada,
        'cantidad_actual': double.parse(_cantidadCtrl.text.trim()),
        'unidad': _unidadSeleccionada,
        'stock_minimo': double.parse(_minimoCtrl.text.trim()),
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ingrediente creado con éxito'),
          backgroundColor: AppColors.disp,
        ),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error),
      );
    } finally {
      if (mounted) setState(() => _estaGuardando = false);
    }
  }

  InputDecoration _dropdownDecoration(String label, IconData icono) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: AppColors.textSecondary),
      prefixIcon: Icon(icono, color: AppColors.gold),
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
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: const BorderSide(color: AppColors.error),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: const BorderSide(color: AppColors.error, width: 2),
      ),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
      errorStyle: const TextStyle(color: AppColors.error),
    );
  }

  String? _validarNumero(String? v) {
    if (v == null || v.trim().isEmpty) return 'Campo requerido';
    if (double.tryParse(v.trim()) == null) return 'Introduce un número válido';
    if (double.parse(v.trim()) < 0) return 'Debe ser mayor o igual a 0';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Nuevo Ingrediente'),
        backgroundColor: AppColors.backgroundButton,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Nombre ──────────────────────────────────────────────────
              EntradaTexto(
                icono: Icons.label_outline,
                controlador: _nombreCtrl,
                etiqueta: 'Nombre del ingrediente',
                validador: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Campo requerido' : null,
              ),

              // ── Categoría ────────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: DropdownButtonFormField<String>(
                  initialValue: _categoriaSeleccionada,
                  decoration: _dropdownDecoration(
                    'Categoría',
                    Icons.category_outlined,
                  ),
                  isExpanded: true,
                  style: const TextStyle(color: AppColors.textPrimary),
                  dropdownColor: AppColors.panel,
                  items: IngredienteService.categorias
                      .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                      .toList(),
                  onChanged: (val) =>
                      setState(() => _categoriaSeleccionada = val!),
                ),
              ),

              // ── Cantidad inicial + Unidad ────────────────────────────────
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 3,
                    child: EntradaTexto(
                      icono: Icons.inventory_2_outlined,
                      controlador: _cantidadCtrl,
                      etiqueta: 'Cantidad inicial',
                      tipoTeclado: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      validador: _validarNumero,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 20),
                      child: DropdownButtonFormField<String>(
                        initialValue: _unidadSeleccionada,
                        decoration: _dropdownDecoration(
                          'Unidad',
                          Icons.scale_outlined,
                        ),
                        style: const TextStyle(color: AppColors.textPrimary),
                        dropdownColor: AppColors.panel,
                        items: IngredienteService.unidades
                            .map(
                              (u) => DropdownMenuItem(value: u, child: Text(u)),
                            )
                            .toList(),
                        onChanged: (val) =>
                            setState(() => _unidadSeleccionada = val!),
                      ),
                    ),
                  ),
                ],
              ),

              // ── Stock mínimo ─────────────────────────────────────────────
              EntradaTexto(
                icono: Icons.warning_amber_outlined,
                controlador: _minimoCtrl,
                etiqueta: 'Stock mínimo de alerta',
                tipoTeclado: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                validador: _validarNumero,
              ),

              const SizedBox(height: 12),

              // ── Botón crear ──────────────────────────────────────────────
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _estaGuardando ? null : _crearIngrediente,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.button,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: AppColors.button.withValues(
                      alpha: 0.5,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                    elevation: 2,
                    shadowColor: AppColors.sombra.withValues(alpha: 0.4),
                  ),
                  child: _estaGuardando
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.5,
                          ),
                        )
                      : const Text(
                          'CREAR INGREDIENTE',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.8,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

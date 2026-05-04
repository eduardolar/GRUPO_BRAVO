import 'package:flutter/material.dart';
import '../../models/producto_model.dart';
import '../../core/colors_style.dart';

/// Diálogo centrado que muestra los ingredientes de un producto y permite
/// al cliente desmarcar los que no quiera.
/// Devuelve la lista de nombres de ingredientes excluidos, o null si cancela.
Future<List<String>?> mostrarDialogoIngredientes(
  BuildContext context,
  Producto producto,
) {
  return showDialog<List<String>>(
    context: context,
    barrierColor: Colors.black54,
    builder: (context) => Center(
      child: _DialogoIngredientes(producto: producto),
    ),
  );
}

class _DialogoIngredientes extends StatefulWidget {
  final Producto producto;
  const _DialogoIngredientes({required this.producto});

  @override
  State<_DialogoIngredientes> createState() => _DialogoIngredientesState();
}

class _DialogoIngredientesState extends State<_DialogoIngredientes> {
  late Map<String, bool> _seleccion;

  @override
  void initState() {
    super.initState();
    _seleccion = {
      for (final ing in widget.producto.ingredientes) ing.nombre: true,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        width: MediaQuery.of(context).size.width * 0.85,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.7,
        ),
        decoration: BoxDecoration(
          color: AppColors.panel,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Cabecera con título y botón cerrar
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 8, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.producto.nombre,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Cerrar',
                    onPressed: () => Navigator.pop(context, null),
                    icon: const Icon(Icons.close, color: AppColors.textSecondary),
                    splashRadius: 20,
                  ),
                ],
              ),
            ),

            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Desmarca los ingredientes que no quieras',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                ),
              ),
            ),
            const SizedBox(height: 8),

            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Divider(height: 1, color: AppColors.line),
            ),

            // Lista de ingredientes (scrollable si son muchos)
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: widget.producto.ingredientes.map((ing) {
                    final activo = _seleccion[ing.nombre] ?? true;
                    return CheckboxListTile(
                      value: activo,
                      activeColor: AppColors.button,
                      checkColor: Colors.white,
                      title: Text(
                        ing.nombre,
                        style: TextStyle(
                          color: activo
                              ? AppColors.textPrimary
                              : AppColors.textSecondary,
                          decoration:
                              activo ? null : TextDecoration.lineThrough,
                        ),
                      ),
                      onChanged: (val) {
                        setState(() => _seleccion[ing.nombre] = val ?? true);
                      },
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                    );
                  }).toList(),
                ),
              ),
            ),

            // Botón confirmar
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.button,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () {
                    final excluidos = _seleccion.entries
                        .where((e) => !e.value)
                        .map((e) => e.key)
                        .toList();
                    Navigator.pop(context, excluidos);
                  },
                  child: const Text(
                    'Añadir al carrito',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

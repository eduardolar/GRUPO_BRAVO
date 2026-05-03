import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/producto_model.dart';
import '../../core/colors_style.dart';

class ProductoDetalleSheet extends StatefulWidget {
  final Producto producto;
  final void Function(List<String> excluidos, int cantidad) onAgregar;

  const ProductoDetalleSheet({
    super.key,
    required this.producto,
    required this.onAgregar,
  });

  @override
  State<ProductoDetalleSheet> createState() => _ProductoDetalleSheetState();
}

class _ProductoDetalleSheetState extends State<ProductoDetalleSheet> {
  final Set<String> _excluidos = {};
  int _cantidad = 1;

  @override
  Widget build(BuildContext context) {
    final p = widget.producto;
    final total = p.precio * _cantidad;
    final bottom = MediaQuery.of(context).padding.bottom;

    return Container(
      decoration: const BoxDecoration(color: AppColors.background),
      padding: EdgeInsets.fromLTRB(0, 0, 0, bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 40,
                height: 3,
                margin: const EdgeInsets.symmetric(vertical: 12),
                color: AppColors.line,
              ),
            ),

            // Product image
            if (p.imagenUrl != null && p.imagenUrl!.isNotEmpty)
              SizedBox(
                height: 200,
                width: double.infinity,
                child: Image.network(
                  p.imagenUrl!,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => const SizedBox.shrink(),
                ),
              ),

            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Name + price row
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              p.nombre,
                              style: GoogleFonts.playfairDisplay(
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                                height: 1.2,
                              ),
                            ),
                            if (p.descripcion.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Text(
                                p.descripcion,
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: AppColors.textSecondary,
                                  height: 1.5,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Text(
                        '${p.precio.toStringAsFixed(2).replaceAll('.', ',')} €',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: AppColors.button,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ],
                  ),

                  // Ingredient exclusion toggles
                  if (p.ingredientes.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        border: Border.all(color: AppColors.line),
                      ),
                      child: const Text(
                        'QUITAR INGREDIENTES',
                        style: TextStyle(
                          fontSize: 9,
                          color: AppColors.textSecondary,
                          letterSpacing: 2.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: p.ingredientes.map((ing) {
                        final excluido = _excluidos.contains(ing.nombre);
                        return GestureDetector(
                          onTap: () => setState(() {
                            if (excluido) {
                              _excluidos.remove(ing.nombre);
                            } else {
                              _excluidos.add(ing.nombre);
                            }
                          }),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: excluido
                                  ? AppColors.error.withValues(alpha: 0.08)
                                  : Colors.transparent,
                              border: Border.all(
                                color: excluido
                                    ? AppColors.error
                                    : AppColors.line,
                                width: excluido ? 1.5 : 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (excluido) ...[
                                  const Icon(Icons.close,
                                      size: 11, color: AppColors.error),
                                  const SizedBox(width: 4),
                                ],
                                Text(
                                  ing.nombre,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: excluido
                                        ? AppColors.error
                                        : AppColors.textPrimary,
                                    fontWeight: excluido
                                        ? FontWeight.w600
                                        : FontWeight.w400,
                                    decoration: excluido
                                        ? TextDecoration.lineThrough
                                        : null,
                                    decorationColor: AppColors.error,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],

                  const SizedBox(height: 28),

                  // Quantity stepper + Add button
                  Row(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: AppColors.line),
                        ),
                        child: Row(
                          children: [
                            _StepBtn(
                              icon: _cantidad == 1
                                  ? Icons.delete_outline
                                  : Icons.remove,
                              onTap: () {
                                if (_cantidad > 1) {
                                  setState(() => _cantidad--);
                                } else {
                                  Navigator.pop(context);
                                }
                              },
                            ),
                            SizedBox(
                              width: 44,
                              height: 50,
                              child: Center(
                                child: Text(
                                  '$_cantidad',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ),
                            ),
                            _StepBtn(
                              icon: Icons.add,
                              onTap: () => setState(() => _cantidad++),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Material(
                          color: AppColors.button,
                          child: InkWell(
                            onTap: () {
                              Navigator.pop(context);
                              widget.onAgregar(
                                  _excluidos.toList(), _cantidad);
                            },
                            child: SizedBox(
                              height: 50,
                              child: Center(
                                child: Text(
                                  'AGREGAR · ${total.toStringAsFixed(2).replaceAll('.', ',')} €',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StepBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _StepBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 50,
        color: AppColors.panel,
        child: Icon(icon, size: 18, color: AppColors.textPrimary),
      ),
    );
  }
}

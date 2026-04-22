import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/producto_model.dart';
import '../../core/colors_style.dart';

class ProductoCard extends StatelessWidget {
  final Producto product;
  final VoidCallback onAdd;
  final VoidCallback? onRemove;
  final int quantity;

  static DateTime _lastTap = DateTime(2000);

  const ProductoCard({
    super.key,
    required this.product,
    required this.onAdd,
    this.onRemove,
    this.quantity = 0,
  });

  @override
  Widget build(BuildContext context) {
    final bool noDisp = !product.estaDisponible;

    final card = Container(
      margin: EdgeInsets.zero,
      decoration: BoxDecoration(
        color: AppColors.panel,
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Imagen ──────────────────────────────────────────────
          SizedBox(
            height: 170,
            width: double.infinity,
            child: product.imagenUrl != null && product.imagenUrl!.isNotEmpty
                ? Image.network(
                    product.imagenUrl!,
                    fit: BoxFit.cover,
                    loadingBuilder: (context, child, progress) {
                      if (progress == null) return child;
                      return Container(
                        color: AppColors.background,
                        child: Center(
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 1.5,
                              color: AppColors.button,
                            ),
                          ),
                        ),
                      );
                    },
                    errorBuilder: (context, err, stack) => const _ImagePlaceholder(),
                  )
                : const _ImagePlaceholder(),
          ),

          // Separador horizontal editorial
          Container(height: 1, color: AppColors.line),

          // ── Contenido ────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Nombre
                Text(
                  product.nombre,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.playfairDisplay(
                    color: AppColors.textPrimary,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    height: 1.25,
                  ),
                ),

                const SizedBox(height: 7),

                // Descripción
                Text(
                  product.descripcion,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    height: 1.5,
                  ),
                ),

                const SizedBox(height: 12),

                // Precio
                Text(
                  '${product.precio.toStringAsFixed(2).replaceAll('.', ',')} €',
                  style: const TextStyle(
                    color: AppColors.button,
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                  ),
                ),
              ],
            ),
          ),

          // ── Barra de controles (siempre visible) ─────────────────
          Container(
            height: 48,
            decoration: BoxDecoration(
              color: quantity > 0 && !noDisp
                  ? AppColors.button.withValues(alpha: 0.12)
                  : Colors.transparent,
              border: Border(
                top: BorderSide(color: AppColors.line),
              ),
            ),
            child: noDisp
                ? const SizedBox.shrink()
                : Row(
                    children: [
                      if (quantity > 0) ...
                        [
                          // Botón quitar
                          Expanded(
                            child: GestureDetector(
                              onTap: onRemove,
                              child: Container(
                                height: 48,
                                color: AppColors.backgroundButton,
                                child: Icon(
                                  quantity == 1
                                      ? Icons.delete_outline
                                      : Icons.remove,
                                  color: AppColors.panel,
                                  size: 20,
                                ),
                              ),
                            ),
                          ),
                          // Contador
                          Container(
                            width: 44,
                            height: 48,
                            color: AppColors.backgroundButton.withOpacity(0.8),
                            alignment: Alignment.center,
                            child: Text(
                              '$quantity',
                              style: const TextStyle(
                                color: AppColors.background,
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      // Botón añadir
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            final now = DateTime.now();
                            if (now
                                    .difference(_lastTap)
                                    .inMilliseconds <
                                300) return;
                            _lastTap = now;
                            onAdd();
                          },
                          child: Container(
                            height: 48,
                            color: AppColors.button,
                            child: const Icon(
                              Icons.add,
                              color: AppColors.background,
                              size: 22,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );

    if (noDisp) {
      return ClipRect(
        child: Banner(
          message: 'AGOTADO',
          location: BannerLocation.topEnd,
          color: AppColors.error,
          textStyle: const TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.8,
          ),
          child: Opacity(opacity: 0.65, child: card),
        ),
      );
    }

    return card;
  }
}

// ─── Placeholder de imagen ────────────────────────────────────────────────────

class _ImagePlaceholder extends StatelessWidget {
  const _ImagePlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.background,
      child: const Center(
        child: Icon(
          Icons.restaurant,
          color: AppColors.line,
          size: 36,
        ),
      ),
    );
  }
}




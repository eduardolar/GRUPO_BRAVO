import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/producto_model.dart';
import '../../core/colors_style.dart';

class ProductoCard extends StatelessWidget {
  final Producto product;
  final VoidCallback onAdd;

  static DateTime _lastTap = DateTime(2000);

  const ProductoCard({
    super.key,
    required this.product,
    required this.onAdd,
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
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
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

                const SizedBox(height: 14),

                // Precio + botón añadir
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      '${product.precio.toStringAsFixed(2).replaceAll('.', ',')} €',
                      style: const TextStyle(
                        color: AppColors.button,
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const Spacer(),
                    _AddButton(
                      disabled: noDisp,
                      onTap: noDisp
                          ? null
                          : () {
                              final now = DateTime.now();
                              if (now.difference(_lastTap).inMilliseconds <
                                  300) return;
                              _lastTap = now;
                              onAdd();
                            },
                    ),
                  ],
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

// ─── Botón Añadir ─────────────────────────────────────────────────────────────

class _AddButton extends StatelessWidget {
  final bool disabled;
  final VoidCallback? onTap;
  const _AddButton({required this.disabled, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 44,
        height: 44,
        color: disabled ? AppColors.line : AppColors.button,
        child: const Icon(Icons.add, color: Colors.white, size: 22),
      ),
    );
  }
}

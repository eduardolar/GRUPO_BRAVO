import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/colors_style.dart';
import '../../../../providers/cart_provider.dart';
import 'entrega_constantes.dart';

class ArticuloCard extends StatelessWidget {
  final CartItem item;
  final CartProvider cart;

  const ArticuloCard({super.key, required this.item, required this.cart});

  @override
  Widget build(BuildContext context) {
    final imageUrl = item.producto.imagenUrl;
    return ClipRRect(
      borderRadius: kRadiusEntrega,
      child: SizedBox(
        height: 130,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (imageUrl != null && imageUrl.isNotEmpty)
              CachedNetworkImage(
                imageUrl: imageUrl,
                fit: BoxFit.cover,
                errorWidget: (_, _, _) => _imgFallback(),
                placeholder: (_, _) => _imgFallback(),
              )
            else
              _imgFallback(),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: const [0.0, 0.35, 0.65, 1.0],
                  colors: [
                    Colors.black.withValues(alpha: 0.45),
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.55),
                    Colors.black.withValues(alpha: 0.88),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 12, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Align(
                    alignment: Alignment.topRight,
                    child: Tooltip(
                      message: 'Eliminar',
                      child: InkWell(
                        onTap: () => cart.removeProduct(item.key),
                        borderRadius: BorderRadius.circular(6),
                        child: Container(
                          width: 26,
                          height: 26,
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.40),
                            border: Border.all(color: Colors.white24),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Icon(
                            Icons.close,
                            size: 13,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    item.producto.nombre,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.playfairDisplay(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      height: 1.2,
                      shadows: const [
                        Shadow(color: Colors.black54, blurRadius: 6),
                      ],
                    ),
                  ),
                  if (item.ingredientesExcluidos.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      'Sin: ${item.ingredientesExcluidos.join(', ')}',
                      style: const TextStyle(
                        color: AppColors.excludedIngredient,
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Text(
                        '${item.producto.precio.toStringAsFixed(2).replaceAll('.', ',')} € / ud',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.60),
                          fontSize: 11,
                        ),
                      ),
                      const Spacer(),
                      StepperCard(item: item, cart: cart),
                      const SizedBox(width: 14),
                      Text(
                        '${item.subtotal.toStringAsFixed(2).replaceAll('.', ',')} €',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3,
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

  Widget _imgFallback() => Container(
        color: Colors.white.withValues(alpha: 0.10),
        child: Icon(
          Icons.restaurant,
          color: Colors.white.withValues(alpha: 0.20),
          size: 28,
        ),
      );
}

class StepperCard extends StatelessWidget {
  final CartItem item;
  final CartProvider cart;

  const StepperCard({super.key, required this.item, required this.cart});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _StepperButton(
          icon: Icons.remove,
          onTap: () => cart.removeItem(item.key),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Text(
            '${item.cantidad}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
            ),
          ),
        ),
        _StepperButton(
          icon: Icons.add,
          filled: true,
          onTap: () => cart.addItem(
            item.producto,
            ingredientesExcluidos: item.ingredientesExcluidos,
          ),
        ),
      ],
    );
  }
}

class _StepperButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool filled;

  const _StepperButton({
    required this.icon,
    required this.onTap,
    this.filled = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: filled
                ? AppColors.primaryAccent
                : Colors.black.withValues(alpha: 0.30),
            borderRadius: BorderRadius.circular(6),
            border: filled ? null : Border.all(color: Colors.white38),
          ),
          child: Icon(icon, size: filled ? 15 : 13, color: Colors.white),
        ),
      ),
    );
  }
}

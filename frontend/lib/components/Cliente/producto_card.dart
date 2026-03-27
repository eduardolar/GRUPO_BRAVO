import 'package:flutter/material.dart';
import '../../models/producto_model.dart';
import '../../core/colors_style.dart';

class ProductoCard extends StatelessWidget {
  final Producto product;
  final VoidCallback onAdd;
  static DateTime _lastTap = DateTime(2000);

  const ProductoCard({super.key, required this.product, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.panel,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // IMAGEN DEL PRODUCTO
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Container(
              width: 90,
              height: 90,
              color: AppColors.background,
              // Si tienes URL de imagen, usa Image.network. Si no, el icono.
              child: product.imagenUrl != null && product.imagenUrl!.isNotEmpty
                  ? Image.network(
                      product.imagenUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Icon(
                        Icons.restaurant,
                        color: AppColors.gold,
                        size: 40,
                      ),
                    )
                  : const Icon(
                      Icons.restaurant,
                      color: AppColors.gold,
                      size: 40,
                    ),
            ),
          ),

          const SizedBox(width: 15),

          // INFORMACIÓN DEL PRODUCTO
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  product.nombre,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  product.descripcion,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${product.precio.toStringAsFixed(2)} €',
                      style: const TextStyle(
                        color: AppColors.gold,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    // BOTÓN AGREGAR (Optimizado)
                    SizedBox(
                      width: 40,
                      height: 40,
                      child: IconButton.filled(
                        style: IconButton.styleFrom(
                          backgroundColor: AppColors.button,
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        onPressed: () {
                          final now = DateTime.now();
                          if (now.difference(_lastTap).inMilliseconds < 300)
                            return;
                          _lastTap = now;
                          onAdd();
                        },
                        icon: const Icon(Icons.add, size: 20),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

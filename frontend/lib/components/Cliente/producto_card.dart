import 'package:flutter/material.dart';
import '../../models/producto_model.dart';
import '../../core/colors_style.dart';

class ProductoCard extends StatelessWidget {
  final Producto product;
  final VoidCallback onAdd;
  final VoidCallback? onPersonalizar;
  bool iconoEditar;
  static DateTime _lastTap = DateTime(2000);

  ProductoCard({
    super.key,
    required this.product,
    required this.onAdd,
    this.onPersonalizar,
    this.iconoEditar = false
  });

  @override
  Widget build(BuildContext context) {
    final deshabilitado = !product.estaDisponible;

    return Opacity(
      opacity: deshabilitado ? 0.45 : 1.0,
      child: Container(
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
                  if (deshabilitado) ...[                    const SizedBox(height: 4),
                    const Text(
                      'No disponible',
                      style: TextStyle(
                        color: AppColors.error,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
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
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // BOTÓN PERSONALIZAR (solo si tiene ingredientes y está disponible)
                        if (product.ingredientes.isNotEmpty && onPersonalizar != null && !deshabilitado)
                          SizedBox(
                            height: 34,
                            child: TextButton.icon(
                              style: TextButton.styleFrom(
                                foregroundColor: AppColors.button,
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  side: const BorderSide(color: AppColors.button),
                                ),
                                visualDensity: VisualDensity.compact,
                              ),
                              onPressed: onPersonalizar,
                              icon: const Icon(Icons.tune, size: 16),
                              label: const Text('Personalizar', style: TextStyle(fontSize: 12)),
                            ),
                          ),
                        if (product.ingredientes.isNotEmpty && onPersonalizar != null && !deshabilitado)
                          const SizedBox(width: 8),
                        // BOTÓN AGREGAR
                        SizedBox(
                          width: 40,
                          height: 40,
                          child: IconButton.filled(
                            style: IconButton.styleFrom(
                              backgroundColor: deshabilitado ? Colors.grey : AppColors.button,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            onPressed: deshabilitado ? null : () {
                              final now = DateTime.now();
                              if (now.difference(_lastTap).inMilliseconds < 300)
                                return;
                              _lastTap = now;
                              onAdd();
                            },
                            icon: IconoBoton(),
                          ),
                        ),
                      ],
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

  Icon IconoBoton(){
    if(iconoEditar){
      return Icon(Icons.edit);
    } else{
      return Icon(Icons.add);
    }
  }

}

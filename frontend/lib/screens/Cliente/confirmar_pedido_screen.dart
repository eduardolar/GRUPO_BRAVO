import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/colors_style.dart';
import '../../providers/cart_provider.dart';
import 'delivery_options_screen.dart';

// ─── Paleta 60-30-10 ───────────────────────────────────────────────
// 60% → negro cálido profundo:  AppColors.background
// 30% → marrón oscuro cálido:   AppColors.backgroundButton
// 10% → dorado:                 AppColors.gold
// ───────────────────────────────────────────────────────────────────

class ConfirmarPedidoScreen extends StatelessWidget {
  const ConfirmarPedidoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // 60% — fondo dominante, negro cálido
      backgroundColor: AppColors.background,
      appBar: _buildAppBar(context),
      body: Consumer<CartProvider>(
        builder: (context, cart, child) {
          if (cart.itemCount == 0) {
            return _buildCarritoVacio();
          }
          return _buildContenido(context, cart);
        },
      ),
    );
  }

  // ── AppBar ────────────────────────────────────────────────────────
  AppBar _buildAppBar(BuildContext context) {
    return AppBar(
      // 30% — superficie cálida
      backgroundColor: AppColors.backgroundButton,
      elevation: 0,
      iconTheme: const IconThemeData(color: Colors.white), // blanco sobre rojo
      title: const Text(
        'CONFIRMAR PEDIDO',
        style: TextStyle(
          fontFamily: 'Playfair Display',
          color: Colors.white, // blanco cálido
          fontSize: 18,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
        ),
      ),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(
          height: 1,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.transparent,
                Colors.white, // acento claro
                Colors.transparent,
              ],
            ),
          ),
        ),
      ),
      actions: [
        Consumer<CartProvider>(
          builder: (context, cart, child) {
            if (cart.itemCount > 0) {
              return TextButton(
                onPressed: () {
                  cart.clearCart();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      backgroundColor: AppColors.backgroundButton, // 30%
                      content: Row(
                        children: [
                          Icon(
                            Icons.delete_outline,
                            color: Colors.white,
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'Carrito vaciado',
                            style: TextStyle(color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                  );
                },
                child: Text(
                  'Vaciar',
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                ),
              );
            }
            return const SizedBox.shrink();
          },
        ),
      ],
    );
  }

  // ── Estado carrito vacío ──────────────────────────────────────────
  Widget _buildCarritoVacio() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white30, width: 1.5),
              color: AppColors.backgroundButton, // 30%
            ),
            child: const Icon(
              Icons.shopping_cart_outlined,
              size: 36,
              color: Colors.white, // acento claro
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Tu carrito está vacío',
            style: TextStyle(
              fontFamily: 'Playfair Display',
              color: AppColors.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Agrega algunos productos del menú',
            style: TextStyle(
              color: Color(0xFF6B6B6B), // gris dorado apagado
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  // ── Contenido principal ───────────────────────────────────────────
  Widget _buildContenido(BuildContext context, CartProvider cart) {
    return Column(
      children: [
        // Lista de productos
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            itemCount: cart.items.length,
            itemBuilder: (context, index) {
              final item = cart.items.values.elementAt(index);
              return _buildProductoCard(cart, item);
            },
          ),
        ),
        // Panel resumen — 30%
        _buildResumen(context, cart),
      ],
    );
  }

  // ── Tarjeta de producto — superficie 30% ──────────────────────────
  Widget _buildProductoCard(CartProvider cart, dynamic item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.backgroundButton, // 30% — superficie cálida
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE0DBD3)),
      ),
      child: Row(
        children: [
          // Imagen placeholder — icono dorado 10%
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: const Color(0xFF660019), // 30% más oscuro
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFA6405A)),
            ),
            child: const Icon(Icons.fastfood, color: Colors.white, size: 26),
          ),

          const SizedBox(width: 14),

          // Info producto
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.producto.nombre,
                  style: const TextStyle(
                    color: Colors.white, // blanco cálido
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  item.producto.descripcion,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                    fontWeight: FontWeight.w300,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (item.ingredientesExcluidos.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    'Sin: ${item.ingredientesExcluidos.join(', ')}',
                    style: const TextStyle(
                      color: Colors.orangeAccent,
                      fontSize: 11,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
                const SizedBox(height: 6),
                Text(
                  '${item.producto.precio.toStringAsFixed(2)} €',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),

          // Controles cantidad
          Column(
            children: [
              Row(
                children: [
                  _cantidadBtn(
                    icon: Icons.remove,
                    onTap: () => cart.removeItem(item.producto.id),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.background, // 60%
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '${item.cantidad}',
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  _cantidadBtn(
                    icon: Icons.add,
                    onTap: () => cart.addItem(item.producto),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                '${item.subtotal.toStringAsFixed(2)} €',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Botón +/- cantidad ────────────────────────────────────────────
  Widget _cantidadBtn({required IconData icon, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 28,
        height: 28,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          color: const Color(0xFF660019), // 30% más oscuro
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Colors.white30),
        ),
        child: Icon(icon, color: Colors.white, size: 16),
      ),
    );
  }

  // ── Panel resumen inferior — superficie 30% ───────────────────────
  Widget _buildResumen(BuildContext context, CartProvider cart) {
    final envio = cart.totalPrice > 25 ? 0.0 : 3.99;
    final total = cart.totalPrice + envio;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
      decoration: BoxDecoration(
        color: AppColors.backgroundButton, // 30% — superficie cálida
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
        border: const Border(top: BorderSide(color: Color(0xFFE0DBD3))),
      ),
      child: Column(
        children: [
          // Línea dorada decorativa — 10%
          Container(
            width: 40,
            height: 2,
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: Colors.white38,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          _filaResumen(
            label: 'Subtotal',
            valor: '${cart.totalPrice.toStringAsFixed(2)} €',
          ),
          const SizedBox(height: 8),
          _filaResumen(
            label: 'Envío',
            valor: cart.totalPrice > 25 ? 'Gratis' : '3,99 €',
            valorDorado: cart.totalPrice > 25, // "Gratis" en dorado
          ),

          const SizedBox(height: 12),

          // Separador dorado — 10%
          Container(
            height: 1,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.transparent, Colors.white, Colors.transparent],
              ),
            ),
          ),

          const SizedBox(height: 12),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Total',
                style: TextStyle(
                  fontFamily: 'Playfair Display',
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                '${total.toStringAsFixed(2)} €',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Botón realizar pedido — acento 10%
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const PantallaOpcionesEntrega(),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.backgroundButton, // 30%
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(13),
                  side: const BorderSide(color: Colors.white, width: 1.5),
                ),
                elevation: 0,
              ),
              child: const Text(
                'REALIZAR PEDIDO',
                style: TextStyle(
                  fontFamily: 'Playfair Display',
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 2,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Fila de resumen (subtotal / envío) ────────────────────────────
  Widget _filaResumen({
    required String label,
    required String valor,
    bool valorDorado = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.7),
            fontSize: 14,
          ),
        ),
        Text(
          valor,
          style: TextStyle(
            color: valorDorado ? Colors.white : Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

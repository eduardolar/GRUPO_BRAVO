import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/colors_style.dart';
import '../../providers/cart_provider.dart';
import 'delivery_options_screen.dart';

class ConfirmarPedidoScreen extends StatelessWidget {
  const ConfirmarPedidoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: _buildAppBar(context),
      body: Consumer<CartProvider>(
        builder: (context, cart, _) {
          if (cart.itemCount == 0) return _buildCarritoVacio();
          return _buildContenido(context, cart);
        },
      ),
    );
  }

  // ── AppBar ──────────────────────────────────────────────────────────
  AppBar _buildAppBar(BuildContext context) {
    return AppBar(
      backgroundColor: AppColors.background,
      elevation: 0,
      scrolledUnderElevation: 0,
      iconTheme: const IconThemeData(color: AppColors.textPrimary),
      title: Text(
        'TU PEDIDO',
        style: GoogleFonts.playfairDisplay(
          color: AppColors.textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.5,
        ),
      ),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(height: 1, color: AppColors.line),
      ),
      actions: [
        Consumer<CartProvider>(
          builder: (context, cart, _) {
            if (cart.itemCount == 0) return const SizedBox.shrink();
            return TextButton(
              onPressed: () {
                cart.clearCart();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    backgroundColor: AppColors.button,
                    behavior: SnackBarBehavior.floating,
                    shape: const RoundedRectangleBorder(),
                    margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    content: const Text(
                      'CARRITO VACIADO',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        letterSpacing: 1.2,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                );
              },
              child: Text(
                'VACIAR',
                style: TextStyle(
                  color: AppColors.button,
                  fontSize: 11,
                  letterSpacing: 1.0,
                  fontWeight: FontWeight.w600,
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  // ── Carrito vacío ───────────────────────────────────────────────────
  Widget _buildCarritoVacio() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.line, width: 1),
              color: AppColors.panel,
            ),
            child: const Icon(
              Icons.shopping_bag_outlined,
              size: 32,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'SIN PRODUCTOS',
            style: GoogleFonts.playfairDisplay(
              color: AppColors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Agrega productos desde la carta',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  // ── Contenido principal ─────────────────────────────────────────────
  Widget _buildContenido(BuildContext context, CartProvider cart) {
    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
            itemCount: cart.items.length,
            itemBuilder: (context, index) {
              final CartItem item = cart.items.values.elementAt(index);
              return _ProductoRow(item: item, cart: cart);
            },
          ),
        ),
        _ResumenPanel(cart: cart),
      ],
    );
  }
}

// ── Tarjeta de producto ─────────────────────────────────────────────────────

class _ProductoRow extends StatelessWidget {
  final CartItem item;
  final CartProvider cart;

  const _ProductoRow({required this.item, required this.cart});

  @override
  Widget build(BuildContext context) {
    final imageUrl = item.producto.imagenUrl;
    final subtotal = item.subtotal;

    return Container(
      height: 160,
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.hardEdge,
      decoration: const BoxDecoration(),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // ── Imagen de fondo ──────────────────────────────────────────
          imageUrl != null && imageUrl.isNotEmpty
              ? Image.network(
                  imageUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) =>
                      const _ImgPlaceholder(),
                )
              : const _ImgPlaceholder(),

          // ── Degradado: oscuro arriba (botón ×) + fuerte abajo (texto) ─
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

          // ── Contenido ────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 12, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Botón eliminar (esquina superior derecha)
                Align(
                  alignment: Alignment.topRight,
                  child: GestureDetector(
                    onTap: () => cart.removeProduct(item.key),
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.40),
                        border: Border.all(color: Colors.white24),
                      ),
                      child: const Icon(
                        Icons.close,
                        size: 14,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),

                const Spacer(),

                // Nombre
                Text(
                  item.producto.nombre,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.playfairDisplay(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    height: 1.2,
                    shadows: const [
                      Shadow(color: Colors.black54, blurRadius: 6),
                    ],
                  ),
                ),

                const SizedBox(height: 3),

                // Descripción
                Text(
                  item.producto.descripcion,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.70),
                    fontSize: 11,
                  ),
                ),

                if (item.ingredientesExcluidos.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    'Sin: ${item.ingredientesExcluidos.join(', ')}',
                    style: const TextStyle(
                      color: Color(0xFFFFB3B3),
                      fontSize: 10,
                      fontStyle: FontStyle.italic,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],

                const SizedBox(height: 10),

                // Fila inferior: precio unitario · stepper · subtotal
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      '${item.producto.precio.toStringAsFixed(2).replaceAll('.', ',')} € / ud',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.60),
                        fontSize: 11,
                      ),
                    ),
                    const Spacer(),
                    _Stepper(item: item, cart: cart),
                    const SizedBox(width: 14),
                    Text(
                      '${subtotal.toStringAsFixed(2).replaceAll('.', ',')} €',
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
    );
  }
}

// ── Stepper de cantidad ──────────────────────────────────────────────────────

class _Stepper extends StatelessWidget {
  final CartItem item;
  final CartProvider cart;
  const _Stepper({required this.item, required this.cart});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Botón − : contorno blanco semitransparente
        GestureDetector(
          onTap: () => cart.removeItem(item.producto.id),
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.30),
              border: Border.all(color: Colors.white38),
            ),
            child: const Icon(Icons.remove, size: 15, color: Colors.white),
          ),
        ),

        // Contador : sin caja, flota sobre la imagen
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Text(
            '${item.cantidad}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
            ),
          ),
        ),

        // Botón + : burdeos sólido — mismo lenguaje que el menú
        GestureDetector(
          onTap: () => cart.addItem(item.producto),
          child: Container(
            width: 36,
            height: 36,
            color: AppColors.button,
            child: const Icon(Icons.add, size: 18, color: Colors.white),
          ),
        ),
      ],
    );
  }
}

// ── Panel resumen inferior ───────────────────────────────────────────────────

class _ResumenPanel extends StatelessWidget {
  final CartProvider cart;
  const _ResumenPanel({required this.cart});

  @override
  Widget build(BuildContext context) {
    final envio = cart.totalPrice > 25 ? 0.0 : 3.99;
    final total = cart.totalPrice + envio;

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.panel,
        border: Border(top: BorderSide(color: AppColors.line)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      child: Column(
        children: [
          _Fila(
            label: 'Subtotal',
            valor: '${cart.totalPrice.toStringAsFixed(2).replaceAll('.', ',')} €',
          ),
          const SizedBox(height: 8),
          _Fila(
            label: 'Envío',
            valor: cart.totalPrice > 25 ? 'Gratis' : '3,99 €',
            acento: cart.totalPrice > 25,
          ),

          Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Container(height: 1, color: AppColors.line),
          ),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'TOTAL',
                style: GoogleFonts.playfairDisplay(
                  color: AppColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.0,
                ),
              ),
              Text(
                '${total.toStringAsFixed(2).replaceAll('.', ',')} €',
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),

          const SizedBox(height: 18),

          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const PantallaOpcionesEntrega(),
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.button,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: const RoundedRectangleBorder(),
              ),
              child: Text(
                'REALIZAR PEDIDO',
                style: GoogleFonts.playfairDisplay(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 2.0,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Fila extends StatelessWidget {
  final String label;
  final String valor;
  final bool acento;
  const _Fila({required this.label, required this.valor, this.acento = false});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 13,
          ),
        ),
        Text(
          valor,
          style: TextStyle(
            color: acento ? AppColors.button : AppColors.textPrimary,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

// ── Placeholder imagen ───────────────────────────────────────────────────────

class _ImgPlaceholder extends StatelessWidget {
  const _ImgPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.line,
      child: const Icon(Icons.restaurant, color: AppColors.panel, size: 28),
    );
  }
}

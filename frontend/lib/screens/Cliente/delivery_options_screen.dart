import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/colors_style.dart';
import '../../providers/cart_provider.dart';

enum DeliveryOption { delivery, pickup }
enum PaymentMethod { cash, card }

class DeliveryOptionsScreen extends StatefulWidget {
  const DeliveryOptionsScreen({super.key});

  @override
  State<DeliveryOptionsScreen> createState() => _DeliveryOptionsScreenState();
}

class _DeliveryOptionsScreenState extends State<DeliveryOptionsScreen> {
  DeliveryOption _selectedDelivery = DeliveryOption.delivery;
  PaymentMethod _selectedPayment = PaymentMethod.cash;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.iconPrimary),
        title: const Text(
          'OPCIONES DE ENTREGA',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '¿Cómo quieres recibir tu pedido?',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),

            // Opción de entrega a domicilio
            _buildDeliveryOption(
              title: 'Entrega a domicilio',
              subtitle: 'Recibe tu pedido en la puerta de tu casa',
              icon: Icons.delivery_dining,
              value: DeliveryOption.delivery,
              cost: '3,99 €',
            ),
            const SizedBox(height: 16),

            // Opción de recoger en restaurante
            _buildDeliveryOption(
              title: 'Recoger en restaurante',
              subtitle: 'Ven a recoger tu pedido cuando esté listo',
              icon: Icons.store,
              value: DeliveryOption.pickup,
              cost: 'Gratis',
            ),

            const SizedBox(height: 40),
            const Divider(color: AppColors.line),
            const SizedBox(height: 20),

            const Text(
              'Método de pago',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),

            // Método de pago en efectivo
            _buildPaymentOption(
              title: 'Efectivo',
              subtitle: 'Paga al recibir tu pedido',
              icon: Icons.payments,
              value: PaymentMethod.cash,
            ),
            const SizedBox(height: 16),

            // Método de pago con tarjeta
            _buildPaymentOption(
              title: 'Tarjeta',
              subtitle: 'Pago seguro con tarjeta de crédito/débito',
              icon: Icons.credit_card,
              value: PaymentMethod.card,
            ),

            const SizedBox(height: 40),

            // Resumen del pedido
            Consumer<CartProvider>(
              builder: (context, cart, child) {
                final deliveryCost = _selectedDelivery == DeliveryOption.delivery ? 3.99 : 0.0;
                final total = cart.totalPrice + deliveryCost;

                return Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.panel,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.line),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Subtotal productos:',
                            style: TextStyle(color: AppColors.textSecondary),
                          ),
                          Text(
                            '${cart.totalPrice.toStringAsFixed(2)} €',
                            style: const TextStyle(color: AppColors.textPrimary),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _selectedDelivery == DeliveryOption.delivery
                                ? 'Entrega a domicilio:'
                                : 'Recoger en restaurante:',
                            style: const TextStyle(color: AppColors.textSecondary),
                          ),
                          Text(
                            deliveryCost == 0 ? 'Gratis' : '${deliveryCost.toStringAsFixed(2)} €',
                            style: const TextStyle(color: AppColors.textPrimary),
                          ),
                        ],
                      ),
                      const Divider(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Total a pagar:',
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            '${total.toStringAsFixed(2)} €',
                            style: const TextStyle(
                              color: AppColors.button,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),

            const SizedBox(height: 30),

            // Botón de confirmar pedido final
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _confirmOrder,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.button,
                  foregroundColor: AppColors.background,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'CONFIRMAR PEDIDO',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeliveryOption({
    required String title,
    required String subtitle,
    required IconData icon,
    required DeliveryOption value,
    required String cost,
  }) {
    final isSelected = _selectedDelivery == value;

    return GestureDetector(
      onTap: () => setState(() => _selectedDelivery = value),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.panel : AppColors.background,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.button : AppColors.line,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.button.withOpacity(0.1) : AppColors.line.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                color: isSelected ? AppColors.button : AppColors.iconPrimary,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.button : AppColors.line.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                cost,
                style: TextStyle(
                  color: isSelected ? AppColors.background : AppColors.textPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
              color: isSelected ? AppColors.button : AppColors.line,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentOption({
    required String title,
    required String subtitle,
    required IconData icon,
    required PaymentMethod value,
  }) {
    final isSelected = _selectedPayment == value;

    return GestureDetector(
      onTap: () => setState(() => _selectedPayment = value),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.panel : AppColors.background,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.button : AppColors.line,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.button.withOpacity(0.1) : AppColors.line.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                color: isSelected ? AppColors.button : AppColors.iconPrimary,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
              color: isSelected ? AppColors.button : AppColors.line,
            ),
          ],
        ),
      ),
    );
  }

  void _confirmOrder() {
    // Aquí iría la lógica para procesar el pedido
    // Por ahora solo mostramos un mensaje de éxito
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '¡Pedido confirmado! ${_selectedDelivery == DeliveryOption.delivery ? "Entrega a domicilio" : "Recoger en restaurante"} - Pago: ${_selectedPayment == PaymentMethod.cash ? "Efectivo" : "Tarjeta"}',
        ),
        backgroundColor: AppColors.button,
        duration: const Duration(seconds: 3),
      ),
    );

    // Limpiar el carrito y volver al inicio
    final cart = Provider.of<CartProvider>(context, listen: false);
    cart.clearCart();

    // Navegar de vuelta al home después de un delay
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    });
  }
}
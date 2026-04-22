import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/colors_style.dart';
import '../../models/opciones_pedido.dart';
import '../../providers/cart_provider.dart';

class ResumenPedido extends StatelessWidget {
  final OpcionEntrega opcionEntrega;

  const ResumenPedido({super.key, required this.opcionEntrega});

  @override
  Widget build(BuildContext context) {
    return Consumer<CartProvider>(
      builder: (context, carrito, child) {
        final costeEnvio = opcionEntrega == OpcionEntrega.domicilio
            ? 3.99
            : 0.0;
        final total = carrito.totalPrice + costeEnvio;

        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.panel,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.line),
          ),
          child: Column(
            children: [
              _filaResumen(
                etiqueta: 'Subtotal productos:',
                valor: '${carrito.totalPrice.toStringAsFixed(2)} €',
              ),
              const SizedBox(height: 8),
              _filaResumen(
                etiqueta: switch (opcionEntrega) {
                  OpcionEntrega.domicilio => 'Entrega a domicilio:',
                  OpcionEntrega.recoger => 'Recoger en restaurante:',
                  OpcionEntrega.enMesa => 'Comer en el local:',
                },
                valor: costeEnvio == 0
                    ? 'Gratis'
                    : '${costeEnvio.toStringAsFixed(2)} €',
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
    );
  }

  Widget _filaResumen({required String etiqueta, required String valor}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(etiqueta, style: const TextStyle(color: AppColors.textSecondary)),
        Text(valor, style: const TextStyle(color: AppColors.textPrimary)),
      ],
    );
  }
}

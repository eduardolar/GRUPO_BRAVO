import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/colors_style.dart';
import '../../../../providers/cart_provider.dart';
import 'entrega_constantes.dart';
import 'step_indicator.dart';

class BottomBarEntrega extends StatelessWidget {
  final EntregaPaso paso;
  final bool cargando;
  final double costeEnvio;
  /// Descuento total ya aplicado (cupón + Bravo Coins). Se resta del total
  /// que se muestra para que el cliente vea SIEMPRE lo que va a pagar.
  final double descuento;
  final VoidCallback onSiguiente;
  final VoidCallback? onAtras;

  const BottomBarEntrega({
    super.key,
    required this.paso,
    required this.cargando,
    required this.costeEnvio,
    this.descuento = 0.0,
    required this.onSiguiente,
    this.onAtras,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<CartProvider>(
      builder: (context, cart, _) {
        final envio = paso == EntregaPaso.confirmar ? 0.0 : costeEnvio;
        final bruto = cart.totalPrice + envio;
        final total = (bruto - descuento) < 0 ? 0.0 : (bruto - descuento);
        final bottom = MediaQuery.of(context).padding.bottom;

        return Container(
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.80),
            border: Border(
              top: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
            ),
          ),
          padding: EdgeInsets.fromLTRB(20, 16, 20, bottom + 16),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'TOTAL',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.50),
                        fontSize: 11,
                        letterSpacing: 2.0,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        if (descuento > 0) ...[
                          Text(
                            '${bruto.toStringAsFixed(2).replaceAll('.', ',')} €',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.40),
                              fontSize: 13,
                              decoration: TextDecoration.lineThrough,
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                        Text(
                          '${total.toStringAsFixed(2).replaceAll('.', ',')} €',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ],
                    ),
                    if (descuento > 0)
                      Text(
                        'Ahorro -${descuento.toStringAsFixed(2).replaceAll('.', ',')} €',
                        style: const TextStyle(
                          color: Colors.greenAccent,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    if (envio > 0)
                      Text(
                        'incl. ${envio.toStringAsFixed(2).replaceAll('.', ',')} € envío',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.40),
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              if (onAtras != null) ...[
                Tooltip(
                  message: 'Volver',
                  child: InkWell(
                    onTap: onAtras,
                    borderRadius: kRadiusEntrega,
                    child: Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        borderRadius: kRadiusEntrega,
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.20),
                        ),
                      ),
                      child: Icon(
                        Icons.arrow_back,
                        color: Colors.white.withValues(alpha: 0.70),
                        size: 20,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: ElevatedButton(
                  onPressed: cargando ? null : onSiguiente,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.button,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor:
                        AppColors.button.withValues(alpha: 0.5),
                    minimumSize: const Size.fromHeight(50),
                    shape: const RoundedRectangleBorder(
                      borderRadius: kRadiusEntrega,
                    ),
                    elevation: 0,
                  ),
                  child: cargando
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : Text(
                          paso != EntregaPaso.pago
                              ? 'CONTINUAR'
                              : 'CONFIRMAR PEDIDO',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.8,
                          ),
                        ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

import 'package:flutter/material.dart';
import '../../../../core/colors_style.dart';
import 'entrega_constantes.dart';

// ── Google Pay button ─────────────────────────────────────────────────────────
// Nota: colores propios (negro/blanco) exigidos por las Google Pay brand guidelines.

class GooglePayButton extends StatelessWidget {
  final bool estaCargando;
  final bool googlePayProcesando;
  final bool googlePayAutorizado;
  final VoidCallback onAutorizar;

  const GooglePayButton({
    super.key,
    required this.estaCargando,
    required this.googlePayProcesando,
    required this.googlePayAutorizado,
    required this.onAutorizar,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: const [
              BoxShadow(
                color: Color(0x33000000),
                blurRadius: 18,
                offset: Offset(0, 10),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: (estaCargando || googlePayProcesando) ? null : onAutorizar,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 16,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          alignment: Alignment.center,
                          child: const Text(
                            'G',
                            style: TextStyle(
                              color: Colors.black,
                              fontSize: 24,
                              fontWeight: FontWeight.w700,
                              height: 1,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Google Pay',
                                style: TextStyle(
                                  color: Colors.black,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Paga al instante con tu tarjeta guardada',
                                style: TextStyle(
                                  color: AppColors.googlePayGrey,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          googlePayAutorizado
                              ? Icons.verified_rounded
                              : Icons.chevron_right_rounded,
                          color: googlePayAutorizado
                              ? AppColors.googlePayGreen
                              : Colors.black54,
                          size: 22,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    AnimatedContainer(
                      duration: kAnimFast,
                      width: double.infinity,
                      height: 54,
                      decoration: BoxDecoration(
                        color: Colors.black,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Center(
                        child: googlePayProcesando
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2.2,
                                ),
                              )
                            : const LogoGooglePayButton(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Icon(
                          googlePayAutorizado
                              ? Icons.lock_clock_outlined
                              : Icons.lock_outline_rounded,
                          size: 16,
                          color: googlePayAutorizado
                              ? AppColors.googlePayGreen
                              : AppColors.googlePayGrey,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            googlePayAutorizado
                                ? 'Método autorizado. Pulsa CONFIRMAR PEDIDO para abrir la hoja de pago segura.'
                                : 'Tus datos se tokenizan y se procesan en una hoja segura de Google Pay.',
                            style: const TextStyle(
                              color: AppColors.googlePayGrey,
                              fontSize: 11.5,
                              height: 1.35,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.08),
            borderRadius: kRadiusEntrega,
            border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                googlePayAutorizado
                    ? Icons.check_circle
                    : Icons.info_outline_rounded,
                color: googlePayAutorizado ? AppColors.successVibrant : Colors.white70,
                size: 18,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  googlePayAutorizado
                      ? 'Google Pay listo. Verás tu tarjeta predeterminada y podrás validar con huella, PIN o desbloqueo del dispositivo.'
                      : 'Experiencia de cartera digital: tarjeta guardada, autenticación del dispositivo y confirmación rápida.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.82),
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── PayPal button ─────────────────────────────────────────────────────────────
// Nota: colores corporativos exigidos por las PayPal brand guidelines.

class PaypalButton extends StatelessWidget {
  final bool estaCargando;
  final bool paypalAutorizado;
  final VoidCallback onAutorizar;

  const PaypalButton({
    super.key,
    required this.estaCargando,
    required this.paypalAutorizado,
    required this.onAutorizar,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.paypal,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 15),
              shape: const RoundedRectangleBorder(
                borderRadius: kRadiusEntrega,
              ),
              elevation: 0,
            ),
            onPressed: estaCargando ? null : onAutorizar,
            icon: const Icon(Icons.account_balance_wallet_outlined),
            label: const Text(
              'PAGAR CON PAYPAL',
              style: TextStyle(fontWeight: FontWeight.w700, letterSpacing: 1),
            ),
          ),
        ),
        if (paypalAutorizado)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Row(
              children: [
                Icon(Icons.check_circle, color: AppColors.successVibrant, size: 18),
                SizedBox(width: 8),
                Flexible(
                  child: Text(
                    'Orden creada. Completa el pago en PayPal y luego confirma el pedido.',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

// ── Apple Pay button ──────────────────────────────────────────────────────────
// Nota: negro/blanco es el único esquema permitido por las Apple Pay brand guidelines.

class ApplePayButton extends StatelessWidget {
  final bool estaCargando;
  final bool applePayAutorizado;
  final VoidCallback onAutorizar;

  const ApplePayButton({
    super.key,
    required this.estaCargando,
    required this.applePayAutorizado,
    required this.onAutorizar,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(vertical: 15),
              shape: const RoundedRectangleBorder(
                borderRadius: kRadiusEntrega,
              ),
              elevation: 0,
            ),
            onPressed: estaCargando ? null : onAutorizar,
            icon: const Icon(Icons.apple),
            label: const Text(
              'AUTORIZAR APPLE PAY',
              style: TextStyle(fontWeight: FontWeight.w700, letterSpacing: 1),
            ),
          ),
        ),
        if (applePayAutorizado)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Row(
              children: [
                Icon(Icons.check_circle, color: AppColors.successVibrant, size: 18),
                SizedBox(width: 8),
                Text(
                  'Apple Pay autorizado',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

// ── Logo Google Pay (texto con colores del logo) ──────────────────────────────

class LogoGooglePayButton extends StatelessWidget {
  const LogoGooglePayButton({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'Buy with',
          style: TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(width: 8),
        RichText(
          text: const TextSpan(
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
            children: [
              TextSpan(
                text: 'G',
                style: TextStyle(color: AppColors.googleBlue),
              ),
              TextSpan(
                text: 'o',
                style: TextStyle(color: AppColors.googleRed),
              ),
              TextSpan(
                text: 'o',
                style: TextStyle(color: AppColors.googleYellow),
              ),
              TextSpan(
                text: 'g',
                style: TextStyle(color: AppColors.googleBlue),
              ),
              TextSpan(
                text: 'l',
                style: TextStyle(color: AppColors.googleGreen),
              ),
              TextSpan(
                text: 'e',
                style: TextStyle(color: AppColors.googleRed),
              ),
              TextSpan(
                text: ' Pay',
                style: TextStyle(color: Colors.white),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

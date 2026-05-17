import 'package:flutter/material.dart';
import '../../../../core/colors_style.dart';
import '../../../../services/api_service.dart';
import 'entrega_constantes.dart';

class StripeCheckoutDialog extends StatefulWidget {
  final String sessionId;
  const StripeCheckoutDialog({super.key, required this.sessionId});

  @override
  State<StripeCheckoutDialog> createState() => _StripeCheckoutDialogState();
}

class _StripeCheckoutDialogState extends State<StripeCheckoutDialog> {
  bool _verificando = false;
  String? _error;

  Future<void> _verificar() async {
    setState(() {
      _verificando = true;
      _error = null;
    });
    try {
      final pagado = await ApiService.verificarCheckoutSession(
        sessionId: widget.sessionId,
      );
      if (!mounted) return;
      if (pagado) {
        Navigator.of(context).pop(true);
      } else {
        setState(() {
          _verificando = false;
          _error =
              'El pago aún no se ha completado. Termínalo en la pestaña de Stripe y vuelve a intentarlo.';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _verificando = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.panel,
      shape: const RoundedRectangleBorder(borderRadius: kRadiusEntrega),
      title: const Row(
        children: [
          Icon(Icons.open_in_new, color: AppColors.primary, size: 20),
          SizedBox(width: 10),
          Text(
            'Completa el pago',
            style: TextStyle(color: AppColors.textPrimary, fontSize: 16),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Se ha abierto la página de pago de Stripe en una nueva pestaña. Completa el pago y pulsa el botón de abajo.',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(
              _error!,
              style: const TextStyle(color: AppColors.error, fontSize: 12),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed:
              _verificando ? null : () => Navigator.of(context).pop(false),
          child: const Text(
            'Cancelar',
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            shape: const RoundedRectangleBorder(
              borderRadius: kRadiusEntrega,
            ),
          ),
          onPressed: _verificando ? null : _verificar,
          child: _verificando
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
              : const Text('Ya he pagado'),
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/colors_style.dart';

class PedidoConfirmadoScreen extends StatefulWidget {
  final String tipoEntrega;
  final String tipoPago;
  final double total;

  const PedidoConfirmadoScreen({
    super.key,
    required this.tipoEntrega,
    required this.tipoPago,
    required this.total,
  });

  @override
  State<PedidoConfirmadoScreen> createState() =>
      _PedidoConfirmadoScreenState();
}

class _PedidoConfirmadoScreenState extends State<PedidoConfirmadoScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scaleAnim;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _scaleAnim = CurvedAnimation(parent: _ctrl, curve: Curves.elasticOut);
    _fadeAnim = CurvedAnimation(parent: _ctrl, curve: Curves.easeIn);
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  String get _tiempoEstimado {
    if (widget.tipoEntrega.contains('mesa') ||
        widget.tipoEntrega.contains('local')) {
      return '10 – 15 min';
    }
    if (widget.tipoEntrega.contains('domicilio')) { return '35 – 45 min'; }
    return '20 – 25 min';
  }

  IconData get _iconoEntrega {
    if (widget.tipoEntrega.contains('local')) return Icons.restaurant;
    if (widget.tipoEntrega.contains('domicilio')) return Icons.delivery_dining;
    return Icons.store_outlined;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            // ── Fondo ──────────────────────────────────────────────────────
            Positioned.fill(
              child: Image.asset(
                'assets/images/Bravo restaurante.jpg',
                fit: BoxFit.cover,
              ),
            ),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.78),
                      Colors.black.withValues(alpha: 0.90),
                    ],
                  ),
                ),
              ),
            ),

            // ── Contenido ──────────────────────────────────────────────────
            SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final maxW = constraints.maxWidth.clamp(0.0, 520.0);
                  final hPad = (constraints.maxWidth - maxW) / 2 + 24.0;

                  return FadeTransition(
                    opacity: _fadeAnim,
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: EdgeInsets.fromLTRB(
                          hPad, 48, hPad, 32),
                      child: Column(
                        children: [
                          // ── Check animado ─────────────────────────────
                          ScaleTransition(
                            scale: _scaleAnim,
                            child: Container(
                              width: 88,
                              height: 88,
                              decoration: BoxDecoration(
                                color: AppColors.button
                                    .withValues(alpha: 0.15),
                                border: Border.all(
                                    color: AppColors.button, width: 1.5),
                              ),
                              child: const Icon(
                                Icons.check,
                                color: AppColors.button,
                                size: 44,
                              ),
                            ),
                          ),

                          const SizedBox(height: 28),

                          // ── Título ────────────────────────────────────
                          Text(
                            'PEDIDO CONFIRMADO',
                            style: GoogleFonts.playfairDisplay(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.5,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'Tu pedido se ha procesado con éxito.\nEstamos preparándolo.',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.55),
                              fontSize: 13,
                              height: 1.6,
                            ),
                            textAlign: TextAlign.center,
                          ),

                          const SizedBox(height: 40),

                          // ── Tiempo estimado ───────────────────────────
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                                vertical: 14, horizontal: 18),
                            decoration: BoxDecoration(
                              color: AppColors.button
                                  .withValues(alpha: 0.12),
                              border: Border.all(
                                  color: AppColors.button
                                      .withValues(alpha: 0.50)),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.access_time,
                                    color: AppColors.button, size: 18),
                                const SizedBox(width: 10),
                                Text(
                                  'Tiempo estimado: $_tiempoEstimado',
                                  style: const TextStyle(
                                    color: AppColors.button,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 20),

                          // ── Panel de detalles ─────────────────────────
                          Container(
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.06),
                              border: Border.all(
                                  color:
                                      Colors.white.withValues(alpha: 0.12)),
                            ),
                            child: Column(
                              children: [
                                _FilaDetalle(
                                  icono: _iconoEntrega,
                                  etiqueta: 'ENTREGA',
                                  valor: widget.tipoEntrega,
                                ),
                                Container(
                                    height: 1,
                                    color:
                                        Colors.white.withValues(alpha: 0.08)),
                                _FilaDetalle(
                                  icono: Icons.credit_card_outlined,
                                  etiqueta: 'PAGO',
                                  valor: widget.tipoPago,
                                ),
                                Container(
                                    height: 1,
                                    color:
                                        Colors.white.withValues(alpha: 0.08)),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 18, vertical: 16),
                                  child: Row(
                                    children: [
                                      Text(
                                        'TOTAL',
                                        style: TextStyle(
                                          color: Colors.white
                                              .withValues(alpha: 0.45),
                                          fontSize: 10,
                                          letterSpacing: 2.0,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const Spacer(),
                                      Text(
                                        '${widget.total.toStringAsFixed(2).replaceAll('.', ',')} €',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 20,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: -0.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 48),

                          // ── CTA ───────────────────────────────────────
                          SizedBox(
                            width: double.infinity,
                            height: 52,
                            child: GestureDetector(
                              onTap: () => Navigator.of(context)
                                  .popUntil((r) => r.isFirst),
                              child: Container(
                                color: AppColors.button,
                                child: Center(
                                  child: Text(
                                    'VOLVER AL INICIO',
                                    style: GoogleFonts.playfairDisplay(
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 2.0,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Fila de detalle ────────────────────────────────────────────────────────────

class _FilaDetalle extends StatelessWidget {
  final IconData icono;
  final String etiqueta;
  final String valor;

  const _FilaDetalle({
    required this.icono,
    required this.etiqueta,
    required this.valor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      child: Row(
        children: [
          Icon(icono,
              size: 16, color: Colors.white.withValues(alpha: 0.40)),
          const SizedBox(width: 10),
          Text(
            etiqueta,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.45),
              fontSize: 10,
              letterSpacing: 1.8,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          Text(
            valor,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

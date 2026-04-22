import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/colors_style.dart';

class PedidoConfirmadoScreen extends StatefulWidget {
  final String tipoEntrega;
  final String tipoPago;
  final double total;
  final String? pedidoId;
  final List<Map<String, dynamic>> items;

  const PedidoConfirmadoScreen({
    super.key,
    required this.tipoEntrega,
    required this.tipoPago,
    required this.total,
    this.pedidoId,
    this.items = const [],
  });

  @override
  State<PedidoConfirmadoScreen> createState() => _PedidoConfirmadoScreenState();
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
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
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
    if (widget.tipoEntrega.contains('domicilio')) return '35 – 45 min';
    return '20 – 25 min';
  }

  IconData get _iconoEntrega {
    if (widget.tipoEntrega.contains('local')) return Icons.restaurant;
    if (widget.tipoEntrega.contains('domicilio')) return Icons.delivery_dining;
    return Icons.store_outlined;
  }

  List<_TrackingStep> get _pasosSeguimiento {
    final esDomicilio = widget.tipoEntrega.contains('domicilio');
    return [
      _TrackingStep(
        icono: Icons.receipt_long_outlined,
        label: 'Recibido',
        hecho: true,
      ),
      _TrackingStep(
        icono: Icons.restaurant_outlined,
        label: 'En preparación',
        hecho: false,
        actual: true,
      ),
      _TrackingStep(
        icono: esDomicilio ? Icons.delivery_dining : Icons.storefront_outlined,
        label: esDomicilio ? 'En camino' : 'Listo para recoger',
        hecho: false,
      ),
      _TrackingStep(
        icono: esDomicilio ? Icons.home_outlined : Icons.check_circle_outline,
        label: esDomicilio ? 'Entregado' : 'Servido',
        hecho: false,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
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
            SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final maxW = constraints.maxWidth.clamp(0.0, 520.0);
                  final hPad = (constraints.maxWidth - maxW) / 2 + 24.0;

                  return FadeTransition(
                    opacity: _fadeAnim,
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: EdgeInsets.fromLTRB(hPad, 48, hPad, 32),
                      child: Column(
                        children: [
                          // ── Check animado ──────────────────────────────
                          ScaleTransition(
                            scale: _scaleAnim,
                            child: Container(
                              width: 88,
                              height: 88,
                              decoration: BoxDecoration(
                                color: AppColors.button.withValues(alpha: 0.15),
                                border: Border.all(
                                  color: AppColors.button,
                                  width: 1.5,
                                ),
                              ),
                              child: const Icon(
                                Icons.check,
                                color: AppColors.button,
                                size: 44,
                              ),
                            ),
                          ),

                          const SizedBox(height: 28),

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

                          const SizedBox(height: 6),
                          Text(
                            'Tu pedido se ha procesado con éxito.\nEstamos preparándolo.',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.55),
                              fontSize: 13,
                              height: 1.6,
                            ),
                            textAlign: TextAlign.center,
                          ),

                          const SizedBox(height: 32),

                          // ── Seguimiento ────────────────────────────────
                          _SeguimientoWidget(pasos: _pasosSeguimiento),

                          const SizedBox(height: 24),

                          // ── Tiempo estimado ────────────────────────────
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              vertical: 14,
                              horizontal: 18,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.button.withValues(alpha: 0.12),
                              border: Border.all(
                                color: AppColors.button.withValues(alpha: 0.50),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.access_time,
                                  color: AppColors.button,
                                  size: 18,
                                ),
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

                          const SizedBox(height: 16),

                          // ── Panel de detalles ──────────────────────────
                          Container(
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.06),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.12),
                              ),
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
                                  color: Colors.white.withValues(alpha: 0.08),
                                ),
                                _FilaDetalle(
                                  icono: Icons.credit_card_outlined,
                                  etiqueta: 'PAGO',
                                  valor: widget.tipoPago,
                                ),
                                Container(
                                  height: 1,
                                  color: Colors.white.withValues(alpha: 0.08),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 18,
                                    vertical: 16,
                                  ),
                                  child: Row(
                                    children: [
                                      Text(
                                        'TOTAL',
                                        style: TextStyle(
                                          color: Colors.white.withValues(
                                            alpha: 0.45,
                                          ),
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

                          // ── Resumen de artículos ───────────────────────
                          if (widget.items.isNotEmpty) ...[
                            const SizedBox(height: 16),
                            _ResumenArticulos(items: widget.items),
                          ],

                          const SizedBox(height: 40),

                          // ── CTA ───────────────────────────────────────
                          SizedBox(
                            width: double.infinity,
                            height: 52,
                            child: GestureDetector(
                              onTap: () => Navigator.of(context).pop(),
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

// ── Seguimiento ────────────────────────────────────────────────────────────────

class _TrackingStep {
  final IconData icono;
  final String label;
  final bool hecho;
  final bool actual;

  const _TrackingStep({
    required this.icono,
    required this.label,
    this.hecho = false,
    this.actual = false,
  });
}

class _SeguimientoWidget extends StatelessWidget {
  final List<_TrackingStep> pasos;
  const _SeguimientoWidget({required this.pasos});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'SEGUIMIENTO',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.45),
              fontSize: 10,
              letterSpacing: 2.0,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              for (int i = 0; i < pasos.length; i++) ...[
                _StepCircle(paso: pasos[i]),
                if (i < pasos.length - 1)
                  Expanded(
                    child: Container(
                      height: 1.5,
                      color: pasos[i].hecho
                          ? AppColors.button
                          : Colors.white.withValues(alpha: 0.18),
                    ),
                  ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: pasos.map((p) {
              return Expanded(
                child: Text(
                  p.label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: p.hecho || p.actual
                        ? Colors.white.withValues(alpha: 0.85)
                        : Colors.white.withValues(alpha: 0.30),
                    fontSize: 9,
                    fontWeight: p.actual ? FontWeight.w700 : FontWeight.w400,
                    letterSpacing: 0.3,
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _StepCircle extends StatelessWidget {
  final _TrackingStep paso;
  const _StepCircle({required this.paso});

  @override
  Widget build(BuildContext context) {
    final Color color = paso.hecho || paso.actual
        ? AppColors.button
        : Colors.white.withValues(alpha: 0.20);

    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: paso.hecho || paso.actual
            ? AppColors.button.withValues(alpha: 0.18)
            : Colors.transparent,
        border: Border.all(color: color, width: 1.5),
        shape: BoxShape.circle,
      ),
      child: Icon(
        paso.hecho ? Icons.check : paso.icono,
        size: 16,
        color: color,
      ),
    );
  }
}

// ── Resumen de artículos ───────────────────────────────────────────────────────

class _ResumenArticulos extends StatelessWidget {
  final List<Map<String, dynamic>> items;
  const _ResumenArticulos({required this.items});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            child: Text(
              'RESUMEN DEL PEDIDO',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.45),
                fontSize: 10,
                letterSpacing: 2.0,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Container(height: 1, color: Colors.white.withValues(alpha: 0.08)),
          ...items.map((item) {
            final nombre = item['nombre']?.toString() ?? '';
            final cantidad = item['cantidad'] as int? ?? 1;
            final precio = (item['precio'] as num?)?.toDouble() ?? 0.0;
            final sin = item['sin'] as List?;
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 12,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 24,
                        height: 24,
                        color: AppColors.button.withValues(alpha: 0.15),
                        child: Center(
                          child: Text(
                            '$cantidad',
                            style: const TextStyle(
                              color: AppColors.button,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              nombre,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (sin != null && sin.isNotEmpty)
                              Text(
                                'Sin: ${sin.join(', ')}',
                                style: const TextStyle(
                                  color: AppColors.excludedIngredient,
                                  fontSize: 10,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                          ],
                        ),
                      ),
                      Text(
                        '${(precio * cantidad).toStringAsFixed(2).replaceAll('.', ',')} €',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.75),
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                if (items.last != item)
                  Container(
                    height: 1,
                    color: Colors.white.withValues(alpha: 0.06),
                  ),
              ],
            );
          }),
        ],
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
          Icon(icono, size: 16, color: Colors.white.withValues(alpha: 0.40)),
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

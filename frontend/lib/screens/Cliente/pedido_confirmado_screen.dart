import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/colors_style.dart';
import '../../services/api_service.dart';

const BorderRadius _kRadius = BorderRadius.all(Radius.circular(12));
const BorderRadius _kRadiusSm = BorderRadius.all(Radius.circular(8));
const Duration _kEntradaDuration = Duration(milliseconds: 600);
const Duration _kStepAnimDuration = Duration(milliseconds: 350);
const Duration _kPollInterval = Duration(seconds: 15);

enum _EstadoVisual { enCurso, entregado, cancelado }

extension on _EstadoVisual {
  Color get colorPrimario => switch (this) {
        _EstadoVisual.cancelado => AppColors.error,
        _EstadoVisual.entregado => AppColors.disp,
        _EstadoVisual.enCurso => AppColors.button,
      };

  IconData get iconoCabecera => switch (this) {
        _EstadoVisual.cancelado => Icons.close,
        _EstadoVisual.entregado => Icons.check_circle_outline,
        _EstadoVisual.enCurso => Icons.check,
      };

  String get titulo => switch (this) {
        _EstadoVisual.cancelado => 'PEDIDO CANCELADO',
        _EstadoVisual.entregado => 'PEDIDO ENTREGADO',
        _EstadoVisual.enCurso => 'PEDIDO CONFIRMADO',
      };

  String get subtitulo => switch (this) {
        _EstadoVisual.cancelado => 'Este pedido ha sido cancelado.',
        _EstadoVisual.entregado => '¡Que lo disfrutes!',
        _EstadoVisual.enCurso =>
          'Tu pedido se ha procesado con éxito.\nEstamos preparándolo.',
      };
}

class _TipoEntregaInfo {
  final IconData icono;
  final String tiempoEstimado;
  final bool esDomicilio;
  final bool esEnLocal;

  const _TipoEntregaInfo._({
    required this.icono,
    required this.tiempoEstimado,
    required this.esDomicilio,
    required this.esEnLocal,
  });

  factory _TipoEntregaInfo.from(String tipoEntrega) {
    final t = tipoEntrega.toLowerCase();
    if (t.contains('mesa') || t.contains('local')) {
      return const _TipoEntregaInfo._(
        icono: Icons.restaurant,
        tiempoEstimado: '10 – 15 min',
        esDomicilio: false,
        esEnLocal: true,
      );
    }
    if (t.contains('domicilio')) {
      return const _TipoEntregaInfo._(
        icono: Icons.delivery_dining,
        tiempoEstimado: '35 – 45 min',
        esDomicilio: true,
        esEnLocal: false,
      );
    }
    return const _TipoEntregaInfo._(
      icono: Icons.store_outlined,
      tiempoEstimado: '20 – 25 min',
      esDomicilio: false,
      esEnLocal: false,
    );
  }
}

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
  State<PedidoConfirmadoScreen> createState() =>
      _PedidoConfirmadoScreenState();
}

class _PedidoConfirmadoScreenState extends State<PedidoConfirmadoScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scaleAnim;
  late final Animation<double> _fadeAnim;

  String _estadoActual = 'pendiente';
  Timer? _pollTimer;

  late final _TipoEntregaInfo _entregaInfo;

  @override
  void initState() {
    super.initState();
    _entregaInfo = _TipoEntregaInfo.from(widget.tipoEntrega);

    _ctrl = AnimationController(vsync: this, duration: _kEntradaDuration);
    _scaleAnim = CurvedAnimation(parent: _ctrl, curve: Curves.elasticOut);
    _fadeAnim = CurvedAnimation(parent: _ctrl, curve: Curves.easeIn);
    _ctrl.forward();

    if (widget.pedidoId != null) {
      _pollEstado();
      _pollTimer = Timer.periodic(_kPollInterval, (_) => _pollEstado());
    }
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _pollEstado() async {
    if (widget.pedidoId == null) return;
    try {
      final pedido = await ApiService.obtenerPedido(widget.pedidoId!);
      if (!mounted) return;
      setState(() => _estadoActual = pedido.estado);
      if (pedido.estado == 'entregado' || pedido.estado == 'cancelado') {
        _pollTimer?.cancel();
      }
    } catch (e) {
      // Reintenta en el siguiente tick. Solo log a debug.
      debugPrint('PedidoConfirmado: poll fallo: $e');
    }
  }

  _EstadoVisual get _estadoVisual {
    switch (_estadoActual) {
      case 'cancelado':
        return _EstadoVisual.cancelado;
      case 'entregado':
        return _EstadoVisual.entregado;
      default:
        return _EstadoVisual.enCurso;
    }
  }

  String? get _referenciaCorta {
    final id = widget.pedidoId;
    if (id == null || id.isEmpty) return null;
    final corte = id.length > 6 ? id.substring(id.length - 6) : id;
    return '#${corte.toUpperCase()}';
  }

  /// Mapea el estado real del backend al índice del paso activo del tracking.
  List<_TrackingStep> get _pasosSeguimiento {
    final esDomicilio = _entregaInfo.esDomicilio;
    final activo = switch (_estadoActual) {
      'preparando' => 1,
      'listo' => 2,
      'entregado' => 4, // mayor que el último → todos hechos
      _ => 0,
    };

    final definicion = <({IconData icono, String label})>[
      (icono: Icons.receipt_long_outlined, label: 'Recibido'),
      (icono: Icons.restaurant_outlined, label: 'En preparación'),
      (
        icono: esDomicilio
            ? Icons.delivery_dining
            : Icons.storefront_outlined,
        label: esDomicilio ? 'En camino' : 'Listo',
      ),
      (
        icono: esDomicilio ? Icons.home_outlined : Icons.check_circle_outline,
        label: esDomicilio ? 'Entregado' : 'Servido',
      ),
    ];

    return [
      for (final (i, d) in definicion.indexed)
        _TrackingStep(
          icono: d.icono,
          label: d.label,
          hecho: i < activo,
          actual: i == activo,
        ),
    ];
  }

  void _volverAlInicio() {
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final visual = _estadoVisual;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _volverAlInicio();
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            const _FondoConVelado(),
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
                          _IconoCabecera(
                            visual: visual,
                            scale: _scaleAnim,
                          ),
                          const SizedBox(height: 28),
                          _Titulo(visual: visual),
                          const SizedBox(height: 6),
                          _Subtitulo(visual: visual),
                          if (_referenciaCorta != null) ...[
                            const SizedBox(height: 14),
                            _ChipReferencia(
                              referencia: _referenciaCorta!,
                              color: visual.colorPrimario,
                            ),
                          ],
                          const SizedBox(height: 32),
                          if (visual == _EstadoVisual.cancelado)
                            const _BannerCancelado()
                          else
                            _SeguimientoWidget(pasos: _pasosSeguimiento),
                          const SizedBox(height: 24),
                          if (visual == _EstadoVisual.enCurso) ...[
                            _ChipTiempo(
                              tiempoEstimado: _entregaInfo.tiempoEstimado,
                            ),
                            const SizedBox(height: 16),
                          ],
                          _PanelDetalles(
                            iconoEntrega: _entregaInfo.icono,
                            tipoEntrega: widget.tipoEntrega,
                            tipoPago: widget.tipoPago,
                            total: widget.total,
                          ),
                          if (widget.items.isNotEmpty) ...[
                            const SizedBox(height: 16),
                            _ResumenArticulos(items: widget.items),
                          ],
                          const SizedBox(height: 40),
                          _CtaVolverInicio(onTap: _volverAlInicio),
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

// ── Widgets internos ─────────────────────────────────────────────────────

class _FondoConVelado extends StatelessWidget {
  const _FondoConVelado();

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: RepaintBoundary(
        child: Stack(
          fit: StackFit.expand,
          children: [
            const Image(
              image: AssetImage('assets/images/Bravo restaurante.jpg'),
              fit: BoxFit.cover,
            ),
            DecoratedBox(
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
          ],
        ),
      ),
    );
  }
}

class _IconoCabecera extends StatelessWidget {
  final _EstadoVisual visual;
  final Animation<double> scale;
  const _IconoCabecera({required this.visual, required this.scale});

  @override
  Widget build(BuildContext context) {
    final color = visual.colorPrimario;
    return ScaleTransition(
      scale: scale,
      child: Container(
        width: 88,
        height: 88,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color.withValues(alpha: 0.15),
          border: Border.all(color: color, width: 1.5),
        ),
        child: Icon(visual.iconoCabecera, color: color, size: 44),
      ),
    );
  }
}

class _Titulo extends StatelessWidget {
  final _EstadoVisual visual;
  const _Titulo({required this.visual});

  @override
  Widget build(BuildContext context) {
    return Text(
      visual.titulo,
      textAlign: TextAlign.center,
      style: GoogleFonts.playfairDisplay(
        color: Colors.white,
        fontSize: 22,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.5,
      ),
    );
  }
}

class _Subtitulo extends StatelessWidget {
  final _EstadoVisual visual;
  const _Subtitulo({required this.visual});

  @override
  Widget build(BuildContext context) {
    return Text(
      visual.subtitulo,
      textAlign: TextAlign.center,
      style: TextStyle(
        color: Colors.white.withValues(alpha: 0.55),
        fontSize: 13,
        height: 1.6,
      ),
    );
  }
}

class _ChipReferencia extends StatelessWidget {
  final String referencia;
  final Color color;
  const _ChipReferencia({required this.referencia, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: _kRadiusSm,
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.tag, size: 13, color: color),
          const SizedBox(width: 5),
          Text(
            referencia,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

class _ChipTiempo extends StatelessWidget {
  final String tiempoEstimado;
  const _ChipTiempo({required this.tiempoEstimado});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 18),
      decoration: BoxDecoration(
        color: AppColors.button.withValues(alpha: 0.12),
        borderRadius: _kRadius,
        border: Border.all(color: AppColors.button.withValues(alpha: 0.50)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.access_time, color: AppColors.button, size: 18),
          const SizedBox(width: 10),
          Text(
            'Tiempo estimado: $tiempoEstimado',
            style: const TextStyle(
              color: AppColors.button,
              fontSize: 13,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _PanelDetalles extends StatelessWidget {
  final IconData iconoEntrega;
  final String tipoEntrega;
  final String tipoPago;
  final double total;

  const _PanelDetalles({
    required this.iconoEntrega,
    required this.tipoEntrega,
    required this.tipoPago,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: _kRadius,
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Column(
        children: [
          _FilaDetalle(
            icono: iconoEntrega,
            etiqueta: 'ENTREGA',
            valor: tipoEntrega,
          ),
          _Separador(),
          _FilaDetalle(
            icono: Icons.credit_card_outlined,
            etiqueta: 'PAGO',
            valor: tipoPago,
          ),
          _Separador(),
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            child: Row(
              children: [
                Text(
                  'TOTAL',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.45),
                    fontSize: 10,
                    letterSpacing: 2.0,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
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
          ),
        ],
      ),
    );
  }
}

class _Separador extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(height: 1, color: Colors.white.withValues(alpha: 0.08));
  }
}

class _CtaVolverInicio extends StatelessWidget {
  final VoidCallback onTap;
  const _CtaVolverInicio({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: Material(
        color: AppColors.button,
        borderRadius: _kRadius,
        elevation: 4,
        shadowColor: Colors.black54,
        child: InkWell(
          onTap: onTap,
          borderRadius: _kRadius,
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
    );
  }
}

class _BannerCancelado extends StatelessWidget {
  const _BannerCancelado();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 18),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.08),
        borderRadius: _kRadius,
        border: Border.all(color: AppColors.error.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Icon(
            Icons.cancel_outlined,
            color: AppColors.error.withValues(alpha: 0.7),
            size: 22,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Este pedido fue cancelado y no será procesado.',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6),
                fontSize: 13,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Seguimiento ──────────────────────────────────────────────────────────

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
        borderRadius: _kRadius,
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
                    child: AnimatedContainer(
                      duration: _kStepAnimDuration,
                      curve: Curves.easeOutCubic,
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
            children: pasos
                .map(
                  (p) => Expanded(
                    child: AnimatedDefaultTextStyle(
                      duration: _kStepAnimDuration,
                      curve: Curves.easeOutCubic,
                      style: TextStyle(
                        color: p.hecho || p.actual
                            ? Colors.white.withValues(alpha: 0.85)
                            : Colors.white.withValues(alpha: 0.30),
                        fontSize: 9,
                        fontWeight:
                            p.actual ? FontWeight.w700 : FontWeight.w400,
                        letterSpacing: 0.3,
                      ),
                      child: Text(p.label, textAlign: TextAlign.center),
                    ),
                  ),
                )
                .toList(),
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
    final activado = paso.hecho || paso.actual;
    final color =
        activado ? AppColors.button : Colors.white.withValues(alpha: 0.20);
    return AnimatedContainer(
      duration: _kStepAnimDuration,
      curve: Curves.easeOutCubic,
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: activado
            ? AppColors.button.withValues(alpha: 0.18)
            : Colors.transparent,
        border: Border.all(color: color, width: 1.5),
      ),
      child: AnimatedSwitcher(
        duration: _kStepAnimDuration,
        transitionBuilder: (child, anim) =>
            ScaleTransition(scale: anim, child: child),
        child: Icon(
          paso.hecho ? Icons.check : paso.icono,
          key: ValueKey(paso.hecho ? 'check' : paso.icono.codePoint),
          size: 16,
          color: color,
        ),
      ),
    );
  }
}

// ── Resumen de artículos ─────────────────────────────────────────────────

class _ResumenArticulos extends StatelessWidget {
  final List<Map<String, dynamic>> items;
  const _ResumenArticulos({required this.items});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: _kRadius,
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
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
          _Separador(),
          for (int i = 0; i < items.length; i++) ...[
            _FilaItem(item: items[i]),
            if (i < items.length - 1)
              Container(
                height: 1,
                color: Colors.white.withValues(alpha: 0.06),
              ),
          ],
        ],
      ),
    );
  }
}

class _FilaItem extends StatelessWidget {
  final Map<String, dynamic> item;
  const _FilaItem({required this.item});

  @override
  Widget build(BuildContext context) {
    final nombre = item['nombre']?.toString() ?? '';
    final cantidad = item['cantidad'] as int? ?? 1;
    final precio = (item['precio'] as num?)?.toDouble() ?? 0.0;
    final sin = item['sin'] as List?;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 26,
            height: 26,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.button.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              '$cantidad',
              style: const TextStyle(
                color: AppColors.button,
                fontSize: 11,
                fontWeight: FontWeight.w800,
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
    );
  }
}

// ── Fila de detalle ──────────────────────────────────────────────────────

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
          Flexible(
            child: Text(
              valor,
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

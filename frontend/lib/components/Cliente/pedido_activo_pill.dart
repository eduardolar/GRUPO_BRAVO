import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/colors_style.dart';
import '../../providers/pedido_activo_provider.dart';
import '../../screens/cliente/pedido_confirmado_screen.dart';

/// Pill flotante que muestra el estado del pedido activo del cliente.
///
/// No se posiciona sola: el padre debe envolverla en un
/// `Positioned(bottom: 16, left: 16, right: 16)`.
///
/// En pantallas anchas (> 600 dp) se limita a 480 dp centrada.
class PedidoActivoPill extends StatelessWidget {
  const PedidoActivoPill({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<PedidoActivoProvider>(
      builder: (context, provider, _) {
        final pedido = provider.pedidoActivo;
        final visible = provider.pillVisible;

        return AnimatedSlide(
          offset: visible ? Offset.zero : const Offset(0, 1.5),
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          child: AnimatedOpacity(
            opacity: visible ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
            child: visible && pedido != null
                ? _PillConstrainedBox(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      child: _PillContent(
                        key: ValueKey(pedido.estado),
                        pedidoId: pedido.id,
                        estado: pedido.estado,
                        tipoEntrega: pedido.tipoEntrega,
                      ),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        );
      },
    );
  }
}

class _PillConstrainedBox extends StatelessWidget {
  final Widget child;
  const _PillConstrainedBox({required this.child});

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width > 600) {
      return Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: child,
        ),
      );
    }
    return child;
  }
}

// ── Contenido de la pill ─────────────────────────────────────────────────

class _PillContent extends StatefulWidget {
  final String pedidoId;
  final String estado;
  final String tipoEntrega;

  const _PillContent({
    super.key,
    required this.pedidoId,
    required this.estado,
    required this.tipoEntrega,
  });

  @override
  State<_PillContent> createState() => _PillContentState();
}

class _PillContentState extends State<_PillContent>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulsoCtrl;
  late final Animation<double> _pulsoScale;

  @override
  void initState() {
    super.initState();
    _pulsoCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _pulsoScale = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _pulsoCtrl, curve: Curves.easeInOut),
    );
    if (widget.estado == 'listo') {
      _pulsoCtrl.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(_PillContent old) {
    super.didUpdateWidget(old);
    if (widget.estado == 'listo' && !_pulsoCtrl.isAnimating) {
      _pulsoCtrl.repeat(reverse: true);
    } else if (widget.estado != 'listo' && _pulsoCtrl.isAnimating) {
      _pulsoCtrl.stop();
      _pulsoCtrl.value = 1.0;
    }
  }

  @override
  void dispose() {
    _pulsoCtrl.dispose();
    super.dispose();
  }

  // ── Helpers de estado ────────────────────────────────────────────────────

  Color get _colorBorde => switch (widget.estado) {
        'pendiente' => AppColors.warning,
        'preparando' => AppColors.button,
        'listo' => AppColors.success,
        _ => AppColors.textSecondary,
      };

  IconData get _icono => switch (widget.estado) {
        'pendiente' => Icons.receipt_long_outlined,
        'preparando' => Icons.restaurant_outlined,
        'listo' => Icons.check_circle_outline,
        _ => Icons.receipt_long_outlined,
      };

  String get _textoEstado => switch (widget.estado) {
        'pendiente' => 'Pedido recibido, en espera',
        'preparando' => 'Cocinando tu pedido…',
        'listo' => 'Listo para recoger',
        _ => widget.estado,
      };

  String get _referenciaCorta {
    final id = widget.pedidoId;
    final corte = id.length > 6 ? id.substring(id.length - 6) : id;
    return '#${corte.toUpperCase()}';
  }

  String get _labelEntrega {
    final t = widget.tipoEntrega.toLowerCase();
    if (t.contains('domicilio')) return 'Domicilio';
    if (t.contains('recoger')) return 'Para recoger';
    return 'En mesa';
  }

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: _textoEstado,
      button: true,
      child: GestureDetector(
        onTap: _navegarAConfirmado,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Material(
              color: Colors.black.withValues(alpha: 0.82),
              borderRadius: BorderRadius.circular(14),
              child: Container(
                height: 60,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: _colorBorde.withValues(alpha: 0.70),
                    width: 1.5,
                  ),
                ),
                child: Row(
                  children: [
                    const SizedBox(width: 12),
                    _IconoAnimado(
                      icono: _icono,
                      color: _colorBorde,
                      pulsoScale: _pulsoScale,
                      animado: widget.estado == 'listo',
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _textoEstado,
                            style: TextStyle(
                              color: _colorBorde,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.3,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Pedido $_referenciaCorta · $_labelEntrega',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.55),
                              fontSize: 12,
                              letterSpacing: 0.2,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.chevron_right,
                      color: Colors.white.withValues(alpha: 0.40),
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _navegarAConfirmado() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PedidoConfirmadoScreen(
          tipoEntrega: widget.tipoEntrega,
          tipoPago: '',
          total: 0,
          pedidoId: widget.pedidoId,
        ),
      ),
    );
  }
}

// ── Icono con animación de pulso ─────────────────────────────────────────

class _IconoAnimado extends StatelessWidget {
  final IconData icono;
  final Color color;
  final Animation<double> pulsoScale;
  final bool animado;

  const _IconoAnimado({
    required this.icono,
    required this.color,
    required this.pulsoScale,
    required this.animado,
  });

  @override
  Widget build(BuildContext context) {
    final circulo = Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withValues(alpha: 0.15),
        border: Border.all(color: color.withValues(alpha: 0.45), width: 1.2),
      ),
      child: Icon(icono, color: color, size: 16),
    );

    if (!animado) return circulo;

    return ScaleTransition(scale: pulsoScale, child: circulo);
  }
}

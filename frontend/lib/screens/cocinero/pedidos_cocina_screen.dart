import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:frontend/core/colors_style.dart';
import 'package:frontend/models/pedido_model.dart';
import 'package:frontend/services/api_service.dart';

const _kEstados = ['pendiente', 'preparando', 'listo'];

String _labelEstado(String e) {
  switch (e) {
    case 'pendiente': return 'Pendiente';
    case 'preparando': return 'En cocina';
    case 'listo': return 'Listo';
    default: return e;
  }
}

Color _colorEstado(String e) {
  switch (e) {
    case 'preparando': return AppColors.button;
    case 'listo': return const Color(0xFF2563EB);
    default: return const Color(0xFFB45309);
  }
}

IconData _iconoEstado(String e) {
  switch (e) {
    case 'preparando': return Icons.local_fire_department_outlined;
    case 'listo': return Icons.check_circle_outline;
    default: return Icons.pending_outlined;
  }
}

class PedidosCocinaScreen extends StatefulWidget {
  const PedidosCocinaScreen({super.key});

  @override
  State<PedidosCocinaScreen> createState() => _PedidosCocinaScreenState();
}

class _PedidosCocinaScreenState extends State<PedidosCocinaScreen> {
  List<Pedido> _pedidos = [];
  bool _cargando = true;
  Timer? _timer;
  final Set<String> _actualizando = {};
  final Map<String, String> _estadoOverride = {};

  @override
  void initState() {
    super.initState();
    _cargarPedidos();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) => _cargarPedidos());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _estadoEfectivo(Pedido p) => _estadoOverride[p.id] ?? p.estado;

  Future<void> _cargarPedidos() async {
    try {
      final todos = await ApiService.obtenerTodosLosPedidos();
      final activos = todos
          .where((p) => _kEstados.contains(p.estado))
          .toList()
        ..sort((a, b) => a.fecha.compareTo(b.fecha));
      if (!mounted) return;
      setState(() {
        _pedidos = activos;
        _cargando = false;
        _estadoOverride.clear();
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _cargando = false);
    }
  }

  Future<void> _cambiarEstado(Pedido pedido, String nuevoEstado) async {
    if (_actualizando.contains(pedido.id)) return;
    if (_estadoEfectivo(pedido) == nuevoEstado) return;
    setState(() {
      _actualizando.add(pedido.id);
      _estadoOverride[pedido.id] = nuevoEstado;
    });
    try {
      await ApiService.actualizarEstadoPedido(
        pedidoId: pedido.id,
        estado: nuevoEstado,
      );
      await _cargarPedidos();
    } catch (e) {
      if (mounted) {
        setState(() => _estadoOverride.remove(pedido.id));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _actualizando.remove(pedido.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'PEDIDOS ACTIVOS',
          style: TextStyle(
            fontFamily: 'Playfair Display',
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.5,
            fontSize: 17,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: IconButton(
              icon: const Icon(Icons.refresh, color: AppColors.button),
              tooltip: 'Actualizar',
              onPressed: () {
                setState(() => _cargando = true);
                _cargarPedidos();
              },
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: AppColors.line, height: 1),
        ),
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator(color: AppColors.button))
          : _buildKanban(),
    );
  }

  Widget _buildKanban() {
    return LayoutBuilder(builder: (context, constraints) {
      const gap = 10.0;
      const padding = 12.0;
      final available = constraints.maxWidth - padding * 2 - gap * 2;
      final colWidth = max(available / 3, 220.0);
      final totalWidth = colWidth * 3 + gap * 2 + padding * 2;

      final board = SizedBox(
        width: totalWidth,
        height: constraints.maxHeight,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: padding, vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (int i = 0; i < _kEstados.length; i++) ...[
                if (i > 0) const SizedBox(width: gap),
                _KanbanColumn(
                  width: colWidth,
                  height: constraints.maxHeight - 24,
                  estado: _kEstados[i],
                  pedidos: _pedidos
                      .where((p) => _estadoEfectivo(p) == _kEstados[i])
                      .toList(),
                  actualizando: _actualizando,
                  onMover: _cambiarEstado,
                ),
              ],
            ],
          ),
        ),
      );

      if (totalWidth > constraints.maxWidth) {
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: board,
        );
      }
      return board;
    });
  }
}

// ── COLUMNA KANBAN ──────────────────────────────────────────────────────────
class _KanbanColumn extends StatelessWidget {
  final double width;
  final double height;
  final String estado;
  final List<Pedido> pedidos;
  final Set<String> actualizando;
  final Future<void> Function(Pedido, String) onMover;

  const _KanbanColumn({
    required this.width,
    required this.height,
    required this.estado,
    required this.pedidos,
    required this.actualizando,
    required this.onMover,
  });

  @override
  Widget build(BuildContext context) {
    final color = _colorEstado(estado);
    return DragTarget<Pedido>(
      onWillAcceptWithDetails: (_) => true,
      onAcceptWithDetails: (d) => onMover(d.data, estado),
      builder: (context, candidates, _) {
        final hovering = candidates.isNotEmpty;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: hovering
                ? color.withValues(alpha: 0.06)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: hovering ? color.withValues(alpha: 0.45) : AppColors.line,
              width: hovering ? 1.5 : 1,
            ),
          ),
          child: Column(
            children: [
              _buildHeader(color),
              Expanded(
                child: pedidos.isEmpty
                    ? _buildEmpty(color)
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(10, 8, 10, 16),
                        itemCount: pedidos.length,
                        itemBuilder: (_, i) => _DraggableCard(
                          pedido: pedidos[i],
                          actualizando: actualizando.contains(pedidos[i].id),
                          currentEstado: estado,
                          onMover: onMover,
                        ),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeader(Color color) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.line)),
      ),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.gold, width: 1.5),
            ),
            child: Icon(_iconoEstado(estado), color: color, size: 15),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              _labelEstado(estado).toUpperCase(),
              style: TextStyle(
                fontFamily: 'Playfair Display',
                color: color,
                fontWeight: FontWeight.w700,
                fontSize: 11,
                letterSpacing: 1.5,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: color.withValues(alpha: 0.3)),
            ),
            child: Text(
              '${pedidos.length}',
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty(Color color) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            _iconoEstado(estado),
            color: color.withValues(alpha: 0.15),
            size: 38,
          ),
          const SizedBox(height: 10),
          Text(
            'Sin pedidos',
            style: TextStyle(
              color: AppColors.textSecondary.withValues(alpha: 0.35),
              fontSize: 12,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

// ── WRAPPER DRAGGABLE ───────────────────────────────────────────────────────
class _DraggableCard extends StatelessWidget {
  final Pedido pedido;
  final bool actualizando;
  final String currentEstado;
  final Future<void> Function(Pedido, String) onMover;

  const _DraggableCard({
    required this.pedido,
    required this.actualizando,
    required this.currentEstado,
    required this.onMover,
  });

  @override
  Widget build(BuildContext context) {
    if (actualizando) {
      return _PedidoCard(
        pedido: pedido,
        currentEstado: currentEstado,
        onMover: onMover,
        loading: true,
      );
    }
    return LongPressDraggable<Pedido>(
      data: pedido,
      delay: const Duration(milliseconds: 280),
      feedback: Material(
        color: Colors.transparent,
        child: Opacity(
          opacity: 0.88,
          child: SizedBox(
            width: 190,
            child: _PedidoCard(
              pedido: pedido,
              currentEstado: currentEstado,
              onMover: onMover,
              compact: true,
            ),
          ),
        ),
      ),
      childWhenDragging: Opacity(
        opacity: 0.25,
        child: _PedidoCard(
          pedido: pedido,
          currentEstado: currentEstado,
          onMover: onMover,
        ),
      ),
      child: _PedidoCard(
        pedido: pedido,
        currentEstado: currentEstado,
        onMover: onMover,
      ),
    );
  }
}

// ── TARJETA ─────────────────────────────────────────────────────────────────
class _PedidoCard extends StatelessWidget {
  final Pedido pedido;
  final String currentEstado;
  final Future<void> Function(Pedido, String) onMover;
  final bool compact;
  final bool loading;

  const _PedidoCard({
    required this.pedido,
    required this.currentEstado,
    required this.onMover,
    this.compact = false,
    this.loading = false,
  });

  String get _etiquetaEntrega {
    switch (pedido.tipoEntrega) {
      case 'local': return 'Mesa ${pedido.numeroMesa ?? '-'}';
      case 'domicilio': return 'A domicilio';
      case 'recoger': return 'Para recoger';
      default: return pedido.tipoEntrega;
    }
  }

  IconData get _iconoEntrega {
    switch (pedido.tipoEntrega) {
      case 'local': return Icons.table_restaurant_outlined;
      case 'domicilio': return Icons.delivery_dining_outlined;
      case 'recoger': return Icons.shopping_bag_outlined;
      default: return Icons.receipt_long_outlined;
    }
  }

  String _hora(String fecha) {
    try {
      final dt = DateTime.parse(fecha);
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.panel,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.line),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.07),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: loading
          ? const Padding(
              padding: EdgeInsets.symmetric(vertical: 22),
              child: Center(
                child: CircularProgressIndicator(
                  color: AppColors.button,
                  strokeWidth: 2,
                ),
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildCabecera(),
                if (!compact) ...[
                  const Divider(height: 1, color: AppColors.line),
                  _buildProductos(),
                  if (pedido.notas != null && pedido.notas!.isNotEmpty)
                    _buildNotas(),
                  const Divider(height: 1, color: AppColors.line),
                  _buildBotones(),
                ],
              ],
            ),
    );
  }

  Widget _buildCabecera() {
    return Padding(
      padding: const EdgeInsets.all(11),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.gold, width: 1.5),
            ),
            child: Icon(_iconoEntrega, color: AppColors.gold, size: 16),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _etiquetaEntrega,
                  style: const TextStyle(
                    fontFamily: 'Playfair Display',
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                Text(
                  _hora(pedido.fecha),
                  style: TextStyle(
                    color: AppColors.textSecondary.withValues(alpha: 0.65),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          if (!compact)
            Tooltip(
              message: 'Mantén pulsado para arrastrar',
              child: Icon(
                Icons.drag_indicator,
                color: AppColors.textSecondary.withValues(alpha: 0.22),
                size: 16,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildProductos() {
    final visible = pedido.productos.take(3).toList();
    final extra = pedido.productos.length - visible.length;
    return Padding(
      padding: const EdgeInsets.fromLTRB(11, 8, 11, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ...visible.map(
            (p) => Padding(
              padding: const EdgeInsets.only(bottom: 5),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 22,
                    height: 22,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AppColors.line),
                    ),
                    child: Text(
                      '${p.cantidad}',
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 10,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          p.nombre.isNotEmpty ? p.nombre : 'Producto',
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        if (p.sin.isNotEmpty)
                          Text(
                            'Sin: ${p.sin.join(', ')}',
                            style: TextStyle(
                              color: AppColors.textSecondary.withValues(alpha: 0.65),
                              fontSize: 10,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (extra > 0)
            Text(
              '+ $extra más',
              style: TextStyle(
                color: AppColors.textSecondary.withValues(alpha: 0.5),
                fontSize: 11,
                fontStyle: FontStyle.italic,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildNotas() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(11, 0, 11, 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.line),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.notes_outlined, size: 12, color: AppColors.textSecondary),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                pedido.notas!,
                style: TextStyle(
                  color: AppColors.textSecondary.withValues(alpha: 0.8),
                  fontSize: 11,
                  fontStyle: FontStyle.italic,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBotones() {
    final idx = _kEstados.indexOf(currentEstado);
    final hasPrev = idx > 0;
    final hasNext = idx < _kEstados.length - 1;

    return Padding(
      padding: const EdgeInsets.all(10),
      child: Row(
        children: [
          if (hasPrev) ...[
            Expanded(
              child: _Boton(
                icon: Icons.chevron_left,
                label: _labelEstado(_kEstados[idx - 1]),
                onPressed: () => onMover(pedido, _kEstados[idx - 1]),
                primary: false,
                iconLeft: true,
              ),
            ),
            if (hasNext) const SizedBox(width: 8),
          ],
          if (hasNext)
            Expanded(
              child: _Boton(
                icon: Icons.chevron_right,
                label: _labelEstado(_kEstados[idx + 1]),
                onPressed: () => onMover(pedido, _kEstados[idx + 1]),
                primary: true,
                iconLeft: false,
              ),
            ),
        ],
      ),
    );
  }
}

// ── BOTÓN ────────────────────────────────────────────────────────────────────
class _Boton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final bool primary;
  final bool iconLeft;

  const _Boton({
    required this.icon,
    required this.label,
    required this.onPressed,
    required this.primary,
    required this.iconLeft,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 34,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: AppColors.gold, width: 1.5),
      ),
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: primary ? AppColors.button : AppColors.panel,
          foregroundColor: primary ? Colors.white : AppColors.textPrimary,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (iconLeft) ...[Icon(icon, size: 13), const SizedBox(width: 3)],
            Flexible(
              child: Text(
                label,
                style: const TextStyle(
                  fontFamily: 'Playfair Display',
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (!iconLeft) ...[const SizedBox(width: 3), Icon(icon, size: 13)],
          ],
        ),
      ),
    );
  }
}

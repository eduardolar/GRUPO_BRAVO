import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../components/Cliente/empty_state.dart';
import '../../components/Cliente/skeleton.dart';
import '../../core/app_snackbar.dart';
import '../../core/colors_style.dart';
import '../../models/pedido_model.dart';
import '../../screens/cliente/pedido_confirmado_screen.dart';
import '../../services/api_service.dart';
import '../../providers/auth_provider.dart';

class HistorialPedidosScreen extends StatefulWidget {
  const HistorialPedidosScreen({super.key});

  @override
  State<HistorialPedidosScreen> createState() => _HistorialPedidosScreenState();
}

class _HistorialPedidosScreenState extends State<HistorialPedidosScreen> {
  List<Pedido> _pedidos = [];
  List<Pedido> _pedidosFiltrados = [];
  bool _cargando = true;
  int _expandido = -1;
  String _filtroEstado = 'todos';

  static const List<List<String>> _filtros = [
    ['todos', 'Todos'],
    ['pendiente', 'Pendiente'],
    ['preparando', 'En cocina'],
    ['listo', 'Listo'],
    ['entregado', 'Entregado'],
    ['cancelado', 'Cancelado'],
  ];

  static const _estadosActivos = {'pendiente', 'preparando', 'listo'};

  @override
  void initState() {
    super.initState();
    _cargarPedidos();
  }

  Future<void> _cargarPedidos() async {
    if (!_cargando) setState(() => _cargando = true);
    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final userId = auth.usuarioActual?.id ?? '';
      final pedidos = await ApiService.obtenerHistorialPedidos(userId: userId);
      pedidos.sort((a, b) => b.fecha.compareTo(a.fecha));
      if (!mounted) return;
      setState(() {
        _pedidos = pedidos;
        _aplicarFiltro();
        _cargando = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _cargando = false);
      showAppError(context, 'Error al cargar pedidos: $e');
    }
  }

  void _aplicarFiltro() {
    _pedidosFiltrados = _filtroEstado == 'todos'
        ? List.from(_pedidos)
        : _pedidos.where((p) => p.estado == _filtroEstado).toList();
  }

  String _formatearFecha(String fecha) {
    try {
      final dt = DateTime.parse(fecha).toLocal();
      final now = DateTime.now();
      final diff = DateTime(now.year, now.month, now.day)
          .difference(DateTime(dt.year, dt.month, dt.day))
          .inDays;
      final hora =
          '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
      if (diff == 0) return 'Hoy · $hora';
      if (diff == 1) return 'Ayer · $hora';
      if (diff < 7) return 'Hace $diff días';
      return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
    } catch (_) {
      return fecha;
    }
  }

  String _formatearPrecio(double precio) =>
      '${precio.toStringAsFixed(2).replaceAll('.', ',')} €';

  Color _colorEstado(String estado) {
    switch (estado) {
      case 'pendiente':
        return AppColors.noDisp;
      case 'preparando':
        return const Color(0xFFD97706);
      case 'listo':
        return AppColors.button;
      case 'entregado':
        return AppColors.disp;
      case 'cancelado':
        return AppColors.error;
      default:
        return AppColors.textSecondary;
    }
  }

  IconData _iconoEstado(String estado) {
    switch (estado) {
      case 'pendiente':
        return Icons.hourglass_empty_rounded;
      case 'preparando':
        return Icons.local_fire_department_rounded;
      case 'listo':
        return Icons.done_all_rounded;
      case 'entregado':
        return Icons.check_circle_rounded;
      case 'cancelado':
        return Icons.cancel_rounded;
      default:
        return Icons.receipt_long_rounded;
    }
  }

  String _etiquetaEstado(Pedido pedido) {
    switch (pedido.estado) {
      case 'pendiente':
        return 'Pendiente';
      case 'preparando':
        return 'En cocina';
      case 'listo':
        switch (pedido.tipoEntrega) {
          case 'domicilio':
            return 'Listo para envío';
          case 'recoger':
            return 'Listo para recoger';
          default:
            return 'Listo para servir';
        }
      case 'entregado':
        return 'Entregado';
      case 'cancelado':
        return 'Cancelado';
      default:
        return pedido.estado;
    }
  }

  String _labelTipoEntrega(String tipo) {
    switch (tipo) {
      case 'domicilio':
        return 'A domicilio';
      case 'recoger':
        return 'Para recoger';
      default:
        return 'En mesa';
    }
  }

  String _labelMetodoPago(String metodo) {
    switch (metodo) {
      case 'tarjeta':
        return 'Tarjeta';
      case 'paypal':
        return 'PayPal';
      default:
        return 'Efectivo';
    }
  }

  IconData _iconoEntrega(String tipo) {
    switch (tipo) {
      case 'domicilio':
        return Icons.delivery_dining_rounded;
      case 'recoger':
        return Icons.shopping_bag_rounded;
      default:
        return Icons.restaurant_rounded;
    }
  }

  IconData _iconoPago(String metodo) {
    switch (metodo) {
      case 'tarjeta':
        return Icons.credit_card_rounded;
      case 'paypal':
        return Icons.account_balance_wallet_rounded;
      default:
        return Icons.payments_rounded;
    }
  }

  String _etiquetaEstadoFiltro(String estado) {
    switch (estado) {
      case 'pendiente':
        return 'pendientes';
      case 'preparando':
        return 'en cocina';
      case 'listo':
        return 'listos';
      case 'entregado':
        return 'entregados';
      case 'cancelado':
        return 'cancelados';
      default:
        return estado;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final activos =
        _pedidos.where((p) => _estadosActivos.contains(p.estado)).length;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _cargarPedidos,
          color: AppColors.button,
          backgroundColor: AppColors.background,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              // ── AppBar ──────────────────────────────────────────────────
              _buildAppBar(),

              // ── Banner activos ──────────────────────────────────────────
              if (!_cargando && activos > 0)
                SliverToBoxAdapter(child: _buildActiveBanner(activos)),

              // ── Chips filtro ────────────────────────────────────────────
              SliverToBoxAdapter(child: _buildFiltros()),

              // ── Contenido ───────────────────────────────────────────────
              if (_cargando)
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (_, _) => _buildSkeleton(),
                    childCount: 4,
                  ),
                )
              else if (_pedidosFiltrados.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: _buildEmptyState(),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (_, i) => _buildPedidoCard(i),
                      childCount: _pedidosFiltrados.length,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ── AppBar ────────────────────────────────────────────────────────────────

  Widget _buildAppBar() {
    return SliverAppBar(
      backgroundColor: AppColors.background,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      pinned: true,
      leading: IconButton(
        tooltip: 'Volver',
        icon: const Icon(Icons.arrow_back_ios_new_rounded,
            color: AppColors.button, size: 20),
        onPressed: () => Navigator.pop(context),
      ),
      title: Text(
        'Mis Pedidos',
        style: GoogleFonts.manrope(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w800,
          fontSize: 20,
        ),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh_rounded,
              color: AppColors.button, size: 22),
          onPressed: _cargarPedidos,
          tooltip: 'Actualizar',
        ),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(height: 1, color: AppColors.line),
      ),
    );
  }

  // ── Banner pedidos activos ─────────────────────────────────────────────────

  Widget _buildActiveBanner(int count) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: AppColors.button.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.button.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          // Punto pulsante
          _PulsingDot(color: AppColors.button),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              count == 1
                  ? 'Tienes 1 pedido en curso'
                  : 'Tienes $count pedidos en curso',
              style: GoogleFonts.manrope(
                color: AppColors.button,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
          Icon(Icons.chevron_right_rounded,
              color: AppColors.button.withValues(alpha: 0.5), size: 18),
        ],
      ),
    );
  }

  // ── Chips de filtro ───────────────────────────────────────────────────────

  Widget _buildFiltros() {
    final counts = <String, int>{
      'todos': _pedidos.length,
    };
    for (final f in _filtros.skip(1)) {
      counts[f[0]] = _pedidos.where((p) => p.estado == f[0]).length;
    }

    return SizedBox(
      height: 52,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: _filtros.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final value = _filtros[i][0];
          final label = _filtros[i][1];
          final isSelected = _filtroEstado == value;
          final count = counts[value] ?? 0;

          return GestureDetector(
            onTap: () => setState(() {
              _filtroEstado = value;
              _expandido = -1;
              _aplicarFiltro();
            }),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.button : AppColors.panel,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected ? AppColors.button : AppColors.line,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: GoogleFonts.manrope(
                      color: isSelected
                          ? Colors.white
                          : AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                  if (count > 0 && !isSelected) ...[
                    const SizedBox(width: 5),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: AppColors.line,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '$count',
                        style: GoogleFonts.manrope(
                          color: AppColors.textSecondary,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ── Tarjeta de pedido ─────────────────────────────────────────────────────

  Widget _buildPedidoCard(int index) {
    final pedido = _pedidosFiltrados[index];
    final estaExpandido = _expandido == index;
    final colorEstado = _colorEstado(pedido.estado);
    final esActivo = _estadosActivos.contains(pedido.estado);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.panel,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: estaExpandido
              ? AppColors.button.withValues(alpha: 0.35)
              : AppColors.line,
        ),
        boxShadow: [
          BoxShadow(
            color: estaExpandido
                ? AppColors.button.withValues(alpha: 0.07)
                : Colors.black.withValues(alpha: 0.04),
            blurRadius: estaExpandido ? 16 : 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => setState(
                () => _expandido = estaExpandido ? -1 : index),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Cabecera ──────────────────────────────────────────
                  Row(
                    children: [
                      // Icono estado con dot activo
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              color:
                                  colorEstado.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Icon(_iconoEstado(pedido.estado),
                                color: colorEstado, size: 24),
                          ),
                          if (esActivo)
                            Positioned(
                              top: -2,
                              right: -2,
                              child: Container(
                                width: 10,
                                height: 10,
                                decoration: BoxDecoration(
                                  color: colorEstado,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                      color: AppColors.panel, width: 2),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(width: 12),

                      // Fecha e items
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _formatearFecha(pedido.fecha),
                              style: GoogleFonts.manrope(
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Row(
                              children: [
                                Text(
                                  '${pedido.items} ${pedido.items == 1 ? 'artículo' : 'artículos'}',
                                  style: GoogleFonts.manrope(
                                    color: AppColors.textSecondary,
                                    fontSize: 12,
                                  ),
                                ),
                                if (pedido.numeroMesa != null) ...[
                                  Text(
                                    ' · Mesa ${pedido.numeroMesa}',
                                    style: GoogleFonts.manrope(
                                      color: AppColors.textSecondary,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),

                      // Total + badge
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            _formatearPrecio(pedido.total),
                            style: GoogleFonts.manrope(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 4),
                          _BadgeEstado(
                            label: _etiquetaEstado(pedido),
                            color: colorEstado,
                          ),
                        ],
                      ),
                      const SizedBox(width: 4),
                      AnimatedRotation(
                        turns: estaExpandido ? 0.5 : 0,
                        duration: const Duration(milliseconds: 300),
                        child: Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: AppColors.textSecondary
                              .withValues(alpha: 0.45),
                          size: 24,
                        ),
                      ),
                    ],
                  ),

                  // ── Detalle expandido ──────────────────────────────────
                  AnimatedCrossFade(
                    firstChild: const SizedBox.shrink(),
                    secondChild: _buildDetalle(pedido, colorEstado),
                    crossFadeState: estaExpandido
                        ? CrossFadeState.showSecond
                        : CrossFadeState.showFirst,
                    duration: const Duration(milliseconds: 300),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Detalle expandido ─────────────────────────────────────────────────────

  Widget _buildDetalle(Pedido pedido, Color colorEstado) {
    final esActivo = _estadosActivos.contains(pedido.estado);
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Divider(),

          const SizedBox(height: 14),

          // ── Stepper de estado ──────────────────────────────────────────
          _buildStatusStepper(pedido.estado),

          const SizedBox(height: 18),

          // ── Productos ─────────────────────────────────────────────────
          _SectionLabel(label: 'PRODUCTOS'),
          const SizedBox(height: 8),
          ...pedido.productos.map((p) => _buildProductoRow(p)),

          _Divider(vPadding: 10),

          // Total
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total',
                style: GoogleFonts.manrope(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
              Text(
                _formatearPrecio(pedido.total),
                style: GoogleFonts.manrope(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // ── Detalles entrega / pago ────────────────────────────────────
          _SectionLabel(label: 'DETALLES'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _InfoChip(
                icon: _iconoEntrega(pedido.tipoEntrega),
                label: _labelTipoEntrega(pedido.tipoEntrega),
              ),
              _InfoChip(
                icon: _iconoPago(pedido.metodoPago),
                label: _labelMetodoPago(pedido.metodoPago),
              ),
              if (pedido.direccion != null)
                _InfoChip(
                  icon: Icons.location_on_rounded,
                  label: pedido.direccion!,
                ),
            ],
          ),

          // Notas
          if (pedido.notas != null && pedido.notas!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.line),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.notes_rounded,
                      size: 14,
                      color:
                          AppColors.textSecondary.withValues(alpha: 0.6)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      pedido.notas!,
                      style: GoogleFonts.manrope(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // ── Botón seguir pedido ────────────────────────────────────────
          if (esActivo) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => PedidoConfirmadoScreen(
                      pedidoId: pedido.id,
                      tipoEntrega: pedido.tipoEntrega,
                      tipoPago: pedido.metodoPago,
                      total: pedido.total,
                      items: pedido.productos
                          .map((p) => {
                                'nombre': p.nombre,
                                'cantidad': p.cantidad,
                                'precio': p.precio,
                                'sin': p.sin,
                              })
                          .toList(),
                    ),
                  ),
                ),
                icon: const Icon(Icons.radar_rounded, size: 18),
                label: Text(
                  'SEGUIR PEDIDO',
                  style: GoogleFonts.manrope(
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                    letterSpacing: 0.5,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.button,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── Status stepper ────────────────────────────────────────────────────────

  Widget _buildStatusStepper(String estadoActual) {
    if (estadoActual == 'cancelado') {
      return Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.error.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: AppColors.error.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            Icon(Icons.cancel_rounded,
                color: AppColors.error, size: 16),
            const SizedBox(width: 8),
            Text(
              'Este pedido fue cancelado',
              style: GoogleFonts.manrope(
                color: AppColors.error,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }

    const pasos = [
      ['pendiente', 'Recibido', 'receipt'],
      ['preparando', 'En cocina', 'fire'],
      ['listo', 'Listo', 'done'],
      ['entregado', 'Entregado', 'check'],
    ];

    final pasoActualIdx =
        pasos.indexWhere((p) => p[0] == estadoActual);

    final iconos = [
      Icons.receipt_rounded,
      Icons.local_fire_department_rounded,
      Icons.done_all_rounded,
      Icons.check_circle_rounded,
    ];

    return Row(
      children: List.generate(pasos.length * 2 - 1, (i) {
        if (i.isOdd) {
          final pasoIdx = (i - 1) ~/ 2;
          final completado = pasoIdx < pasoActualIdx;
          return Expanded(
            child: Container(
              height: 2,
              decoration: BoxDecoration(
                color: completado ? AppColors.button : AppColors.line,
                borderRadius: BorderRadius.circular(1),
              ),
            ),
          );
        }

        final pasoIdx = i ~/ 2;
        final label = pasos[pasoIdx][1];
        final completado = pasoIdx < pasoActualIdx;
        final actual = pasoIdx == pasoActualIdx;

        return Column(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: completado || actual
                    ? AppColors.button
                    : AppColors.line,
                shape: BoxShape.circle,
              ),
              child: Icon(
                completado ? Icons.check_rounded : iconos[pasoIdx],
                size: 16,
                color: completado || actual
                    ? Colors.white
                    : AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              label,
              style: GoogleFonts.manrope(
                color: completado || actual
                    ? AppColors.textPrimary
                    : AppColors.textSecondary.withValues(alpha: 0.4),
                fontSize: 9,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        );
      }),
    );
  }

  // ── Fila de producto ──────────────────────────────────────────────────────

  Widget _buildProductoRow(ProductoPedido p) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: AppColors.button.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(7),
            ),
            child: Center(
              child: Text(
                '${p.cantidad}',
                style: GoogleFonts.manrope(
                  color: AppColors.button,
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  p.nombre,
                  style: GoogleFonts.manrope(
                    color: AppColors.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (p.sin.isNotEmpty)
                  Text(
                    'Sin: ${p.sin.join(', ')}',
                    style: GoogleFonts.manrope(
                      color: AppColors.textSecondary,
                      fontSize: 11,
                    ),
                  ),
              ],
            ),
          ),
          Text(
            _formatearPrecio(p.subtotal),
            style: GoogleFonts.manrope(
              color: AppColors.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // ── Empty state ───────────────────────────────────────────────────────────

  Widget _buildEmptyState() {
    final esTodos = _filtroEstado == 'todos';
    return EmptyState(
      icon: esTodos ? Icons.receipt_long_rounded : _iconoEstado(_filtroEstado),
      iconBackground: AppColors.panel,
      title: esTodos
          ? 'Aún no tienes pedidos'
          : 'Sin pedidos ${_etiquetaEstadoFiltro(_filtroEstado)}',
      subtitle: esTodos
          ? 'Tus pedidos aparecerán aquí una vez que realices tu primera orden.'
          : 'No hay pedidos con este estado en tu historial.',
    );
  }

  // ── Skeleton shimmer ──────────────────────────────────────────────────────

  Widget _buildSkeleton() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.panel,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.line),
        ),
        child: Row(
          children: [
            const SkeletonBlock(width: 50, height: 50, borderRadius: 14),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  SkeletonBlock(height: 14, borderRadius: 7),
                  SizedBox(height: 8),
                  SkeletonBlock(width: 130, height: 10, borderRadius: 5),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: const [
                SkeletonBlock(width: 60, height: 14, borderRadius: 7),
                SizedBox(height: 8),
                SkeletonBlock(width: 75, height: 10, borderRadius: 5),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Widgets auxiliares
// ─────────────────────────────────────────────────────────────────────────────

class _BadgeEstado extends StatelessWidget {
  const _BadgeEstado({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: GoogleFonts.manrope(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon,
              size: 14,
              color: AppColors.textSecondary.withValues(alpha: 0.7)),
          const SizedBox(width: 6),
          Text(
            label,
            style: GoogleFonts.manrope(
              color: AppColors.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: GoogleFonts.manrope(
        color: AppColors.textSecondary,
        fontSize: 10,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.2,
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider({this.vPadding = 0});
  final double vPadding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: vPadding),
      child: Row(
        children: [
          Expanded(child: Container(height: 1, color: AppColors.line)),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 10),
            width: 5,
            height: 5,
            decoration: BoxDecoration(
              color: AppColors.button.withValues(alpha: 0.25),
              shape: BoxShape.circle,
            ),
          ),
          Expanded(child: Container(height: 1, color: AppColors.line)),
        ],
      ),
    );
  }
}

class _PulsingDot extends StatefulWidget {
  const _PulsingDot({required this.color});
  final Color color;

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _scale = Tween(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scale,
      child: Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(
          color: widget.color,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

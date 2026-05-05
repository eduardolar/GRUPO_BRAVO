import 'dart:ui';
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
      final diff = DateTime(
        now.year,
        now.month,
        now.day,
      ).difference(DateTime(dt.year, dt.month, dt.day)).inDays;
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
    final activos = _pedidos
        .where((p) => _estadosActivos.contains(p.estado))
        .length;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // ── FONDO EXACTO AL DE LA CAPTURA ──────────────────────────────
          Positioned.fill(
            child: Image.asset(
              'assets/images/Bravo restaurante.jpg', // Ruta a tu imagen
              fit: BoxFit.cover,
            ),
          ),
          // Capa oscura por encima para dar legibilidad (como en la captura)
          Positioned.fill(
            child: Container(
              color: Colors.black.withValues(alpha: 0.7), // Ajusta la oscuridad aquí
            ),
          ),

          // ── CONTENIDO PRINCIPAL ─────────────────────────────────────────
          SafeArea(
            child: RefreshIndicator(
              onRefresh: _cargarPedidos,
              color: AppColors.button,
              backgroundColor: AppColors.panel,
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
        ],
      ),
    );
  }

  // ── AppBar ────────────────────────────────────────────────────────────────

  Widget _buildAppBar() {
    return SliverAppBar(
      backgroundColor: Colors.transparent, // Transparente total
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      pinned: true,
      leading: IconButton(
        tooltip: 'Volver',
        icon: const Icon(
          Icons.arrow_back_ios_new_rounded,
          color: Colors.white, // Blanco para contrastar en fondo oscuro
          size: 20,
        ),
        onPressed: () => Navigator.pop(context),
      ),
      title: Text(
        'Historial de pedidos',
        style: GoogleFonts.manrope(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: 18,
          letterSpacing: 0.5,
        ),
      ),
      centerTitle: true,
      actions: [
        IconButton(
          icon: const Icon(
            Icons.refresh_rounded,
            color: Colors.white70,
            size: 22,
          ),
          onPressed: _cargarPedidos,
          tooltip: 'Actualizar',
        ),
      ],
    );
  }

  // ── Banner pedidos activos ─────────────────────────────────────────────────

  Widget _buildActiveBanner(int count) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.button.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.button.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          _PulsingDot(color: AppColors.button),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              count == 1
                  ? 'Tienes 1 pedido en curso'
                  : 'Tienes $count pedidos en curso',
              style: GoogleFonts.manrope(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
          Icon(
            Icons.chevron_right_rounded,
            color: Colors.white54,
            size: 20,
          ),
        ],
      ),
    );
  }

  // ── Chips de filtro ───────────────────────────────────────────────────────

  Widget _buildFiltros() {
    final counts = <String, int>{'todos': _pedidos.length};
    for (final f in _filtros.skip(1)) {
      counts[f[0]] = _pedidos.where((p) => p.estado == f[0]).length;
    }

    return SizedBox(
      height: 60,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                // Fondo oscuro cristalino como en tu captura
                color: isSelected 
                    ? AppColors.button 
                    : Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isSelected 
                      ? AppColors.button 
                      : Colors.white.withValues(alpha: 0.1),
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
                          : Colors.white70,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      fontSize: 13,
                    ),
                  ),
                  if (count > 0 && !isSelected) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '$count',
                        style: GoogleFonts.manrope(
                          color: Colors.white70,
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

  // ── Tarjeta de pedido (Efecto Perfil) ─────────────────────────────────────

  Widget _buildPedidoCard(int index) {
    final pedido = _pedidosFiltrados[index];
    final estaExpandido = _expandido == index;
    final colorEstado = _colorEstado(pedido.estado);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      margin: const EdgeInsets.only(bottom: 12),
      // Mismo estilo de la captura: fondo semi-transparente y borde sutil
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: estaExpandido
              ? AppColors.button.withValues(alpha: 0.5)
              : Colors.white.withValues(alpha: 0.1),
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8), // Blur cristalino
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () =>
                  setState(() => _expandido = estaExpandido ? -1 : index),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Cabecera ──────────────────────────────────────────
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Icono minimalista
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: colorEstado.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: colorEstado.withValues(alpha: 0.3)),
                          ),
                          child: Icon(
                            _iconoEstado(pedido.estado),
                            color: colorEstado,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 14),

                        // Fecha e items
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _formatearFecha(pedido.fecha),
                                style: GoogleFonts.manrope(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Text(
                                    '${pedido.items} ${pedido.items == 1 ? 'artículo' : 'artículos'}',
                                    style: GoogleFonts.manrope(
                                      color: Colors.white60,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  if (pedido.numeroMesa != null) ...[
                                    Text(
                                      ' · Mesa ${pedido.numeroMesa}',
                                      style: GoogleFonts.manrope(
                                        color: Colors.white60,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 8),
                              _BadgeEstado(
                                label: _etiquetaEstado(pedido),
                                color: colorEstado,
                              ),
                            ],
                          ),
                        ),

                        // Total + Flecha
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              _formatearPrecio(pedido.total),
                              style: GoogleFonts.manrope(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 12),
                            AnimatedRotation(
                              turns: estaExpandido ? 0.5 : 0,
                              duration: const Duration(milliseconds: 300),
                              child: Icon(
                                Icons.keyboard_arrow_down_rounded,
                                color: Colors.white54,
                                size: 24,
                              ),
                            ),
                          ],
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

          const SizedBox(height: 16),

          // ── Stepper de estado ──────────────────────────────────────────
          _buildStatusStepper(pedido.estado),

          const SizedBox(height: 24),

          // ── Productos (Diseño Limpio) ───────────────────────────────────
          _SectionLabel(label: 'RESUMEN DE CUENTA'),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.2), // Fondo más oscuro para contraste
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
            ),
            child: Column(
              children: [
                ...pedido.productos.map((p) => _buildProductoRow(p)),
                _Divider(vPadding: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'TOTAL',
                      style: GoogleFonts.manrope(
                        color: Colors.white70,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        letterSpacing: 1.0,
                      ),
                    ),
                    Text(
                      _formatearPrecio(pedido.total),
                      style: GoogleFonts.manrope(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 18),

          // ── Detalles entrega / pago ────────────────────────────────────
          _SectionLabel(label: 'INFORMACIÓN DE ENVÍO'),
          const SizedBox(height: 10),
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
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.edit_note_rounded,
                    size: 16,
                    color: Colors.white54,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      pedido.notas!,
                      style: GoogleFonts.manrope(
                        color: Colors.white70,
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // ── Botón seguir pedido ────────────────────────────────────────
          if (esActivo) ...[
            const SizedBox(height: 20),
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
                          .map(
                            (p) => {
                              'nombre': p.nombre,
                              'cantidad': p.cantidad,
                              'precio': p.precio,
                              'sin': p.sin,
                            },
                          )
                          .toList(),
                    ),
                  ),
                ),
                icon: const Icon(Icons.my_location_rounded, size: 18),
                label: Text(
                  'RASTREAR PEDIDO',
                  style: GoogleFonts.manrope(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    letterSpacing: 1.0,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.button,
                  foregroundColor: Colors.white,
                  elevation: 0, // Plano para encajar en el diseño
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
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
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.error.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Icon(Icons.error_outline_rounded, color: AppColors.error, size: 18),
            const SizedBox(width: 10),
            Text(
              'El pedido fue cancelado',
              style: GoogleFonts.manrope(
                color: AppColors.error,
                fontSize: 13,
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

    final pasoActualIdx = pasos.indexWhere((p) => p[0] == estadoActual);

    final iconos = [
      Icons.receipt_long_rounded,
      Icons.outdoor_grill_rounded,
      Icons.check_circle_outline_rounded,
      Icons.home_work_rounded,
    ];

    return Row(
      children: List.generate(pasos.length * 2 - 1, (i) {
        if (i.isOdd) {
          final pasoIdx = (i - 1) ~/ 2;
          final completado = pasoIdx < pasoActualIdx;
          return Expanded(
            child: Container(
              height: 2,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                color: completado ? AppColors.button : Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(2),
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
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: completado || actual ? AppColors.button : Colors.white.withValues(alpha: 0.05),
                shape: BoxShape.circle,
                border: Border.all(
                  color: completado || actual ? AppColors.button : Colors.white.withValues(alpha: 0.2),
                  width: 1.5,
                ),
              ),
              child: Icon(
                completado ? Icons.check_rounded : iconos[pasoIdx],
                size: 16,
                color: completado || actual
                    ? Colors.white
                    : Colors.white54,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: GoogleFonts.manrope(
                color: completado || actual
                    ? Colors.white
                    : Colors.white54,
                fontSize: 10,
                fontWeight: actual ? FontWeight.w700 : FontWeight.w500,
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
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Center(
              child: Text(
                '${p.cantidad}x',
                style: GoogleFonts.manrope(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 11,
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
                  p.nombre,
                  style: GoogleFonts.manrope(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (p.sin.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      'Sin: ${p.sin.join(', ')}',
                      style: GoogleFonts.manrope(
                        color: AppColors.error.withValues(alpha: 0.9),
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Text(
            _formatearPrecio(p.subtotal),
            style: GoogleFonts.manrope(
              color: Colors.white70,
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
      iconBackground: Colors.white.withValues(alpha: 0.05),
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
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        ),
        child: Row(
          children: [
            const SkeletonBlock(width: 44, height: 44, borderRadius: 8),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  SkeletonBlock(height: 14, borderRadius: 4),
                  SizedBox(height: 8),
                  SkeletonBlock(width: 120, height: 10, borderRadius: 4),
                ],
              ),
            ),
            const SizedBox(width: 14),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: const [
                SkeletonBlock(width: 60, height: 14, borderRadius: 4),
                SizedBox(height: 8),
                SkeletonBlock(width: 70, height: 10, borderRadius: 4),
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        label.toUpperCase(),
        style: GoogleFonts.manrope(
          color: color,
          fontSize: 9,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.5,
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
        color: Colors.black.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
            color: Colors.white60,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: GoogleFonts.manrope(
              color: Colors.white70,
              fontSize: 11,
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
        color: Colors.white54,
        fontSize: 10,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.5,
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
          Expanded(child: Container(height: 1, color: Colors.white.withValues(alpha: 0.1))),
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
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
    _scale = Tween(
      begin: 0.6,
      end: 1.2,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
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
          boxShadow: [
            BoxShadow(
              color: widget.color.withValues(alpha: 0.6),
              blurRadius: 4,
              spreadRadius: 1,
            )
          ]
        ),
      ),
    );
  }
}
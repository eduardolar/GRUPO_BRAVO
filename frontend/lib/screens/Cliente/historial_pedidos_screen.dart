import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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
  bool _cargando = true;
  int _expandido = -1;

  @override
  void initState() {
    super.initState();
    _cargarPedidos();
  }

  Future<void> _cargarPedidos() async {
    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final userId = auth.usuarioActual?.id ?? '';
      final pedidos = await ApiService.obtenerHistorialPedidos(userId: userId);
      pedidos.sort((a, b) => b.fecha.compareTo(a.fecha));
      if (!mounted) return;
      setState(() {
        _pedidos = pedidos;
        _cargando = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _cargando = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al cargar pedidos: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  String _formatearFecha(String fecha) {
    try {
      final dt = DateTime.parse(fecha);
      return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return fecha;
    }
  }

  Color _colorEstado(String estado) {
    switch (estado) {
      case 'pendiente':
        return const Color(0xFFB45309);
      case 'preparando':
        return Colors.deepOrange;
      case 'listo':
        return const Color(0xFF2563EB);
      case 'entregado':
        return Colors.green;
      case 'cancelado':
        return Colors.redAccent;
      default:
        return AppColors.gold;
    }
  }

  IconData _iconoEstado(String estado) {
    switch (estado) {
      case 'pendiente':
        return Icons.pending_outlined;
      case 'preparando':
        return Icons.local_fire_department_outlined;
      case 'listo':
        return Icons.done_all;
      case 'entregado':
        return Icons.check_circle_outline;
      case 'cancelado':
        return Icons.cancel_outlined;
      default:
        return Icons.receipt_long;
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
          case 'domicilio': return 'Listo para envío';
          case 'recoger':   return 'Listo para recoger';
          default:          return 'Listo para servir';
        }
      case 'entregado':
        return 'Entregado';
      case 'cancelado':
        return 'Cancelado';
      default:
        return pedido.estado;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.gold),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'HISTORIAL DE PEDIDOS',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
            fontSize: 18,
          ),
        ),
      ),
      body: _cargando
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.button),
            )
          : _pedidos.isEmpty
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.receipt_long, color: AppColors.line, size: 60),
                  SizedBox(height: 16),
                  Text(
                    'No tienes pedidos aún',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _pedidos.length,
              itemBuilder: (context, index) {
                final pedido = _pedidos[index];
                final estaExpandido = _expandido == index;
                final colorEstado = _colorEstado(pedido.estado);

                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _expandido = estaExpandido ? -1 : index;
                    });
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.panel,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: estaExpandido
                            ? AppColors.gold.withValues(alpha: 0.5)
                            : AppColors.line,
                      ),
                    ),
                    child: Column(
                      children: [
                        // ── Cabecera ──
                        Row(
                          children: [
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: colorEstado.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                _iconoEstado(pedido.estado),
                                color: colorEstado,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _formatearFecha(pedido.fecha),
                                    style: const TextStyle(
                                      color: AppColors.textPrimary,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${pedido.items} artículos · ${_etiquetaEstado(pedido)}',
                                    style: TextStyle(
                                      color: AppColors.textSecondary
                                          .withValues(alpha: 0.7),
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  '${pedido.total.toStringAsFixed(2)} €',
                                  style: const TextStyle(
                                    color: AppColors.gold,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: colorEstado.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    _etiquetaEstado(pedido),
                                    style: TextStyle(
                                      color: colorEstado,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(width: 4),
                            AnimatedRotation(
                              turns: estaExpandido ? 0.5 : 0,
                              duration: const Duration(milliseconds: 300),
                              child: Icon(
                                Icons.expand_more,
                                color: AppColors.textSecondary.withValues(alpha: 0.5),
                                size: 22,
                              ),
                            ),
                          ],
                        ),

                        // ── Contenido expandido ──
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
                );
              },
            ),
    );
  }

  static const _estadosActivos = {'pendiente', 'preparando', 'listo'};

  Widget _buildDetalle(Pedido pedido, Color colorEstado) {
    final esActivo = _estadosActivos.contains(pedido.estado);
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Divider(color: AppColors.line.withValues(alpha: 0.5), height: 1),
          const SizedBox(height: 12),

          // ── Productos ──
          ...pedido.productos.map(
            (p) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Text(
                    '${p.cantidad}x',
                    style: const TextStyle(
                      color: AppColors.gold,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      p.nombre,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  Text(
                    '${p.subtotal.toStringAsFixed(2)} €',
                    style: TextStyle(
                      color: AppColors.textSecondary.withValues(alpha: 0.8),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 8),
          Divider(color: AppColors.line.withValues(alpha: 0.5), height: 1),
          const SizedBox(height: 10),

          // ── Info de entrega y pago ──
          _buildInfoRow(Icons.delivery_dining, pedido.tipoEntrega),
          const SizedBox(height: 6),
          _buildInfoRow(Icons.payment, pedido.metodoPago),
          if (pedido.direccion != null) ...[
            const SizedBox(height: 6),
            _buildInfoRow(Icons.location_on_outlined, pedido.direccion!),
          ],

          // ── Seguir pedido (solo activos) ──
          if (esActivo) ...[
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              height: 40,
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
                icon: const Icon(Icons.radar, size: 16),
                label: const Text(
                  'SEGUIR PEDIDO',
                  style: TextStyle(
                    fontFamily: 'Playfair Display',
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                    letterSpacing: 0.5,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.button,
                  foregroundColor: Colors.white,
                  elevation: 0,
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

  Widget _buildInfoRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.textSecondary.withValues(alpha: 0.6)),
        const SizedBox(width: 8),
        Text(
          text,
          style: TextStyle(
            color: AppColors.textSecondary.withValues(alpha: 0.8),
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:frontend/core/colors_style.dart';
import 'package:frontend/models/pedido_model.dart';
import 'package:frontend/providers/auth_provider.dart';
import 'package:frontend/services/api_service.dart';
import 'package:provider/provider.dart';

const _kBlue = Color(0xFF2563EB);

class PedidosListosScreen extends StatefulWidget {
  const PedidosListosScreen({super.key});

  @override
  State<PedidosListosScreen> createState() => _PedidosListosScreenState();
}

class _PedidosListosScreenState extends State<PedidosListosScreen> {
  List<Pedido> _pedidos = [];
  bool _cargando = true;
  Timer? _timer;
  final Set<String> _entregando = {};

  @override
  void initState() {
    super.initState();
    _cargar();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) => _cargar());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _cargar() async {
    try {
      final restauranteId = context
          .read<AuthProvider>()
          .usuarioActual
          ?.restauranteId;
      final todos = await ApiService.obtenerTodosLosPedidos(
        restauranteId: restauranteId,
        estado: 'listo',
      );
      // Filtro cliente como fallback: si el backend ignora el param estado,
      // garantizamos que solo aparecen los marcados como 'listo'.
      final listos = todos.where((p) => p.estado == 'listo').toList()
        ..sort((a, b) => a.fecha.compareTo(b.fecha));
      if (!mounted) return;
      setState(() {
        _pedidos = listos;
        _cargando = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _cargando = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al cargar pedidos: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _entregar(Pedido pedido) async {
    if (_entregando.contains(pedido.id)) return;
    setState(() => _entregando.add(pedido.id));
    try {
      await ApiService.actualizarEstadoPedido(
        pedidoId: pedido.id,
        estado: 'entregado',
      );
      await _cargar();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _entregando.remove(pedido.id));
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
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'PEDIDOS LISTOS',
              style: TextStyle(
                fontFamily: 'Playfair Display',
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.5,
                fontSize: 17,
              ),
            ),
            if (!_cargando && _pedidos.isNotEmpty) ...[
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: _kBlue.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _kBlue.withValues(alpha: 0.4)),
                ),
                child: Text(
                  '${_pedidos.length}',
                  style: const TextStyle(
                    color: _kBlue,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: IconButton(
              icon: const Icon(Icons.refresh, color: AppColors.button),
              tooltip: 'Actualizar',
              onPressed: () {
                setState(() => _cargando = true);
                _cargar();
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
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.button),
            )
          : _pedidos.isEmpty
          ? _buildVacio()
          : _buildLista(),
    );
  }

  Widget _buildVacio() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.check_circle_outline,
            size: 56,
            color: AppColors.textSecondary.withValues(alpha: 0.2),
          ),
          const SizedBox(height: 16),
          Text(
            'No hay pedidos listos',
            style: TextStyle(
              color: AppColors.textSecondary.withValues(alpha: 0.45),
              fontSize: 15,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Los pedidos marcados como listos\naparecerán aquí',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.textSecondary.withValues(alpha: 0.3),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLista() {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      itemCount: _pedidos.length,
      itemBuilder: (_, i) => _TarjetaPedidoListo(
        pedido: _pedidos[i],
        entregando: _entregando.contains(_pedidos[i].id),
        onEntregar: () => _entregar(_pedidos[i]),
      ),
    );
  }
}

// ── TARJETA ──────────────────────────────────────────────────────────────────

class _TarjetaPedidoListo extends StatelessWidget {
  final Pedido pedido;
  final bool entregando;
  final VoidCallback onEntregar;

  const _TarjetaPedidoListo({
    required this.pedido,
    required this.entregando,
    required this.onEntregar,
  });

  String get _etiqueta {
    switch (pedido.tipoEntrega) {
      case 'local':
        return 'Mesa ${pedido.numeroMesa ?? '-'}';
      case 'domicilio':
        return 'A domicilio';
      case 'recoger':
        return 'Para recoger';
      default:
        return pedido.tipoEntrega;
    }
  }

  IconData get _icono {
    switch (pedido.tipoEntrega) {
      case 'local':
        return Icons.table_restaurant_outlined;
      case 'domicilio':
        return Icons.delivery_dining_outlined;
      case 'recoger':
        return Icons.shopping_bag_outlined;
      default:
        return Icons.receipt_long_outlined;
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
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.panel,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _kBlue.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: entregando
          ? const Padding(
              padding: EdgeInsets.symmetric(vertical: 28),
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
                const Divider(height: 1, color: AppColors.line),
                _buildProductos(),
                if (pedido.notas != null && pedido.notas!.isNotEmpty)
                  _buildNotas(),
                const Divider(height: 1, color: AppColors.line),
                _buildAccion(),
              ],
            ),
    );
  }

  Widget _buildCabecera() {
    return Padding(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: _kBlue, width: 1.5),
            ),
            child: Icon(_icono, color: _kBlue, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _etiqueta,
                  style: const TextStyle(
                    fontFamily: 'Playfair Display',
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                Text(
                  _hora(pedido.fecha),
                  style: TextStyle(
                    color: AppColors.textSecondary.withValues(alpha: 0.6),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: _kBlue.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _kBlue.withValues(alpha: 0.3)),
            ),
            child: const Text(
              'LISTO',
              style: TextStyle(
                color: _kBlue,
                fontWeight: FontWeight.w700,
                fontSize: 10,
                letterSpacing: 1.2,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductos() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: pedido.productos.map((p) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 24,
                  height: 24,
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
                      fontSize: 11,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        p.nombre.isNotEmpty ? p.nombre : 'Producto',
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (p.sin.isNotEmpty)
                        Text(
                          'Sin: ${p.sin.join(', ')}',
                          style: TextStyle(
                            color: AppColors.textSecondary.withValues(
                              alpha: 0.6,
                            ),
                            fontSize: 11,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildNotas() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.line),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(
              Icons.notes_outlined,
              size: 13,
              color: AppColors.textSecondary,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                pedido.notas!,
                style: TextStyle(
                  color: AppColors.textSecondary.withValues(alpha: 0.8),
                  fontSize: 11,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAccion() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: SizedBox(
        width: double.infinity,
        height: 42,
        child: ElevatedButton.icon(
          onPressed: onEntregar,
          icon: const Icon(Icons.check_circle_outline, size: 16),
          label: const Text(
            'MARCAR COMO ENTREGADO',
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
              borderRadius: BorderRadius.circular(9),
            ),
          ),
        ),
      ),
    );
  }
}

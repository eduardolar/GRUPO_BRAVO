import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:frontend/components/bravo_app_bar.dart';
import '../../core/colors_style.dart';
import '../../models/pedido_model.dart';
import '../../services/pedido_service.dart';

class PedidosActivosScreen extends StatefulWidget {
  final String? restauranteId;
  final String restauranteNombre;

  const PedidosActivosScreen({
    super.key,
    this.restauranteId,
    this.restauranteNombre = 'Todas las sucursales',
  });

  @override
  State<PedidosActivosScreen> createState() => _PedidosActivosScreenState();
}

class _PedidosActivosScreenState extends State<PedidosActivosScreen> {
  List<Pedido> _pedidos = [];
  bool _cargando = true;
  String? _error;
  DateTime? _ultimaActualizacion;
  String _filtroEstado = 'activos';
  Timer? _timer;

  static const _intervaloRefresco = Duration(seconds: 30);
  static const _estadosActivos = {'pendiente', 'preparando', 'listo'};
  static const _prioridadEstado = {
    'pendiente': 0,
    'preparando': 1,
    'listo': 2,
    'entregado': 3,
    'cancelado': 4,
  };

  static const _etiquetas = {
    'activos': 'Activos',
    'todos': 'Todos',
    'pendiente': 'Pendiente',
    'preparando': 'Preparando',
    'listo': 'Listo',
    'entregado': 'Entregado',
    'cancelado': 'Cancelado',
  };

  static const _filtros = [
    'activos',
    'todos',
    'pendiente',
    'preparando',
    'listo',
    'entregado',
    'cancelado',
  ];

  @override
  void initState() {
    super.initState();
    _cargar();
    _timer = Timer.periodic(
      _intervaloRefresco,
      (_) => _cargar(silencioso: true),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _cargar({bool silencioso = false}) async {
    if (!silencioso) {
      setState(() {
        _cargando = true;
        _error = null;
      });
    }
    try {
      // No filtramos por fecha: los pedidos activos son los que están abiertos
      // ahora mismo, independientemente de cuándo se crearon. El limit actúa
      // como salvaguarda dura para no bloquear la UI en volúmenes altos.
      final datos = await PedidoService.obtenerTodosLosPedidos(
        restauranteId: (widget.restauranteId?.isEmpty ?? true)
            ? null
            : widget.restauranteId,
        limit: 1000,
      );
      if (!mounted) return;
      setState(() {
        _pedidos = datos;
        _cargando = false;
        _error = null;
        _ultimaActualizacion = DateTime.now();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _cargando = false;
        _error = e.toString();
      });
    }
  }

  List<Pedido> _aplicarFiltro() {
    List<Pedido> lista;
    if (_filtroEstado == 'todos') {
      lista = List.from(_pedidos);
    } else if (_filtroEstado == 'activos') {
      lista = _pedidos
          .where((p) => _estadosActivos.contains(p.estado.toLowerCase()))
          .toList();
    } else {
      lista = _pedidos
          .where((p) => p.estado.toLowerCase() == _filtroEstado)
          .toList();
    }

    // Ordenar: por prioridad de estado (pendiente primero) y luego por fecha descendente
    lista.sort((a, b) {
      final pa = _prioridadEstado[a.estado.toLowerCase()] ?? 99;
      final pb = _prioridadEstado[b.estado.toLowerCase()] ?? 99;
      if (pa != pb) return pa.compareTo(pb);
      return b.fecha.compareTo(a.fecha); // más reciente primero
    });

    return lista;
  }

  int _contarEstado(String estado) {
    if (estado == 'activos') {
      return _pedidos
          .where((p) => _estadosActivos.contains(p.estado.toLowerCase()))
          .length;
    }
    if (estado == 'todos') return _pedidos.length;
    return _pedidos.where((p) => p.estado.toLowerCase() == estado).length;
  }

  Color _colorEstado(String estado) {
    switch (estado.toLowerCase()) {
      case 'pendiente':
        return Colors.orange;
      case 'preparando':
        return Colors.blue;
      case 'listo':
        return Colors.greenAccent;
      case 'entregado':
        return Colors.green;
      case 'cancelado':
        return AppColors.error;
      default:
        return Colors.white70;
    }
  }

  IconData _iconoEstado(String estado) {
    switch (estado.toLowerCase()) {
      case 'pendiente':
        return Icons.hourglass_empty_rounded;
      case 'preparando':
        return Icons.restaurant_outlined;
      case 'listo':
        return Icons.check_circle_outline;
      case 'entregado':
        return Icons.done_all_rounded;
      case 'cancelado':
        return Icons.cancel_outlined;
      default:
        return Icons.circle_outlined;
    }
  }

  String _formatFecha(String fecha) {
    final dt = DateTime.tryParse(fecha);
    if (dt == null) return fecha;
    final hoy = DateTime.now();
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    if (dt.year == hoy.year && dt.month == hoy.month && dt.day == hoy.day) {
      return 'Hoy $h:$m';
    }
    return '${dt.day}/${dt.month} $h:$m';
  }

  String _formatHoraActualizacion() {
    if (_ultimaActualizacion == null) return '';
    final h = _ultimaActualizacion!.hour.toString().padLeft(2, '0');
    final m = _ultimaActualizacion!.minute.toString().padLeft(2, '0');
    final s = _ultimaActualizacion!.second.toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final lista = _aplicarFiltro();

    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: const BravoAppBar(title: 'PEDIDOS'),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/images/Bravo restaurante.jpg'),
            fit: BoxFit.cover,
          ),
        ),
        child: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withValues(alpha: 0.55),
                Colors.black.withValues(alpha: 0.88),
              ],
            ),
          ),
          child: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(),
                _buildFiltros(),
                if (_ultimaActualizacion != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 6, 20, 4),
                    child: Row(
                      children: [
                        Icon(
                          Icons.sync_rounded,
                          size: 11,
                          color: _cargando
                              ? AppColors.button
                              : Colors.white.withValues(alpha: 0.4),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          _cargando
                              ? 'Actualizando...'
                              : 'Actualizado ${_formatHoraActualizacion()} · refresca cada 30 s',
                          style: GoogleFonts.manrope(
                            fontSize: 10,
                            color: Colors.white.withValues(alpha: 0.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                Expanded(child: _buildCuerpo(lista)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCuerpo(List<Pedido> lista) {
    if (_cargando && _pedidos.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.button),
      );
    }
    if (_error != null && _pedidos.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.wifi_off_outlined,
              color: Colors.white.withValues(alpha: 0.4),
              size: 48,
            ),
            const SizedBox(height: 12),
            Text(
              'Error al cargar pedidos',
              style: GoogleFonts.manrope(color: Colors.white70),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: _cargar,
              child: Text(
                'Reintentar',
                style: GoogleFonts.manrope(color: AppColors.button),
              ),
            ),
          ],
        ),
      );
    }
    if (lista.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.receipt_long_outlined,
              size: 64,
              color: Colors.white.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 16),
            Text(
              _filtroEstado == 'activos'
                  ? 'No hay pedidos activos ahora mismo'
                  : 'No hay pedidos en este estado',
              style: GoogleFonts.manrope(color: Colors.white70, fontSize: 14),
            ),
            const SizedBox(height: 8),
            Text(
              'La pantalla se actualiza automáticamente',
              style: GoogleFonts.manrope(
                color: Colors.white.withValues(alpha: 0.5),
                fontSize: 12,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _cargar(),
      color: AppColors.button,
      backgroundColor: Colors.black,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
        itemCount: lista.length + 1,
        itemBuilder: (context, i) {
          if (i == 0) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 640),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${lista.length} pedido${lista.length != 1 ? 's' : ''}',
                        style: GoogleFonts.manrope(
                          color: Colors.white70,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      // Aviso si el backend devuelve exactamente el límite:
                      // significa que puede haber más pedidos sin mostrar.
                      if (_pedidos.length == 1000)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.warning_amber_rounded,
                                size: 13,
                                color: Colors.orangeAccent,
                              ),
                              const SizedBox(width: 5),
                              Flexible(
                                child: Text(
                                  'Mostrando los 1000 pedidos más recientes — algo puede ir mal si se llega a este tope',
                                  style: GoogleFonts.manrope(
                                    fontSize: 10,
                                    color: Colors.orangeAccent,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            );
          }
          final pedido = lista[i - 1];
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: _PedidoTile(
                pedido: pedido,
                colorEstado: _colorEstado(pedido.estado),
                iconoEstado: _iconoEstado(pedido.estado),
                fechaFormateada: _formatFecha(pedido.fecha),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Pedidos',
                  style: TextStyle(
                    fontFamily: 'Playfair Display',
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              IconButton(
                icon: _cargando
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 1.8,
                          color: AppColors.button,
                        ),
                      )
                    : Icon(
                        Icons.refresh_rounded,
                        color: Colors.white.withValues(alpha: 0.7),
                        size: 22,
                      ),
                tooltip: 'Refrescar ahora',
                onPressed: _cargando ? null : () => _cargar(),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Container(height: 2, width: 40, color: AppColors.button),
          const SizedBox(height: 8),
          Text(
            widget.restauranteNombre,
            style: GoogleFonts.manrope(
              color: Colors.white.withValues(alpha: 0.65),
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFiltros() {
    return SizedBox(
      height: 38,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        children: _filtros.map((f) {
          final selected = _filtroEstado == f;
          final count = _contarEstado(f);
          return GestureDetector(
            onTap: () => setState(() => _filtroEstado = f),
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: selected
                    ? AppColors.button
                    : Colors.white.withValues(alpha: 0.07),
                border: Border.all(
                  color: selected ? AppColors.button : Colors.white24,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _etiquetas[f] ?? f,
                    style: GoogleFonts.manrope(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: selected ? Colors.white : Colors.white70,
                    ),
                  ),
                  if (count > 0 && !_cargando) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: selected
                            ? Colors.white.withValues(alpha: 0.25)
                            : Colors.white.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '$count',
                        style: GoogleFonts.manrope(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: selected ? Colors.white : Colors.white70,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _PedidoTile extends StatelessWidget {
  final Pedido pedido;
  final Color colorEstado;
  final IconData iconoEstado;
  final String fechaFormateada;

  const _PedidoTile({
    required this.pedido,
    required this.colorEstado,
    required this.iconoEstado,
    required this.fechaFormateada,
  });

  String get _descripcionEntrega {
    final tipo = pedido.tipoEntrega.toLowerCase();
    if (tipo.contains('mesa') ||
        tipo.contains('local') ||
        tipo.contains('comer')) {
      return pedido.numeroMesa != null ? 'Mesa ${pedido.numeroMesa}' : 'Local';
    }
    if (tipo.contains('domicilio') || tipo.contains('delivery')) {
      return pedido.direccion?.isNotEmpty == true
          ? pedido.direccion!
          : 'A domicilio';
    }
    return pedido.tipoEntrega.isNotEmpty
        ? pedido.tipoEntrega
        : 'Sin especificar';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.45),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: colorEstado.withValues(alpha: 0.40),
                width: 1.5,
              ),
            ),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: colorEstado.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: colorEstado.withValues(alpha: 0.5),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(iconoEstado, size: 11, color: colorEstado),
                            const SizedBox(width: 5),
                            Text(
                              pedido.estado.toUpperCase(),
                              style: GoogleFonts.manrope(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: colorEstado,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _descripcionEntrega,
                          style: GoogleFonts.manrope(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            color: Colors.white,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '${pedido.total.toStringAsFixed(2)} €',
                            style: GoogleFonts.manrope(
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                              color: AppColors.button,
                            ),
                          ),
                          Text(
                            fechaFormateada,
                            style: GoogleFonts.manrope(
                              fontSize: 11,
                              color: Colors.white.withValues(alpha: 0.6),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  height: 1,
                  color: Colors.white.withValues(alpha: 0.10),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
                  child: Row(
                    children: [
                      Icon(
                        Icons.shopping_bag_outlined,
                        size: 13,
                        color: Colors.white.withValues(alpha: 0.6),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        '${pedido.items} artículo${pedido.items != 1 ? 's' : ''}',
                        style: GoogleFonts.manrope(
                          fontSize: 12,
                          color: Colors.white70,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Icon(
                        Icons.payment_outlined,
                        size: 13,
                        color: Colors.white.withValues(alpha: 0.6),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        pedido.metodoPago.isNotEmpty
                            ? pedido.metodoPago
                            : 'Sin especificar',
                        style: GoogleFonts.manrope(
                          fontSize: 12,
                          color: Colors.white70,
                        ),
                      ),
                      if (pedido.notas != null && pedido.notas!.isNotEmpty) ...[
                        const SizedBox(width: 12),
                        Icon(
                          Icons.notes_outlined,
                          size: 13,
                          color: Colors.orange.withValues(alpha: 0.7),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            pedido.notas!,
                            style: GoogleFonts.manrope(
                              fontSize: 11,
                              color: Colors.orange.withValues(alpha: 0.7),
                              fontStyle: FontStyle.italic,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

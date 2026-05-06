import 'package:flutter/material.dart';
import 'package:frontend/core/colors_style.dart';
import 'package:frontend/models/mesa_model.dart';
import 'package:frontend/providers/auth_provider.dart';
import 'package:frontend/services/api_service.dart';
import 'package:frontend/services/mesa_service.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'crear_comanda.dart';

class ModificarComanda extends StatefulWidget {
  const ModificarComanda({super.key});

  @override
  State<ModificarComanda> createState() => _ModificarComandaState();
}

class _ModificarComandaState extends State<ModificarComanda> {
  List<Mesa> _mesasOcupadas = [];
  bool _cargando = true;
  String? _mesaCargandoId;

  @override
  void initState() {
    super.initState();
    _cargarMesas();
  }

  Future<void> _cargarMesas() async {
    final restauranteId = context.read<AuthProvider>().usuarioActual?.restauranteId;
    try {
      final todas = await MesaService.obtenerMesas(restauranteId: restauranteId);
      if (!mounted) return;
      setState(() {
        _mesasOcupadas = todas.where((m) => !m.disponible).toList();
        _cargando = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _cargando = false);
    }
  }

  Future<void> _abrirComanda(Mesa mesa) async {
    setState(() => _mesaCargandoId = mesa.id);
    try {
      final pedido = await ApiService.obtenerPedidoActivoPorMesa(mesa.id);
      if (!mounted) return;
      setState(() => _mesaCargandoId = null);

      _mostrarDetalleComanda(mesa, pedido);
    } catch (_) {
      if (!mounted) return;
      setState(() => _mesaCargandoId = null);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('ERROR AL CARGAR EL PEDIDO'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(),
          margin: EdgeInsets.fromLTRB(16, 0, 16, 32),
        ),
      );
    }
  }

  void _mostrarDetalleComanda(Mesa mesa, Map<String, dynamic>? pedido) {
    final pedidoId = (pedido?['id'] ?? pedido?['_id'])?.toString();
    final productos = () {
      final raw = pedido?['productos'] ?? pedido?['items'];
      if (raw is List) return raw.cast<Map<String, dynamic>>();
      return <Map<String, dynamic>>[];
    }();
    final total = (pedido?['total'] as num?)?.toDouble() ?? 0.0;
    final parentContext = context;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _DetalleComandaSheet(
        mesa: mesa,
        pedidoId: pedidoId,
        productos: productos,
        total: total,
        parentContext: parentContext,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
                    Colors.black.withValues(alpha: 0.45),
                    Colors.black.withValues(alpha: 0.72),
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── AppBar ──────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back_ios_new,
                            color: AppColors.background, size: 18),
                        onPressed: () => Navigator.pop(context),
                      ),
                      Expanded(
                        child: Text(
                          'MODIFICAR COMANDA',
                          style: GoogleFonts.playfairDisplay(
                            color: AppColors.background,
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // ── Lista de mesas ──────────────────────────────
                Expanded(child: _buildCuerpo()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCuerpo() {
    if (_cargando) {
      return const Center(
        child: SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(
              color: AppColors.background, strokeWidth: 1.5),
        ),
      );
    }

    if (_mesasOcupadas.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.table_restaurant_outlined,
                size: 40, color: AppColors.background),
            const SizedBox(height: 14),
            const Text(
              'NO HAY CUENTAS ABIERTAS',
              style: TextStyle(
                color: AppColors.background,
                fontSize: 11,
                letterSpacing: 3.0,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            'SELECCIONA LA MESA',
            style: TextStyle(
              color: AppColors.background,
              fontSize: 11,
              letterSpacing: 2.5,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: RefreshIndicator(
            color: AppColors.button,
            backgroundColor: Colors.black,
            onRefresh: _cargarMesas,
            child: ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics()),
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
              itemCount: _mesasOcupadas.length,
              itemBuilder: (_, i) {
                final mesa = _mesasOcupadas[i];
                final cargando = _mesaCargandoId == mesa.id;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: cargando ? null : () => _abrirComanda(mesa),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 18),
                        decoration: BoxDecoration(
                          color: Colors.black45,
                          border:
                              Border.all(color: AppColors.background),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              color: AppColors.backgroundButton,
                              child: Center(
                                child: Text(
                                  '${mesa.numero}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'MESA ${mesa.numero}',
                                    style: const TextStyle(
                                      color: AppColors.background,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13,
                                      letterSpacing: 1.0,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    '${mesa.ubicacion.toUpperCase()} · ${mesa.capacidad} PAX',
                                    style: const TextStyle(
                                      color: AppColors.background,
                                      fontSize: 11,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            cargando
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                        color: AppColors.background,
                                        strokeWidth: 1.5),
                                  )
                                : const Icon(Icons.chevron_right,
                                    color: AppColors.background, size: 20),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}
// ─── Bottom sheet detalle de comanda ─────────────────────────────────────────

class _DetalleComandaSheet extends StatelessWidget {
  final Mesa mesa;
  final String? pedidoId;
  final List<Map<String, dynamic>> productos;
  final double total;
  final BuildContext parentContext;

  const _DetalleComandaSheet({
    required this.mesa,
    required this.pedidoId,
    required this.productos,
    required this.total,
    required this.parentContext,
  });

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.55,
      minChildSize: 0.35,
      maxChildSize: 0.90,
      expand: false,
      builder: (_, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFF111111),
            border: Border(
              top: BorderSide(color: Colors.white12, width: 1),
            ),
          ),
          child: Column(
            children: [
              // ── Handle ──────────────────────────────────────
              const SizedBox(height: 12),
              Center(
                child: Container(
                  width: 36,
                  height: 3,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // ── Cabecera ─────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      color: AppColors.backgroundButton,
                      child: Center(
                        child: Text(
                          '${mesa.numero}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
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
                            'MESA ${mesa.numero}',
                            style: const TextStyle(
                              color: AppColors.background,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.2,
                            ),
                          ),
                          Text(
                            '${mesa.ubicacion.toUpperCase()} · ${mesa.capacidad} PAX',
                            style: const TextStyle(
                              color: Colors.white38,
                              fontSize: 10,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // ── Botón modificar ───────────────────────
                    GestureDetector(
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.of(parentContext).push(
                          MaterialPageRoute(
                            builder: (_) => CrearComanda(
                              mesaId: mesa.id,
                              pedidoIdExistente: pedidoId,
                              productosExistentes: productos,
                              totalExistente: total,
                              onPedidoEnviado: () {
                                // Volver a ServicioTrabajador: pop CrearComanda y ModificarComanda
                                Navigator.of(parentContext).pop();
                                Navigator.of(parentContext).pop();
                              },
                            ),
                          ),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppColors.button,
                          borderRadius: BorderRadius.zero,
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.add, color: Colors.white, size: 14),
                            SizedBox(width: 6),
                            Text(
                              'AÑADIR',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),
              const Divider(color: Colors.white10, height: 1),

              // ── Lista de productos ────────────────────────────
              Expanded(
                child: productos.isEmpty
                    ? const Center(
                        child: Text(
                          'SIN PRODUCTOS',
                          style: TextStyle(
                            color: Colors.white38,
                            fontSize: 11,
                            letterSpacing: 2.5,
                          ),
                        ),
                      )
                    : ListView.separated(
                        controller: scrollController,
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                        itemCount: productos.length,
                        separatorBuilder: (_, _) =>
                            const Divider(color: Colors.white10, height: 1),
                        itemBuilder: (_, i) {
                          final item = productos[i];
                          final cantidad = (item['cantidad'] as num?)?.toInt() ?? 1;
                          final nombre = (item['nombre'] ?? '').toString();
                          final precio = (item['precio'] as num?)?.toDouble() ?? 0.0;
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            child: Row(
                              children: [
                                Text(
                                  '× $cantidad',
                                  style: TextStyle(
                                    color: AppColors.button,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    nombre,
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                                Text(
                                  '${(precio * cantidad).toStringAsFixed(2).replaceAll('.', ',')} €',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),

              // ── Total ─────────────────────────────────────────
              if (productos.isNotEmpty) ...[
                const Divider(color: Colors.white12, height: 1),
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'TOTAL ACUMULADO',
                        style: TextStyle(
                          color: Colors.white54,
                          fontSize: 11,
                          letterSpacing: 1.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        '${total.toStringAsFixed(2).replaceAll('.', ',')} €',
                        style: TextStyle(
                          color: AppColors.button,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
            ],
          ),
        );
      },
    );
  }
}
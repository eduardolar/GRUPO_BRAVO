import 'dart:async';

import 'package:flutter/material.dart';
import 'package:frontend/core/app_routes.dart';
import 'package:frontend/core/app_snackbar.dart';
import 'package:frontend/core/colors_style.dart';
import 'package:frontend/models/ingrediente_model.dart';
import 'package:frontend/providers/auth_provider.dart';
import 'package:frontend/screens/trabajador/appbar_trabajador.dart';
import 'package:frontend/services/api_service.dart';
import 'package:frontend/services/aviso_falta_service.dart';
import 'package:frontend/services/ingredientes_service.dart';
import 'package:provider/provider.dart';

class GestionStock extends StatelessWidget {
  const GestionStock({super.key});

  @override
  Widget build(BuildContext context) => const _StockBody();
}

// ─────────────────────────────────────────────────────────────────────────────
// CONTENIDO PRINCIPAL — Lista de ingredientes con acciones inline
// ─────────────────────────────────────────────────────────────────────────────
class _StockBody extends StatefulWidget {
  const _StockBody();

  @override
  State<_StockBody> createState() => _StockBodyState();
}

class _StockBodyState extends State<_StockBody> {
  List<Ingrediente> _todos = [];
  bool _cargando = true;
  String _busqueda = '';
  // Ids de filas que están procesando una acción ahora mismo (spinner inline).
  final Set<String> _procesando = {};

  late final TextEditingController _searchCtrl;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _searchCtrl = TextEditingController();
    _searchCtrl.addListener(_onSearchChanged);
    _cargar();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () {
      if (!mounted) return;
      setState(() => _busqueda = _searchCtrl.text.trim().toLowerCase());
    });
  }

  Future<void> _cargar() async {
    final restauranteId =
        context.read<AuthProvider>().usuarioActual?.restauranteId;
    setState(() => _cargando = true);
    try {
      final lista = await ApiService.obtenerIngredientes(
        restauranteId: restauranteId,
      );
      if (!mounted) return;
      // Ordenamos por nombre para que el camarero encuentre rápido.
      lista.sort(
        (a, b) =>
            a.nombre.toLowerCase().compareTo(b.nombre.toLowerCase()),
      );
      setState(() {
        _todos = lista;
        _cargando = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _cargando = false);
      handleApiError(context, e, prefix: 'Error al cargar stock');
    }
  }

  List<Ingrediente> get _filtrados {
    if (_busqueda.isEmpty) return _todos;
    return _todos
        .where((i) => i.nombre.toLowerCase().contains(_busqueda))
        .toList();
  }

  // ── Acciones ──────────────────────────────────────────────────

  Future<void> _agotar(Ingrediente ing) async {
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.panel,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Text(
          '¿Marcar "${ing.nombre}" como agotado?',
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: const Text(
          'El stock pasará a 0 y los platos que lo usen quedarán no '
          'disponibles automáticamente. La operación es inmediata.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(
              'CANCELAR',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              shape: const RoundedRectangleBorder(),
              padding: const EdgeInsets.symmetric(
                horizontal: 18,
                vertical: 10,
              ),
            ),
            child: const Text(
              'AGOTAR',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
              ),
            ),
          ),
        ],
      ),
    );
    if (confirmado != true || !mounted) return;

    setState(() => _procesando.add(ing.id));
    try {
      await IngredienteService.ponerStockACero(ing.id);
      if (!mounted) return;
      // Refrescamos la cantidad localmente sin recargar toda la lista.
      setState(() {
        final idx = _todos.indexWhere((i) => i.id == ing.id);
        if (idx >= 0) {
          _todos[idx] = _todos[idx].copyWith(cantidadActual: 0);
        }
        _procesando.remove(ing.id);
      });
      showAppSuccess(context, '"${ing.nombre}" marcado como agotado');
    } catch (e) {
      if (!mounted) return;
      setState(() => _procesando.remove(ing.id));
      handleApiError(context, e, prefix: 'No se pudo agotar');
    }
  }

  Future<void> _avisar(Ingrediente ing) async {
    final notasCtrl = TextEditingController();
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.panel,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Text(
          'Avisar falta de "${ing.nombre}"',
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Se enviará un aviso al admin para que reabastezca. '
              'No cambia el stock actual.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: notasCtrl,
              maxLines: 3,
              maxLength: 200,
              decoration: InputDecoration(
                labelText: 'Notas (opcional)',
                hintText: 'Ej: queda muy poco, urgente para el servicio',
                hintStyle: const TextStyle(color: AppColors.textSecondary),
                filled: true,
                fillColor: AppColors.background,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(
              'CANCELAR',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.button,
              shape: const RoundedRectangleBorder(),
              padding: const EdgeInsets.symmetric(
                horizontal: 18,
                vertical: 10,
              ),
            ),
            child: const Text(
              'ENVIAR',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
              ),
            ),
          ),
        ],
      ),
    );
    final notas = notasCtrl.text.trim();
    notasCtrl.dispose();
    if (confirmado != true || !mounted) return;

    setState(() => _procesando.add(ing.id));
    try {
      await AvisoFaltaService.crear(
        nombre: ing.nombre,
        ingredienteId: ing.id,
        notas: notas.isNotEmpty ? notas : null,
      );
      if (!mounted) return;
      setState(() => _procesando.remove(ing.id));
      showAppSuccess(context, 'Aviso enviado al admin');
    } catch (e) {
      if (!mounted) return;
      setState(() => _procesando.remove(ing.id));
      handleApiError(context, e, prefix: 'No se pudo enviar el aviso');
    }
  }

  // ── Build ─────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: const TrabajadorAppBar(title: 'GESTIÓN DE STOCK'),
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
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withValues(alpha: 0.5),
                Colors.black.withValues(alpha: 0.92),
              ],
            ),
          ),
          child: SafeArea(
            child: FadeSlideIn(
              child: Column(
                children: [
                  const SizedBox(height: kToolbarHeight + 12),
                  _buildBuscador(),
                  Expanded(
                    child: _cargando
                        ? const Center(
                            child: CircularProgressIndicator(
                              color: AppColors.button,
                            ),
                          )
                        : _filtrados.isEmpty
                        ? _buildEmpty()
                        : RefreshIndicator(
                            onRefresh: _cargar,
                            color: AppColors.button,
                            child: ListView.separated(
                              padding: const EdgeInsets.fromLTRB(
                                16,
                                8,
                                16,
                                32,
                              ),
                              itemCount: _filtrados.length,
                              separatorBuilder: (_, _) =>
                                  const SizedBox(height: 8),
                              itemBuilder: (_, i) => _IngredienteRow(
                                ing: _filtrados[i],
                                procesando: _procesando.contains(
                                  _filtrados[i].id,
                                ),
                                onAvisar: () => _avisar(_filtrados[i]),
                                onAgotar: () => _agotar(_filtrados[i]),
                              ),
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBuscador() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: TextField(
        controller: _searchCtrl,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: 'Buscar ingrediente...',
          hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
          prefixIcon: Icon(
            Icons.search,
            color: Colors.white.withValues(alpha: 0.6),
            size: 20,
          ),
          suffixIcon: _searchCtrl.text.isNotEmpty
              ? IconButton(
                  tooltip: 'Limpiar búsqueda',
                  icon: Icon(
                    Icons.close,
                    color: Colors.white.withValues(alpha: 0.6),
                    size: 18,
                  ),
                  onPressed: () => _searchCtrl.clear(),
                )
              : null,
          filled: true,
          fillColor: Colors.black.withValues(alpha: 0.4),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 8,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: Colors.white.withValues(alpha: 0.15),
              width: 1.2,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: AppColors.button.withValues(alpha: 0.7),
              width: 1.5,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.inventory_2_outlined,
              size: 48,
              color: Colors.white.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 14),
            Text(
              _busqueda.isEmpty
                  ? 'NO HAY INGREDIENTES'
                  : 'SIN RESULTADOS PARA "${_busqueda.toUpperCase()}"',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6),
                fontSize: 12,
                letterSpacing: 2.5,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Fila por ingrediente — info + botones AVISAR / AGOTAR
// ─────────────────────────────────────────────────────────────────────────────
class _IngredienteRow extends StatelessWidget {
  final Ingrediente ing;
  final bool procesando;
  final VoidCallback onAvisar;
  final VoidCallback onAgotar;

  const _IngredienteRow({
    required this.ing,
    required this.procesando,
    required this.onAvisar,
    required this.onAgotar,
  });

  bool get _agotado => ing.cantidadActual <= 0;
  bool get _bajoMinimo =>
      !_agotado && ing.cantidadActual <= ing.stockMinimo;

  Color get _colorChip {
    if (_agotado) return AppColors.error;
    if (_bajoMinimo) return AppColors.warningLight;
    return AppColors.button;
  }

  String get _labelChip {
    if (_agotado) return 'AGOTADO';
    if (_bajoMinimo) return 'BAJO';
    return 'OK';
  }

  IconData get _iconChip {
    if (_agotado) return Icons.block;
    if (_bajoMinimo) return Icons.warning_amber_outlined;
    return Icons.check_circle_outline;
  }

  String get _semanticsChip {
    if (_agotado) return 'Agotado';
    if (_bajoMinimo) return 'Stock bajo';
    return 'Stock correcto';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.15),
          width: 1.2,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cabecera: nombre + chip estado
            Row(
              children: [
                Expanded(
                  child: Text(
                    ing.nombre,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Semantics(
                  label: _semanticsChip,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: _colorChip.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: _colorChip.withValues(alpha: 0.5),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _iconChip,
                          color: _colorChip == AppColors.button
                              ? Colors.white
                              : _colorChip,
                          size: 10,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _labelChip,
                          style: TextStyle(
                            color: _colorChip == AppColors.button
                                ? Colors.white
                                : _colorChip,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '${ing.cantidadActual} ${ing.unidad} · mínimo: ${ing.stockMinimo}',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.65),
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 10),
            // Acciones inline
            Row(
              children: [
                if (procesando)
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.button,
                    ),
                  ),
                if (procesando) const Spacer(),
                if (!procesando) ...[
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onAvisar,
                      icon: const Icon(Icons.warning_amber_outlined, size: 16),
                      label: const Text(
                        'AVISAR',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.2,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        backgroundColor: AppColors.button.withValues(
                          alpha: 0.25,
                        ),
                        side: BorderSide(
                          color: AppColors.button.withValues(alpha: 0.7),
                          width: 1,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // El botón AGOTAR solo tiene sentido si aún hay stock.
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _agotado ? null : onAgotar,
                      icon: const Icon(Icons.block, size: 16),
                      label: const Text(
                        'AGOTAR',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.2,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.error,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: Colors.white.withValues(
                          alpha: 0.08,
                        ),
                        disabledForegroundColor: Colors.white.withValues(
                          alpha: 0.35,
                        ),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

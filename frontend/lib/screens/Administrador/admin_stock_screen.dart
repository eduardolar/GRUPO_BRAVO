import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:frontend/core/colors_style.dart';
import 'package:frontend/models/ingrediente_model.dart';
import 'package:frontend/providers/auth_provider.dart';
import 'package:frontend/screens/Administrador/admin_duplicados_screen.dart';
import 'package:frontend/services/ingredientes_service.dart';
import 'package:provider/provider.dart';

// ─── Constants ────────────────────────────────────────────────────────────────

const _kSheetBg = Color(0xFF1A1A1A);
const _kFieldFill = Color(0x12FFFFFF);
const _kBorder = Color(0x33FFFFFF);

// ─── Screen ───────────────────────────────────────────────────────────────────

class AdminStockScreen extends StatefulWidget {
  const AdminStockScreen({super.key});

  @override
  State<AdminStockScreen> createState() => _AdminStockScreenState();
}

class _AdminStockScreenState extends State<AdminStockScreen> {
  List<Ingrediente> _todos = [];
  bool _cargando = true;
  String? _errorCarga;
  String _categoriaActiva = 'Todos';
  String _busqueda = '';
  final _busquedaCtrl = TextEditingController();
  String? _restauranteId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _restauranteId = context
          .read<AuthProvider>()
          .usuarioActual
          ?.restauranteId;
      _cargar();
    });
  }

  @override
  void dispose() {
    _busquedaCtrl.dispose();
    super.dispose();
  }

  Future<void> _cargar() async {
    if (!mounted) return;
    setState(() {
      _cargando = true;
      _errorCarga = null;
    });
    try {
      final lista = await IngredienteService.obtenerIngredientes(
        restauranteId: _restauranteId,
      );
      if (!mounted) return;
      final seen = <String>{};
      setState(() {
        _todos = lista.where((i) => i.id.isNotEmpty && seen.add(i.id)).toList();
        _cargando = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _cargando = false;
        _errorCarga = e.toString();
      });
    }
  }

  List<String> get _categorias {
    // Mostramos SIEMPRE las categorías oficiales (las del IngredienteService),
    // estén vacías o no — así el admin puede filtrar por "Otros" para mover
    // ingredientes aunque no haya ninguno todavía, y se ven las canónicas con
    // sus tildes correctas. Después añadimos las "huérfanas": categorías que
    // aparecen en BD pero NO están en la lista canónica (typos legacy como
    // "Panaderia" sin tilde, "Reposteria"...). Así el admin las ve y puede
    // limpiar sus ingredientes hacia la canónica correspondiente.
    final canonicas = IngredienteService.categorias;
    final usadas = _todos.map((i) => i.categoria).toSet();
    final huerfanas = usadas.where((c) => !canonicas.contains(c)).toList()
      ..sort();
    return ['Todos', ...canonicas, ...huerfanas];
  }

  List<Ingrediente> get _filtrados {
    var lista = List<Ingrediente>.from(_todos);
    if (_categoriaActiva != 'Todos') {
      lista = lista.where((i) => i.categoria == _categoriaActiva).toList();
    }
    if (_busqueda.isNotEmpty) {
      lista = lista
          .where((i) => i.nombre.toLowerCase().contains(_busqueda))
          .toList();
    }
    lista.sort((a, b) {
      final aLow = a.stockMinimo > 0 && a.cantidadActual <= a.stockMinimo;
      final bLow = b.stockMinimo > 0 && b.cantidadActual <= b.stockMinimo;
      if (aLow && !bLow) return -1;
      if (!aLow && bLow) return 1;
      return a.nombre.compareTo(b.nombre);
    });
    return lista;
  }

  int get _conteoStockBajo => _todos
      .where((i) => i.stockMinimo > 0 && i.cantidadActual <= i.stockMinimo)
      .length;

  Future<void> _abrirEditor({Ingrediente? ingrediente}) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _EditorIngredienteSheet(
        ingrediente: ingrediente,
        restauranteId: _restauranteId,
        onGuardado: _cargar,
      ),
    );
  }

  /// Atajo desde la card del ingrediente: abre un sheet con todas las
  /// categorías disponibles. Al pulsar una, hace PUT y recarga la lista.
  /// Útil para reasignar masivamente los ingredientes que quedaron en "Otros".
  Future<void> _moverCategoria(Ingrediente ing) async {
    final nueva = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: _kSheetBg,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(ctx).size.height * 0.7,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Mover "${ing.nombre}" a…',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 18,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.fromLTRB(20, 0, 20, 8),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Selecciona la nueva categoría',
                      style: TextStyle(color: Colors.white54, fontSize: 13),
                    ),
                  ),
                ),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
                    itemCount: IngredienteService.categorias.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (_, i) {
                      final cat = IngredienteService.categorias[i];
                      final actual = cat == ing.categoria;
                      return InkWell(
                        onTap: actual ? null : () => Navigator.pop(ctx, cat),
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          constraints: const BoxConstraints(minHeight: 60),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                          decoration: BoxDecoration(
                            color: actual
                                ? Colors.white.withValues(alpha: 0.04)
                                : Colors.white.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: actual
                                  ? AppColors.button
                                  : Colors.white.withValues(alpha: 0.15),
                              width: actual ? 1.5 : 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  cat,
                                  style: TextStyle(
                                    color: actual
                                        ? Colors.white38
                                        : Colors.white,
                                    fontWeight: actual
                                        ? FontWeight.w500
                                        : FontWeight.w600,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                              if (actual)
                                const Text(
                                  'Actual',
                                  style: TextStyle(
                                    color: AppColors.button,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
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
      },
    );

    if (nueva == null || nueva == ing.categoria) return;

    try {
      await IngredienteService.actualizarIngrediente(ing.id, {
        'categoria': nueva,
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('"${ing.nombre}" movido a $nueva'),
          backgroundColor: AppColors.disp,
        ),
      );
      await _cargar();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtrados = _filtrados;
    final bajoCant = _conteoStockBajo;

    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'INVENTARIO',
          style: TextStyle(
            color: AppColors.textAppBar,
            fontWeight: FontWeight.w700,
            fontSize: 16,
            letterSpacing: 0.5,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.auto_fix_high),
            tooltip: 'Limpiar duplicados',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const AdminDuplicadosScreen(),
              ),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: Container(
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
                      Colors.black.withValues(alpha: 0.55),
                      Colors.black.withValues(alpha: 0.9),
                    ],
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildStatsRow(bajoCant),
                _buildSearchBar(),
                _buildCategoryChips(),
                Expanded(
                  child: _cargando
                      ? const Center(
                          child: CircularProgressIndicator(
                            color: AppColors.button,
                          ),
                        )
                      : _errorCarga != null
                      ? _buildErrorState()
                      : filtrados.isEmpty
                      ? _buildEmpty()
                      : RefreshIndicator(
                          color: AppColors.button,
                          onRefresh: _cargar,
                          child: ListView.builder(
                            padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
                            itemCount: filtrados.length,
                            itemBuilder: (_, i) => _IngredienteCard(
                              ingrediente: filtrados[i],
                              onTap: () =>
                                  _abrirEditor(ingrediente: filtrados[i]),
                              onMoverCategoria: () =>
                                  _moverCategoria(filtrados[i]),
                            ),
                          ),
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'fab-stock',
        onPressed: () => _abrirEditor(),
        backgroundColor: AppColors.button,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Nuevo ingrediente'),
      ),
    );
  }

  Widget _buildStatsRow(int bajoCant) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Row(
        children: [
          _StatChip(
            icon: Icons.inventory_2_outlined,
            label: '${_todos.length}',
            sublabel: 'ingredientes',
            color: Colors.white70,
          ),
          const SizedBox(width: 10),
          _StatChip(
            icon: Icons.warning_amber_rounded,
            label: '$bajoCant',
            sublabel: 'bajo mínimo',
            color: bajoCant > 0 ? AppColors.error : Colors.white38,
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Container(
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
            ),
            child: TextField(
              controller: _busquedaCtrl,
              cursorColor: AppColors.button,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              onChanged: (v) => setState(() => _busqueda = v.toLowerCase()),
              decoration: InputDecoration(
                hintText: 'Buscar ingrediente...',
                hintStyle: const TextStyle(color: Colors.white70, fontSize: 14),
                prefixIcon: const Icon(
                  Icons.search,
                  color: Colors.white60,
                  size: 20,
                ),
                suffixIcon: _busqueda.isNotEmpty
                    ? IconButton(
                        icon: const Icon(
                          Icons.clear,
                          color: Colors.white60,
                          size: 18,
                        ),
                        onPressed: () {
                          _busquedaCtrl.clear();
                          setState(() => _busqueda = '');
                        },
                      )
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildChip(String cat) {
    final selected = cat == _categoriaActiva;
    return InkWell(
      onTap: () => setState(() => _categoriaActiva = cat),
      borderRadius: BorderRadius.circular(22),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        // Pildora más alta y con más padding horizontal: hace falta al menos
        // 44 px de área para evitar pulsaciones erróneas (guideline Material).
        constraints: const BoxConstraints(minHeight: 44),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.button
              : Colors.black.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: selected
                ? AppColors.button
                : Colors.white.withValues(alpha: 0.3),
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          cat,
          style: TextStyle(
            color: selected ? Colors.white : Colors.white70,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  Future<void> _abrirSelectorCategoria() async {
    final elegida = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: _kSheetBg,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(ctx).size.height * 0.7,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(20, 16, 20, 8),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Filtrar por categoría',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 18,
                      ),
                    ),
                  ),
                ),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
                    itemCount: _categorias.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (_, i) {
                      final cat = _categorias[i];
                      final selected = cat == _categoriaActiva;
                      return InkWell(
                        onTap: () => Navigator.pop(ctx, cat),
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          // Altura cómoda al pulsar (>= 56 px guideline Material).
                          constraints: const BoxConstraints(minHeight: 60),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                          decoration: BoxDecoration(
                            color: selected
                                ? AppColors.button.withValues(alpha: 0.18)
                                : Colors.white.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: selected
                                  ? AppColors.button
                                  : Colors.white.withValues(alpha: 0.15),
                              width: selected ? 1.5 : 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  cat,
                                  style: TextStyle(
                                    color: selected
                                        ? AppColors.button
                                        : Colors.white,
                                    fontWeight: selected
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                              if (selected)
                                const Icon(
                                  Icons.check_circle,
                                  color: AppColors.button,
                                  size: 22,
                                ),
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
      },
    );
    if (elegida != null && mounted) {
      setState(() => _categoriaActiva = elegida);
    }
  }

  Widget _buildCategoryDropdown() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _abrirSelectorCategoria,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            // Altura cómoda al pulsar; antes era ~38 px y se erraba al tocar.
            constraints: const BoxConstraints(minHeight: 56),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.filter_list,
                  color: AppColors.button,
                  size: 22,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _categoriaActiva,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const Icon(
                  Icons.keyboard_arrow_down,
                  color: Colors.white70,
                  size: 24,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryChips() {
    // En pantallas estrechas mostramos un desplegable compacto en lugar de
    // chips: ahorra espacio vertical y deja la lista de ingredientes con más
    // sitio. En pantallas anchas mantenemos los chips con scroll horizontal.
    final esEstrecha = MediaQuery.of(context).size.width < 600;
    if (esEstrecha) return _buildCategoryDropdown();

    final List<Widget> chips = _categorias.map(_buildChip).toList();

    return SizedBox(
      height: 64,
      child: Stack(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: chips
                  .map(
                    (c) => Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 5),
                      child: c,
                    ),
                  )
                  .toList(),
            ),
          ),
          // Gradiente derecho que indica que hay más chips fuera de pantalla.
          Positioned(
            right: 0,
            top: 0,
            bottom: 0,
            width: 32,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.6),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.inventory_2_outlined,
            size: 52,
            color: Colors.white24,
          ),
          const SizedBox(height: 12),
          Text(
            _busqueda.isNotEmpty
                ? 'Sin resultados para "$_busqueda"'
                : 'No hay ingredientes en esta categoría',
            style: const TextStyle(color: Colors.white60),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 52, color: AppColors.error),
            const SizedBox(height: 12),
            const Text(
              'No se pudo cargar el inventario',
              style: TextStyle(color: Colors.white),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              _errorCarga ?? '',
              style: const TextStyle(color: Colors.white54, fontSize: 12),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _cargar,
              icon: const Icon(Icons.refresh),
              label: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Stat Chip ────────────────────────────────────────────────────────────────

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String sublabel;
  final Color color;

  const _StatChip({
    required this.icon,
    required this.label,
    required this.sublabel,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 16),
              const SizedBox(width: 6),
              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: '$label ',
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                    TextSpan(
                      text: sublabel,
                      style: const TextStyle(
                        color: Colors.white38,
                        fontSize: 12,
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
}

// ─── Ingredient Card ──────────────────────────────────────────────────────────

class _IngredienteCard extends StatelessWidget {
  final Ingrediente ingrediente;
  final VoidCallback onTap;
  // Callback opcional para "mover a otra categoría" sin entrar al editor
  // completo. Si es null, no se muestra el botón.
  final VoidCallback? onMoverCategoria;

  const _IngredienteCard({
    required this.ingrediente,
    required this.onTap,
    this.onMoverCategoria,
  });

  @override
  Widget build(BuildContext context) {
    final ing = ingrediente;
    final hasMin = ing.stockMinimo > 0;
    final isBajo = hasMin && ing.cantidadActual <= ing.stockMinimo;
    final isJusto =
        hasMin &&
        ing.cantidadActual > ing.stockMinimo &&
        ing.cantidadActual <= ing.stockMinimo * 1.5;

    final double ratio = hasMin
        ? (ing.cantidadActual / (ing.stockMinimo * 2)).clamp(0.0, 1.0)
        : 1.0;

    final Color barColor = isBajo
        ? AppColors.error
        : isJusto
        ? Colors.amber.shade400
        : AppColors.disp;

    final String? badge = isBajo
        ? 'BAJO'
        : isJusto
        ? 'JUSTO'
        : null;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GestureDetector(
        onTap: onTap,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isBajo
                      ? AppColors.error.withValues(alpha: 0.5)
                      : Colors.white.withValues(alpha: 0.12),
                  width: 1.5,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: AppColors.button.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: AppColors.button.withValues(alpha: 0.35),
                          ),
                        ),
                        child: Icon(
                          _iconForCategory(ing.categoria),
                          color: AppColors.button,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              ing.nombre,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              ing.categoria,
                              style: const TextStyle(
                                color: Colors.white54,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (badge != null) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color:
                                (isBajo
                                        ? AppColors.error
                                        : Colors.amber.shade700)
                                    .withValues(alpha: 0.9),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            badge,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                      ],
                      if (onMoverCategoria != null) ...[
                        Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: onMoverCategoria,
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.button.withValues(alpha: 0.18),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: AppColors.button.withValues(
                                    alpha: 0.4,
                                  ),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: const [
                                  Icon(
                                    Icons.drive_file_move_outline,
                                    color: AppColors.button,
                                    size: 16,
                                  ),
                                  SizedBox(width: 4),
                                  Text(
                                    'Mover',
                                    style: TextStyle(
                                      color: AppColors.button,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 11,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                      ],
                      const Icon(
                        Icons.chevron_right,
                        color: Colors.white30,
                        size: 18,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: ratio,
                      minHeight: 6,
                      backgroundColor: Colors.white.withValues(alpha: 0.1),
                      valueColor: AlwaysStoppedAnimation<Color>(barColor),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Text(
                        '${_fmt(ing.cantidadActual)} ${ing.unidad}',
                        style: TextStyle(
                          color: barColor,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                      const Spacer(),
                      if (hasMin)
                        Text(
                          'Mín: ${_fmt(ing.stockMinimo)} ${ing.unidad}',
                          style: const TextStyle(
                            color: Colors.white38,
                            fontSize: 12,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _fmt(double v) =>
      v % 1 == 0 ? v.toInt().toString() : v.toStringAsFixed(1);

  IconData _iconForCategory(String cat) {
    switch (cat.toLowerCase()) {
      case 'carnes':
        return Icons.lunch_dining;
      case 'mariscos y pescados':
        return Icons.set_meal;
      case 'verduras':
        return Icons.eco;
      case 'lácteos':
        return Icons.water_drop;
      case 'panadería':
        return Icons.bakery_dining;
      case 'salsas y condimentos':
        return Icons.soup_kitchen;
      case 'especias':
        return Icons.spa;
      case 'almidones y cereales':
        return Icons.grain;
      case 'huevos':
        return Icons.egg;
      case 'frutas':
        return Icons.apple;
      default:
        return Icons.inventory_2;
    }
  }
}

// ─── Editor Modal ─────────────────────────────────────────────────────────────

class _EditorIngredienteSheet extends StatefulWidget {
  final Ingrediente? ingrediente;
  final String? restauranteId;
  final VoidCallback onGuardado;

  const _EditorIngredienteSheet({
    this.ingrediente,
    this.restauranteId,
    required this.onGuardado,
  });

  @override
  State<_EditorIngredienteSheet> createState() =>
      _EditorIngredienteSheetState();
}

class _EditorIngredienteSheetState extends State<_EditorIngredienteSheet> {
  final _formKey = GlobalKey<FormState>();
  bool _guardando = false;

  late final TextEditingController _nombreCtrl;
  late final TextEditingController _cantidadCtrl;
  late final TextEditingController _minimoCtrl;
  late String _categoria;
  late String _unidad;

  bool get _esEdicion => widget.ingrediente != null;

  @override
  void initState() {
    super.initState();
    final ing = widget.ingrediente;
    _nombreCtrl = TextEditingController(text: ing?.nombre ?? '');
    _cantidadCtrl = TextEditingController(
      text: ing != null ? _fmt(ing.cantidadActual) : '',
    );
    _minimoCtrl = TextEditingController(
      text: ing != null ? _fmt(ing.stockMinimo) : '',
    );
    final ingCat = ing?.categoria;
    _categoria =
        ingCat != null && IngredienteService.categorias.contains(ingCat)
        ? ingCat
        : IngredienteService.categorias.first;
    final ingUnidad = ing?.unidad;
    _unidad =
        ingUnidad != null && IngredienteService.unidades.contains(ingUnidad)
        ? ingUnidad
        : 'kg';
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _cantidadCtrl.dispose();
    _minimoCtrl.dispose();
    super.dispose();
  }

  String _fmt(double v) =>
      v % 1 == 0 ? v.toInt().toString() : v.toStringAsFixed(1);

  double get _step {
    switch (_unidad) {
      case 'g':
        return 100;
      case 'unidades':
        return 1;
      default:
        return 0.5;
    }
  }

  void _adjustQuantity(double delta) {
    final current = double.tryParse(_cantidadCtrl.text) ?? 0;
    final next = (current + delta).clamp(0.0, double.infinity);
    _cantidadCtrl.text = _fmt(next);
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _guardando = true);
    try {
      final cantidad = double.parse(_cantidadCtrl.text);
      final minimo = double.parse(_minimoCtrl.text);
      if (_esEdicion) {
        await IngredienteService.actualizarIngrediente(widget.ingrediente!.id, {
          'nombre': _nombreCtrl.text.trim(),
          'categoria': _categoria,
          'cantidadActual': cantidad,
          'unidad': _unidad,
          'stockMinimo': minimo,
        });
      } else {
        await IngredienteService.crearIngrediente({
          'nombre': _nombreCtrl.text.trim(),
          'categoria': _categoria,
          'cantidadActual': cantidad,
          'unidad': _unidad,
          'stockMinimo': minimo,
          if (widget.restauranteId != null)
            'restauranteId': widget.restauranteId,
        });
      }
      widget.onGuardado();
      if (mounted) Navigator.pop(context);
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
      if (mounted) setState(() => _guardando = false);
    }
  }

  Future<void> _eliminar() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _kSheetBg,
        titleTextStyle: const TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
        contentTextStyle: const TextStyle(color: Colors.white70),
        title: const Text('Eliminar ingrediente'),
        content: Text(
          '¿Eliminar "${widget.ingrediente!.nombre}"? Esta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(
              'Cancelar',
              style: TextStyle(color: Colors.white60),
            ),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmar != true) return;
    try {
      await IngredienteService.eliminarIngrediente(widget.ingrediente!.id);
      widget.onGuardado();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  InputDecoration _fieldDec(String label, {Widget? suffix}) => InputDecoration(
    labelText: label,
    labelStyle: const TextStyle(color: Colors.white60, fontSize: 13),
    filled: true,
    fillColor: _kFieldFill,
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: _kBorder),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: AppColors.button, width: 2),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: AppColors.error),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: AppColors.error, width: 2),
    ),
    suffixIcon: suffix,
  );

  @override
  Widget build(BuildContext context) {
    final viewInsets = MediaQuery.of(context).viewInsets;

    return DraggableScrollableSheet(
      initialChildSize: 0.88,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, scroll) {
        return Container(
          decoration: const BoxDecoration(
            color: _kSheetBg,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Padding(
            padding: EdgeInsets.only(bottom: viewInsets.bottom),
            child: Column(
              children: [
                // ─ Drag handle
                Padding(
                  padding: const EdgeInsets.only(top: 12, bottom: 8),
                  child: Container(
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                // ─ Header con icono granate + título + close
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 8, 12),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: AppColors.button.withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppColors.button.withValues(alpha: 0.4),
                          ),
                        ),
                        child: Icon(
                          _esEdicion
                              ? Icons.edit_note
                              : Icons.add_circle_outline,
                          color: AppColors.button,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _esEdicion
                                  ? 'Editar ingrediente'
                                  : 'Nuevo ingrediente',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            if (_esEdicion)
                              Text(
                                widget.ingrediente!.nombre,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.white60,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white60),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
                Divider(
                  height: 1,
                  color: Colors.white.withValues(alpha: 0.12),
                ),
                // ─ Formulario scrolleable
                Expanded(
                  child: Form(
                    key: _formKey,
                    child: ListView(
                      controller: scroll,
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                      children: [
                        // Nombre con autoenfoque al abrir
                        TextFormField(
                          controller: _nombreCtrl,
                          autofocus: true,
                          style: const TextStyle(color: Colors.white),
                          cursorColor: AppColors.button,
                          textCapitalization: TextCapitalization.words,
                          decoration: _fieldDec('Nombre del ingrediente'),
                          validator: (v) =>
                              v == null || v.trim().isEmpty ? 'Requerido' : null,
                        ),
                        const SizedBox(height: 14),
                        // Cantidad + steppers + unidad (flex 2:1 más respirado)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 2,
                              child: TextFormField(
                                controller: _cantidadCtrl,
                                style: const TextStyle(color: Colors.white),
                                cursorColor: AppColors.button,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                  decimal: true,
                                ),
                                inputFormatters: [
                                  FilteringTextInputFormatter.allow(
                                    RegExp(r'[0-9.]'),
                                  ),
                                ],
                                decoration: _fieldDec('Cantidad actual'),
                                validator: (v) {
                                  if (v == null || v.isEmpty) return 'Requerido';
                                  if (double.tryParse(v) == null) {
                                    return 'Número inválido';
                                  }
                                  return null;
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            // Botones +/- para ajuste rápido
                            Column(
                              children: [
                                _StepBtn(
                                  icon: Icons.add,
                                  onPressed: () => _adjustQuantity(_step),
                                ),
                                const SizedBox(height: 6),
                                _StepBtn(
                                  icon: Icons.remove,
                                  onPressed: () => _adjustQuantity(-_step),
                                ),
                              ],
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 1,
                              child: DropdownButtonFormField<String>(
                                initialValue: _unidad,
                                dropdownColor: _kSheetBg,
                                style: const TextStyle(color: Colors.white),
                                iconEnabledColor: Colors.white60,
                                decoration: _fieldDec('Unidad'),
                                items: IngredienteService.unidades
                                    .map(
                                      (u) => DropdownMenuItem(
                                        value: u,
                                        child: Text(u),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (v) => setState(() => _unidad = v!),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _minimoCtrl,
                          style: const TextStyle(color: Colors.white),
                          cursorColor: AppColors.button,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                          ],
                          decoration: _fieldDec(
                            'Stock mínimo de alerta',
                            suffix: const Icon(
                              Icons.warning_amber_outlined,
                              color: Colors.amber,
                              size: 18,
                            ),
                          ),
                          validator: (v) {
                            if (v == null || v.isEmpty) return 'Requerido';
                            if (double.tryParse(v) == null) {
                              return 'Número inválido';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),
                        DropdownButtonFormField<String>(
                          initialValue: _categoria,
                          dropdownColor: _kSheetBg,
                          style: const TextStyle(color: Colors.white),
                          iconEnabledColor: Colors.white60,
                          isExpanded: true,
                          decoration: _fieldDec('Categoría'),
                          items: IngredienteService.categorias
                              .map(
                                (c) => DropdownMenuItem(
                                  value: c,
                                  child: Text(c),
                                ),
                              )
                              .toList(),
                          onChanged: (v) => setState(() => _categoria = v!),
                        ),
                        const SizedBox(height: 28),
                        // ─ Botón principal: guardar / crear
                        SizedBox(
                          height: 54,
                          child: ElevatedButton(
                            onPressed: _guardando ? null : _guardar,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.button,
                              foregroundColor: Colors.white,
                              disabledBackgroundColor: AppColors.button
                                  .withValues(alpha: 0.5),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              elevation: 0,
                            ),
                            child: _guardando
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Text(
                                    _esEdicion
                                        ? 'GUARDAR CAMBIOS'
                                        : 'CREAR INGREDIENTE',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                          ),
                        ),
                        // Eliminar separado visualmente (solo en edición)
                        if (_esEdicion) ...[
                          const SizedBox(height: 24),
                          Divider(
                            color: Colors.white.withValues(alpha: 0.10),
                            thickness: 1,
                          ),
                          const SizedBox(height: 8),
                          TextButton.icon(
                            onPressed: _guardando ? null : _eliminar,
                            icon: const Icon(Icons.delete_outline),
                            label: const Text('Eliminar ingrediente'),
                            style: TextButton.styleFrom(
                              foregroundColor: AppColors.error,
                              minimumSize: const Size(double.infinity, 44),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ─── Stepper Button ───────────────────────────────────────────────────────────

class _StepBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;

  const _StepBtn({required this.icon, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: AppColors.button.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.button.withValues(alpha: 0.4)),
        ),
        child: Icon(icon, color: AppColors.button, size: 18),
      ),
    );
  }
}

import 'dart:async';
import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:frontend/components/bravo_app_bar.dart';
import 'package:provider/provider.dart';

import '../../core/app_snackbar.dart';
import '../../core/colors_style.dart';
import '../../models/producto_model.dart';
import '../../models/restaurante_model.dart';
import '../../providers/restaurante_provider.dart';
import '../../services/producto_service.dart';

// ─── Colores locales ─────────────────────────────────────────────────────────
const _kGreen = Color(0xFF34C759);
const _kOrange = Color(0xFFFF9500);
const _kRed = Color(0xFFFF3B30);
const _kAccent = AppColors.button;

// ─── Constantes de validación / negocio ──────────────────────────────────────
const double _kPrecioMin = 0.01;
const double _kPrecioMax = 999.99;
const int _kBatchSize = 5; // peticiones simultáneas máximas al guardar
const Duration _kBusquedaDebounce = Duration(milliseconds: 250);

// ─── Modelo de fila ──────────────────────────────────────────────────────────

/// Estado mutable de un producto dentro de la pantalla de edición masiva.
///
/// Expone un [ChangeNotifier] vía [precioCtrl] (TextEditingController también
/// es Listenable) y [_disponible] como [ValueNotifier], de modo que la UI
/// puede reaccionar fila a fila sin reconstruir toda la pantalla.
class _ItemEdicion {
  final Producto original;
  final TextEditingController precioCtrl;
  final ValueNotifier<bool> disponibleN;

  _ItemEdicion(this.original)
    : precioCtrl = TextEditingController(
        text: original.precio.toStringAsFixed(2),
      ),
      disponibleN = ValueNotifier(original.estaDisponible);

  bool get disponible => disponibleN.value;

  /// Precio parseado del campo de texto. `null` si la cadena está vacía o no
  /// es un número válido.
  double? get precioEditado => double.tryParse(precioCtrl.text.trim());

  /// Devuelve un mensaje de error de validación, o `null` si el precio es OK.
  String? validar() {
    final txt = precioCtrl.text.trim();
    if (txt.isEmpty) return 'Precio requerido';
    final p = double.tryParse(txt);
    if (p == null) return 'Número inválido';
    if (p < _kPrecioMin) return 'Mínimo ${_kPrecioMin.toStringAsFixed(2)}€';
    if (p > _kPrecioMax) return 'Máximo ${_kPrecioMax.toStringAsFixed(0)}€';
    return null;
  }

  bool get sucio {
    final p = precioEditado;
    return (p != null && p != original.precio) ||
        disponible != original.estaDisponible;
  }

  void resetear() {
    precioCtrl.text = original.precio.toStringAsFixed(2);
    disponibleN.value = original.estaDisponible;
  }

  void aplicarDelta(double porcentaje) {
    final base = precioEditado ?? original.precio;
    final nuevo = (base * (1 + porcentaje / 100)).clamp(
      _kPrecioMin,
      _kPrecioMax,
    );
    // Redondeo "comercial" a 0,05 € para precios de carta más limpios.
    final redondeado = (nuevo * 20).round() / 20;
    precioCtrl.text = redondeado.toStringAsFixed(2);
  }

  void dispose() {
    precioCtrl.dispose();
    disponibleN.dispose();
  }
}

// ─── Pantalla ────────────────────────────────────────────────────────────────

class CatalogoMasivoScreen extends StatefulWidget {
  const CatalogoMasivoScreen({super.key});

  @override
  State<CatalogoMasivoScreen> createState() => _CatalogoMasivoScreenState();
}

class _CatalogoMasivoScreenState extends State<CatalogoMasivoScreen> {
  // ── Estado ────────────────────────────────────────────────────────────────
  List<_ItemEdicion> _items = [];
  List<String> _categorias = [];
  bool _cargando = false;
  String? _error;
  String _busqueda = '';
  bool _guardando = false;

  /// Sucursal cuyo catálogo se está editando. `null` = ninguna seleccionada
  /// y por tanto la pantalla muestra el estado de bienvenida con el selector.
  /// Edición masiva mezclando sucursales no se permite a propósito.
  String? _restauranteId;
  // Set de categorías colapsadas. Inicia vacío → todas abiertas.
  // Persiste entre recargas (no se vuelven a abrir todas tras guardar).
  final Set<String> _catColapsadas = {};
  // Progreso de guardado (X de N)
  int _guardadasOk = 0;
  int _guardadasTotal = 0;

  /// Versión del estado "sucio". Cualquier cambio (precio, disponible, lista)
  /// incrementa este notifier y solo el FAB y la barra se rebuildean.
  final ValueNotifier<int> _versionSucio = ValueNotifier(0);

  final TextEditingController _buscadorCtrl = TextEditingController();
  final ScrollController _scroll = ScrollController();
  Timer? _debounceBusqueda;

  // ── Ciclo de vida ─────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    // Pedimos al provider las sucursales tras el primer frame; el selector
    // las usa para renderizarse. No cargamos productos hasta que el super
    // admin elija una sucursal explícitamente.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final prov = context.read<RestauranteProvider>();
      if (prov.restaurantes.isEmpty && !prov.cargando) {
        prov.cargar();
      }
    });
  }

  @override
  void dispose() {
    _liberarItems();
    _buscadorCtrl.dispose();
    _scroll.dispose();
    _debounceBusqueda?.cancel();
    _versionSucio.dispose();
    super.dispose();
  }

  /// Desengancha listeners y libera controllers de los items actuales.
  /// Se llama tanto al recargar como al cerrar la pantalla.
  void _liberarItems() {
    for (final it in _items) {
      it.precioCtrl.removeListener(_onItemSucioCambia);
      it.disponibleN.removeListener(_onItemSucioCambia);
      it.dispose();
    }
  }

  /// Listener que se engancha a cada controller/notifier de las filas.
  /// Solo incrementa una versión: el FAB se rebuildea, la lista no.
  void _onItemSucioCambia() {
    _versionSucio.value++;
  }

  // ── Carga ─────────────────────────────────────────────────────────────────
  Future<void> _cargar() async {
    final rid = _restauranteId;
    if (rid == null) {
      // No hay sucursal seleccionada: limpiamos cualquier item previo
      // (por si veníamos de otra sucursal) y dejamos la pantalla en
      // estado vacío.
      _liberarItems();
      if (!mounted) return;
      setState(() {
        _items = [];
        _categorias = [];
        _cargando = false;
        _error = null;
      });
      return;
    }
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        ProductoService.obtenerProductos(restauranteId: rid),
        ProductoService.obtenerCategorias(),
      ]);
      final productos = results[0] as List<Producto>;
      final categorias = results[1] as List<String>;

      // Liberar items antiguos antes de reemplazarlos.
      _liberarItems();

      // Categorías que existen + categorías referenciadas por productos.
      final cats = List<String>.from(categorias);
      for (final p in productos) {
        if (!cats.contains(p.categoria)) cats.add(p.categoria);
      }

      final nuevos = productos.map((p) => _ItemEdicion(p)).toList();
      for (final it in nuevos) {
        it.precioCtrl.addListener(_onItemSucioCambia);
        it.disponibleN.addListener(_onItemSucioCambia);
      }

      if (!mounted) return;
      setState(() {
        _categorias = cats;
        _items = nuevos;
        _cargando = false;
      });
      _versionSucio.value++;
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _cargando = false;
      });
    }
  }

  // ── Selector de sucursal ──────────────────────────────────────────────────

  /// Cambia la sucursal activa. Si hay cambios sin guardar pide confirmación
  /// para no perderlos al recargar el catálogo de otra sucursal.
  Future<void> _seleccionarSucursal(String? nuevoId) async {
    if (nuevoId == _restauranteId) return;
    if (_hayCambios) {
      final ok = await _confirmar(
        titulo: 'Cambiar de sucursal',
        cuerpo:
            'Tienes ${_itemsSucios.length} cambio(s) sin guardar en la '
            'sucursal actual. Si cambias se descartarán.',
        cta: 'Cambiar y descartar',
        ctaColor: _kRed,
      );
      if (ok != true) return;
    }
    setState(() {
      _restauranteId = nuevoId;
      _busqueda = '';
      _buscadorCtrl.clear();
      _catColapsadas.clear();
    });
    _versionSucio.value++;
    await _cargar();
  }

  // ── Filtros ───────────────────────────────────────────────────────────────
  List<_ItemEdicion> _itemsDeCategoria(String categoria) {
    final q = _busqueda.toLowerCase().trim();
    return _items.where((it) {
      if (it.original.categoria != categoria) return false;
      if (q.isEmpty) return true;
      return it.original.nombre.toLowerCase().contains(q);
    }).toList();
  }

  List<_ItemEdicion> get _itemsSucios =>
      _items.where((it) => it.sucio).toList();

  bool get _hayCambios => _items.any((it) => it.sucio);

  bool get _hayInvalidos =>
      _items.any((it) => it.sucio && it.validar() != null);

  // ── Guardar (con concurrencia limitada y progreso) ─────────────────────────
  Future<void> _guardarCambios() async {
    final sucios = _itemsSucios;
    if (sucios.isEmpty) return;

    // Validar antes de mandar nada.
    final invalidos = sucios.where((it) => it.validar() != null).toList();
    if (invalidos.isNotEmpty) {
      showAppError(
        context,
        '${invalidos.length} producto(s) con precio inválido. Corrígelos antes de guardar.',
      );
      _scrollAPrimerInvalido();
      return;
    }

    setState(() {
      _guardando = true;
      _guardadasOk = 0;
      _guardadasTotal = sucios.length;
    });

    final errores = <_ResultadoGuardado>[];

    // Procesa en lotes de _kBatchSize para no saturar el backend ni el
    // rate-limiter. 100 cambios → 20 lotes; cada lote en paralelo.
    for (var i = 0; i < sucios.length; i += _kBatchSize) {
      final lote = sucios.skip(i).take(_kBatchSize).toList();
      final resultados = await Future.wait(
        lote.map((it) async {
          try {
            // El backend (ProductoCrear) usa los nombres `imagen` y
            // `disponible`. NO `imagenUrl` ni `estaDisponible`. Construimos
            // explícitamente el payload para no perder la imagen ni mezclar
            // alias.
            final precio = it.precioEditado ?? it.original.precio;
            final ingredientes = it.original.ingredientes
                .map((i) => <String, dynamic>{
                  if (i.id.isNotEmpty) 'ingrediente_id': i.id,
                  'nombre': i.nombre,
                  'cantidad_receta': i.cantidadReceta,
                })
                .toList();
            final datos = <String, dynamic>{
              'nombre': it.original.nombre,
              'descripcion': it.original.descripcion,
              'precio': precio,
              'categoria': it.original.categoria,
              'imagen': it.original.imagenUrl,
              'disponible': it.disponible,
              'ingredientes': ingredientes,
              // Mantenemos siempre la sucursal del producto para no perderla
              // al actualizar (Pydantic ignora el campo si vale None).
              if (it.original.restauranteId != null)
                'restaurante_id': it.original.restauranteId,
            };
            await ProductoService.actualizarProducto(it.original.id, datos);
            return _ResultadoGuardado(nombre: it.original.nombre, ok: true);
          } catch (e) {
            return _ResultadoGuardado(
              nombre: it.original.nombre,
              ok: false,
              error: e.toString(),
            );
          }
        }),
      );
      if (!mounted) return;
      setState(() {
        _guardadasOk += resultados.where((r) => r.ok).length;
      });
      errores.addAll(resultados.where((r) => !r.ok));
    }

    if (!mounted) return;
    setState(() {
      _guardando = false;
      _guardadasOk = 0;
      _guardadasTotal = 0;
    });

    if (errores.isEmpty) {
      showAppSuccess(
        context,
        '${sucios.length} producto(s) actualizados correctamente',
      );
    } else if (errores.length == sucios.length) {
      // Si TODOS fallan con el mismo error es probablemente un problema
      // global (backend caído, sin auth, sin red). Mostramos el mensaje.
      final errorComun = _detectarErrorComun(errores);
      showAppError(
        context,
        errorComun ??
            'No se pudo guardar ningún cambio. Revisa la conexión y reintenta.',
      );
    } else {
      showAppError(
        context,
        '${sucios.length - errores.length} guardados · ${errores.length} fallaron. '
        'Revisa los productos marcados en rojo y reintenta.',
      );
    }

    // Sincronizar siempre con el backend para reflejar el estado real.
    await _cargar();
  }

  /// Si todos los errores comparten el mismo mensaje (backend caído,
  /// 401/403, sin red…), lo devolvemos para mostrarlo al usuario en lugar
  /// del genérico "no se pudo guardar". Si difieren, devuelve null.
  String? _detectarErrorComun(List<_ResultadoGuardado> errores) {
    if (errores.isEmpty) return null;
    final primero = errores.first.error ?? '';
    final iguales = errores.every((e) => (e.error ?? '') == primero);
    if (!iguales || primero.isEmpty) return null;
    return primero;
  }

  void _scrollAPrimerInvalido() {
    // Heurística simple: subir al inicio. Mejorarlo con keys requiere
    // mantener un GlobalKey por fila — coste alto para beneficio bajo.
    if (_scroll.hasClients) {
      _scroll.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  // ── Descartar ─────────────────────────────────────────────────────────────
  Future<void> _descartarTodo() async {
    final n = _itemsSucios.length;
    if (n == 0) return;
    final ok = await _confirmar(
      titulo: 'Descartar cambios',
      cuerpo: 'Se perderán $n cambio(s) sin guardar.',
      cta: 'Descartar',
      ctaColor: _kRed,
    );
    if (ok != true) return;
    for (final it in _itemsSucios) {
      it.resetear();
    }
    _versionSucio.value++;
  }

  Future<bool?> _confirmar({
    required String titulo,
    required String cuerpo,
    required String cta,
    Color ctaColor = _kAccent,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.background,
        title: Text(
          titulo,
          style: const TextStyle(color: AppColors.textPrimary),
        ),
        content: Text(
          cuerpo,
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              'Cancelar',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(cta, style: TextStyle(color: ctaColor)),
          ),
        ],
      ),
    );
  }

  // ── Operaciones masivas por categoría ─────────────────────────────────────

  Future<void> _aplicarDeltaCategoria(String categoria) async {
    final items = _itemsDeCategoria(categoria);
    if (items.isEmpty) return;
    final delta = await _pedirPorcentaje(categoria, items.length);
    if (delta == null) return;
    for (final it in items) {
      it.aplicarDelta(delta);
    }
    _versionSucio.value++;
    if (!mounted) return;
    showAppSuccess(
      context,
      '${delta > 0 ? '+' : ''}${delta.toStringAsFixed(1)} % aplicado a '
      '${items.length} producto(s) de "$categoria"',
    );
  }

  Future<double?> _pedirPorcentaje(String categoria, int n) async {
    final ctrl = TextEditingController(text: '5');
    try {
      return await showDialog<double>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppColors.background,
          title: const Text(
            'Ajustar precios',
            style: TextStyle(color: AppColors.textPrimary),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Aplicar un porcentaje sobre $n producto(s) de "$categoria". '
                'Usa números negativos para bajar precios.',
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: ctrl,
                autofocus: true,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                  signed: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(
                    RegExp(r'^-?\d{0,3}(\.\d{0,2})?'),
                  ),
                ],
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: const InputDecoration(
                  labelText: 'Porcentaje',
                  suffixText: '%',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                children: [-10.0, -5.0, 5.0, 10.0]
                    .map(
                      (v) => OutlinedButton(
                        onPressed: () => Navigator.pop(ctx, v),
                        child: Text('${v > 0 ? '+' : ''}${v.toInt()} %'),
                      ),
                    )
                    .toList(),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, null),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () {
                final v = double.tryParse(ctrl.text);
                if (v == null || v < -90 || v > 200) return;
                Navigator.pop(ctx, v);
              },
              child: const Text(
                'APLICAR',
                style: TextStyle(color: _kAccent, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      );
    } finally {
      ctrl.dispose();
    }
  }

  void _toggleDisponibilidadCategoria(String categoria, bool disponible) {
    final items = _itemsDeCategoria(categoria);
    if (items.isEmpty) return;
    for (final it in items) {
      it.disponibleN.value = disponible;
    }
    _versionSucio.value++;
    if (!mounted) return;
    showAppSuccess(
      context,
      '${items.length} producto(s) marcados como '
      '${disponible ? "disponibles" : "no disponibles"}',
    );
  }

  // ── Búsqueda con debounce ─────────────────────────────────────────────────
  void _onBusquedaChanged(String texto) {
    _debounceBusqueda?.cancel();
    _debounceBusqueda = Timer(_kBusquedaDebounce, () {
      if (!mounted) return;
      setState(() => _busqueda = texto);
    });
  }

  // ── Pop con confirmación ──────────────────────────────────────────────────
  Future<bool> _onPop() async {
    if (!_hayCambios) return true;
    final ok = await _confirmar(
      titulo: 'Salir sin guardar',
      cuerpo:
          'Tienes ${_itemsSucios.length} cambio(s) sin guardar. '
          'Si sales se perderán.',
      cta: 'Salir',
      ctaColor: _kRed,
    );
    return ok == true;
  }

  // ── BUILD ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_hayCambios,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await _onPop() && context.mounted) {
          Navigator.pop(context);
        }
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        extendBodyBehindAppBar: true,
        appBar: const BravoAppBar(title: 'CATÁLOGO'),
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
            child: SafeArea(child: _buildBody()),
          ),
        ),
        floatingActionButton: ValueListenableBuilder<int>(
          valueListenable: _versionSucio,
          builder: (_, _, _) {
            if (!_hayCambios) return const SizedBox.shrink();
            return _buildFAB();
          },
        ),
      ),
    );
  }

  Widget _buildBody() {
    return Column(
      children: [
        // Selector de sucursal SIEMPRE visible: el super admin debe saber
        // (y poder cambiar) qué catálogo está editando.
        _buildSelectorSucursal(),
        Expanded(child: _buildContenido()),
      ],
    );
  }

  Widget _buildContenido() {
    // 1) Sin sucursal elegida → estado de bienvenida.
    if (_restauranteId == null) {
      return _buildEstadoBienvenida();
    }
    // 2) Cargando productos de la sucursal seleccionada.
    if (_cargando) {
      return const Center(child: CircularProgressIndicator(color: _kAccent));
    }
    // 3) Error al cargar.
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded, color: _kRed, size: 48),
              const SizedBox(height: 12),
              Text(
                _error!,
                style: const TextStyle(color: Colors.white70),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _cargar,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Reintentar'),
                style: ElevatedButton.styleFrom(backgroundColor: _kAccent),
              ),
            ],
          ),
        ),
      );
    }
    // 4) OK: pintamos banner + buscador + lista.
    return Column(
      children: [
        ValueListenableBuilder<int>(
          valueListenable: _versionSucio,
          builder: (_, _, _) => _buildBannerCambios(),
        ),
        _buildBuscador(),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _cargar,
            color: _kAccent,
            child: ListView(
              controller: _scroll,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
              children: [
                if (_items.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 80),
                    child: Center(
                      child: Text(
                        'Esta sucursal no tiene productos todavía',
                        style: TextStyle(color: Colors.white60, fontSize: 15),
                      ),
                    ),
                  )
                else
                  for (final cat in _categorias) _buildCategoria(cat),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// Selector horizontal de sucursales — chips con la activa resaltada.
  Widget _buildSelectorSucursal() {
    return Consumer<RestauranteProvider>(
      builder: (_, prov, _) {
        if (prov.cargando && prov.restaurantes.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            child: SizedBox(
              height: 22,
              width: 22,
              child: CircularProgressIndicator(color: _kAccent, strokeWidth: 2),
            ),
          );
        }
        if (prov.error != null && prov.restaurantes.isEmpty) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
            child: Row(
              children: [
                const Icon(Icons.error_outline, color: _kRed, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'No se pudieron cargar las sucursales',
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ),
                TextButton(
                  onPressed: prov.cargar,
                  child: const Text(
                    'Reintentar',
                    style: TextStyle(color: _kAccent, fontSize: 12),
                  ),
                ),
              ],
            ),
          );
        }
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(width: 3, height: 18, color: AppColors.button),
                  const SizedBox(width: 10),
                  const Text(
                    'SUCURSAL',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: Colors.white70,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(width: 10),
                  if (_restauranteId != null) ...[
                    const Icon(
                      Icons.lens_rounded,
                      size: 6,
                      color: Colors.white38,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${prov.restaurantes.length} disponible(s)',
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 38,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: prov.restaurantes.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (_, i) {
                    final r = prov.restaurantes[i];
                    final activa = r.id == _restauranteId;
                    return _ChipSucursal(
                      restaurante: r,
                      activa: activa,
                      onTap: () => _seleccionarSucursal(r.id),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEstadoBienvenida() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.storefront_rounded,
              size: 64,
              color: Colors.white.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 14),
            const Text(
              'Selecciona una sucursal',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'La edición masiva trabaja sobre el catálogo de UNA sucursal. '
              'Elige cuál arriba para empezar.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.55),
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Banner sticky con totales y atajos ────────────────────────────────────
  Widget _buildBannerCambios() {
    final total = _items.length;
    final dispon = _items.where((it) => it.disponible).length;
    final sucios = _itemsSucios.length;
    final invalidos = _items
        .where((it) => it.sucio && it.validar() != null)
        .length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(width: 3, height: 18, color: AppColors.button),
              const SizedBox(width: 10),
              const Text(
                'EDICIÓN MASIVA',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: Colors.white70,
                  letterSpacing: 2,
                ),
              ),
              const Spacer(),
              if (sucios > 0)
                TextButton.icon(
                  onPressed: _guardando ? null : _descartarTodo,
                  icon: const Icon(
                    Icons.undo_rounded,
                    color: _kOrange,
                    size: 18,
                  ),
                  label: const Text(
                    'Descartar todo',
                    style: TextStyle(color: _kOrange, fontSize: 13),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          // Chips de resumen — usa Wrap para no desbordar en móvil pequeño.
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _StatChip(
                label: '$total productos',
                icon: Icons.restaurant_menu_rounded,
                color: Colors.white70,
              ),
              _StatChip(
                label: '$dispon disponibles',
                icon: Icons.check_circle_outline_rounded,
                color: _kGreen,
              ),
              if (sucios > 0)
                _StatChip(
                  label: '$sucios sin guardar',
                  icon: Icons.edit_note_rounded,
                  color: _kOrange,
                ),
              if (invalidos > 0)
                _StatChip(
                  label: '$invalidos inválidos',
                  icon: Icons.warning_amber_rounded,
                  color: _kRed,
                ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Buscador con debounce ─────────────────────────────────────────────────
  Widget _buildBuscador() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: TextField(
            controller: _buscadorCtrl,
            onChanged: _onBusquedaChanged,
            textInputAction: TextInputAction.search,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Buscar producto…',
              hintStyle: const TextStyle(color: Colors.white70),
              prefixIcon: const Icon(
                Icons.search_rounded,
                color: Colors.white70,
              ),
              suffixIcon: _busqueda.isNotEmpty
                  ? IconButton(
                      tooltip: 'Limpiar búsqueda',
                      icon: const Icon(
                        Icons.clear_rounded,
                        color: Colors.white70,
                      ),
                      onPressed: () {
                        _buscadorCtrl.clear();
                        _onBusquedaChanged('');
                      },
                    )
                  : null,
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.08),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.white24),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.white24),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: _kAccent, width: 1.5),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Sección de categoría ──────────────────────────────────────────────────
  Widget _buildCategoria(String categoria) {
    final items = _itemsDeCategoria(categoria);
    // Si la búsqueda está activa y la categoría no tiene resultados, ocultar.
    if (_busqueda.isNotEmpty && items.isEmpty) return const SizedBox.shrink();

    final colapsada = _catColapsadas.contains(categoria);
    final suciosCat = items.where((it) => it.sucio).length;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.45),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.15),
                width: 1.5,
              ),
            ),
            child: Column(
              children: [
                _CabeceraCategoria(
                  categoria: categoria,
                  total: items.length,
                  sucios: suciosCat,
                  colapsada: colapsada,
                  onToggle: () => setState(() {
                    if (colapsada) {
                      _catColapsadas.remove(categoria);
                    } else {
                      _catColapsadas.add(categoria);
                    }
                  }),
                  onAjustarPrecios: items.isEmpty
                      ? null
                      : () => _aplicarDeltaCategoria(categoria),
                  onMarcarTodos: items.isEmpty
                      ? null
                      : () => _toggleDisponibilidadCategoria(categoria, true),
                  onDesmarcarTodos: items.isEmpty
                      ? null
                      : () => _toggleDisponibilidadCategoria(categoria, false),
                ),
                if (!colapsada) ...[
                  const Divider(color: Colors.white12, height: 1),
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: items.length,
                    separatorBuilder: (_, _) =>
                        const Divider(color: Colors.white12, height: 1),
                    itemBuilder: (_, i) => _FilaProducto(
                      key: ValueKey(items[i].original.id),
                      item: items[i],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── FAB con progreso de guardado ──────────────────────────────────────────
  Widget _buildFAB() {
    final n = _itemsSucios.length;
    if (_guardando) {
      final progreso = _guardadasTotal == 0
          ? 0.0
          : (_guardadasOk / _guardadasTotal).clamp(0.0, 1.0);
      return FloatingActionButton.extended(
        onPressed: null,
        backgroundColor: _kAccent,
        foregroundColor: Colors.white,
        icon: SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(
            color: Colors.white,
            strokeWidth: 2,
            value: progreso > 0 ? progreso : null,
          ),
        ),
        label: Text(
          'Guardando $_guardadasOk / $_guardadasTotal',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
      );
    }
    final invalidos = _hayInvalidos;
    return FloatingActionButton.extended(
      onPressed: invalidos ? null : _guardarCambios,
      backgroundColor: invalidos ? Colors.white24 : _kAccent,
      foregroundColor: Colors.white,
      icon: Icon(invalidos ? Icons.warning_amber_rounded : Icons.save_rounded),
      label: Text(
        invalidos ? 'Hay errores' : 'Aplicar cambios ($n)',
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
    );
  }
}

// ─── Cabecera de categoría con menú de acciones masivas ──────────────────────

class _CabeceraCategoria extends StatelessWidget {
  final String categoria;
  final int total;
  final int sucios;
  final bool colapsada;
  final VoidCallback onToggle;
  final VoidCallback? onAjustarPrecios;
  final VoidCallback? onMarcarTodos;
  final VoidCallback? onDesmarcarTodos;

  const _CabeceraCategoria({
    required this.categoria,
    required this.total,
    required this.sucios,
    required this.colapsada,
    required this.onToggle,
    required this.onAjustarPrecios,
    required this.onMarcarTodos,
    required this.onDesmarcarTodos,
  });

  @override
  Widget build(BuildContext context) {
    final nombre = categoria.isEmpty ? 'Sin categoría' : categoria;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onToggle,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              const Icon(Icons.folder_rounded, color: _kAccent, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  nombre,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
              ),
              if (sucios > 0) ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: _kOrange.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _kOrange.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    '$sucios editado(s)',
                    style: const TextStyle(
                      color: _kOrange,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Text(
                '$total',
                style: const TextStyle(color: Colors.white60, fontSize: 13),
              ),
              const SizedBox(width: 4),
              // Menú de acciones masivas
              PopupMenuButton<String>(
                tooltip: 'Acciones masivas',
                icon: const Icon(
                  Icons.more_vert_rounded,
                  color: Colors.white70,
                ),
                color: AppColors.background,
                onSelected: (v) {
                  switch (v) {
                    case 'precio':
                      onAjustarPrecios?.call();
                    case 'marcar':
                      onMarcarTodos?.call();
                    case 'desmarcar':
                      onDesmarcarTodos?.call();
                  }
                },
                itemBuilder: (_) => [
                  PopupMenuItem(
                    value: 'precio',
                    enabled: onAjustarPrecios != null,
                    child: const _MenuItemLabel(
                      icon: Icons.percent_rounded,
                      texto: 'Ajustar precios (+/− %)',
                    ),
                  ),
                  PopupMenuItem(
                    value: 'marcar',
                    enabled: onMarcarTodos != null,
                    child: const _MenuItemLabel(
                      icon: Icons.check_circle_outline_rounded,
                      texto: 'Marcar todos disponibles',
                      color: _kGreen,
                    ),
                  ),
                  PopupMenuItem(
                    value: 'desmarcar',
                    enabled: onDesmarcarTodos != null,
                    child: const _MenuItemLabel(
                      icon: Icons.cancel_outlined,
                      texto: 'Marcar todos no disponibles',
                      color: _kRed,
                    ),
                  ),
                ],
              ),
              Icon(
                colapsada
                    ? Icons.keyboard_arrow_down_rounded
                    : Icons.keyboard_arrow_up_rounded,
                color: Colors.white70,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MenuItemLabel extends StatelessWidget {
  final IconData icon;
  final String texto;
  final Color color;

  const _MenuItemLabel({
    required this.icon,
    required this.texto,
    this.color = AppColors.textPrimary,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(width: 8),
        Text(texto, style: TextStyle(color: color, fontSize: 13)),
      ],
    );
  }
}

// ─── Chip de sucursal del selector ───────────────────────────────────────────

class _ChipSucursal extends StatelessWidget {
  final Restaurante restaurante;
  final bool activa;
  final VoidCallback onTap;

  const _ChipSucursal({
    required this.restaurante,
    required this.activa,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final r = restaurante;
    final inactiva = !r.activo;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: activa
                ? _kAccent.withValues(alpha: 0.22)
                : Colors.white.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: activa ? _kAccent : Colors.white.withValues(alpha: 0.18),
              width: activa ? 1.4 : 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                activa ? Icons.storefront_rounded : Icons.storefront_outlined,
                size: 14,
                color: activa ? _kAccent : Colors.white70,
              ),
              const SizedBox(width: 6),
              Text(
                r.nombre.isEmpty ? '(sin nombre)' : r.nombre,
                style: TextStyle(
                  color: activa ? Colors.white : Colors.white70,
                  fontSize: 12,
                  fontWeight: activa ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
              if (inactiva) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 5,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    color: _kRed.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: _kRed.withValues(alpha: 0.4)),
                  ),
                  child: const Text(
                    'SUSP.',
                    style: TextStyle(
                      color: _kRed,
                      fontSize: 8,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Fila de producto (rebuildea solo al cambiar SU controller) ──────────────

class _FilaProducto extends StatelessWidget {
  final _ItemEdicion item;
  const _FilaProducto({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    // Listenable agregado: precioCtrl + disponibleN. Solo esta fila rebuildea
    // cuando cambia su precio o su switch.
    return ListenableBuilder(
      listenable: Listenable.merge([item.precioCtrl, item.disponibleN]),
      builder: (context, _) {
        final sucio = item.sucio;
        final errorTxt = sucio ? item.validar() : null;
        return Semantics(
          label:
              '${item.original.nombre}, '
              '${item.disponible ? "disponible" : "no disponible"}, '
              'precio ${item.precioCtrl.text} euros'
              '${sucio ? ", modificado" : ""}',
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            color: errorTxt != null
                ? _kRed.withValues(alpha: 0.08)
                : sucio
                ? _kOrange.withValues(alpha: 0.05)
                : Colors.transparent,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _IndicadorSucio(sucio: sucio, error: errorTxt != null),
                const SizedBox(width: 8),
                _Imagen(url: item.original.imagenUrl),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.original.nombre,
                        style: TextStyle(
                          color: item.disponible
                              ? Colors.white
                              : Colors.white60,
                          fontWeight: FontWeight.w500,
                          fontSize: 14,
                          decoration: item.disponible
                              ? TextDecoration.none
                              : TextDecoration.lineThrough,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      _LineaPrecioOriginal(
                        original: item.original.precio,
                        editado: item.precioEditado,
                        sucio: sucio,
                      ),
                      if (errorTxt != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          errorTxt,
                          style: const TextStyle(
                            color: _kRed,
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                _CampoPrecio(item: item, sucio: sucio, error: errorTxt != null),
                const SizedBox(width: 6),
                Switch.adaptive(
                  value: item.disponible,
                  activeThumbColor: _kGreen,
                  inactiveThumbColor: Colors.white60,
                  onChanged: (v) => item.disponibleN.value = v,
                ),
                if (sucio)
                  IconButton(
                    tooltip: 'Deshacer cambios de este producto',
                    icon: const Icon(
                      Icons.undo_rounded,
                      color: _kOrange,
                      size: 18,
                    ),
                    onPressed: item.resetear,
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _IndicadorSucio extends StatelessWidget {
  final bool sucio;
  final bool error;
  const _IndicadorSucio({required this.sucio, required this.error});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      width: 3,
      height: 40,
      decoration: BoxDecoration(
        color: error
            ? _kRed
            : sucio
            ? _kOrange
            : Colors.transparent,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
}

class _Imagen extends StatelessWidget {
  final String? url;
  const _Imagen({required this.url});

  @override
  Widget build(BuildContext context) {
    Widget placeholder() => Container(
      width: 44,
      height: 44,
      color: Colors.white.withValues(alpha: 0.08),
      child: const Icon(
        Icons.fastfood_rounded,
        color: Colors.white60,
        size: 22,
      ),
    );

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: url == null || url!.isEmpty
          ? placeholder()
          : CachedNetworkImage(
              imageUrl: url!,
              width: 44,
              height: 44,
              fit: BoxFit.cover,
              errorWidget: (_, _, _) => placeholder(),
              placeholder: (_, _) => placeholder(),
            ),
    );
  }
}

class _LineaPrecioOriginal extends StatelessWidget {
  final double original;
  final double? editado;
  final bool sucio;

  const _LineaPrecioOriginal({
    required this.original,
    required this.editado,
    required this.sucio,
  });

  @override
  Widget build(BuildContext context) {
    if (!sucio || editado == null) {
      return _BadgeDisponibleNeutro(precio: original);
    }
    final delta = editado! - original;
    final pct = original > 0 ? (delta / original) * 100 : 0;
    final subeBaja = delta >= 0;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '${original.toStringAsFixed(2)} €',
          style: const TextStyle(
            color: Colors.white60,
            fontSize: 11,
            decoration: TextDecoration.lineThrough,
          ),
        ),
        const SizedBox(width: 4),
        Icon(Icons.arrow_right_alt_rounded, size: 12, color: Colors.white60),
        const SizedBox(width: 2),
        Text(
          '${editado!.toStringAsFixed(2)} €',
          style: TextStyle(
            color: subeBaja ? _kGreen : _kOrange,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          '(${subeBaja ? '+' : ''}${pct.toStringAsFixed(1)}%)',
          style: TextStyle(color: subeBaja ? _kGreen : _kOrange, fontSize: 10),
        ),
      ],
    );
  }
}

class _BadgeDisponibleNeutro extends StatelessWidget {
  final double precio;
  const _BadgeDisponibleNeutro({required this.precio});

  @override
  Widget build(BuildContext context) {
    return Text(
      '${precio.toStringAsFixed(2)} €',
      style: const TextStyle(color: Colors.white60, fontSize: 11),
    );
  }
}

class _CampoPrecio extends StatelessWidget {
  final _ItemEdicion item;
  final bool sucio;
  final bool error;

  const _CampoPrecio({
    required this.item,
    required this.sucio,
    required this.error,
  });

  @override
  Widget build(BuildContext context) {
    final color = error
        ? _kRed
        : sucio
        ? _kOrange
        : Colors.white24;
    return SizedBox(
      width: 86,
      child: TextField(
        controller: item.precioCtrl,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp(r'^\d{0,3}(\.\d{0,2})?')),
        ],
        textAlign: TextAlign.right,
        textInputAction: TextInputAction.done,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
        decoration: InputDecoration(
          prefixText: '€ ',
          prefixStyle: const TextStyle(color: Colors.white60, fontSize: 12),
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 8,
            vertical: 8,
          ),
          filled: true,
          fillColor: Colors.white.withValues(alpha: 0.08),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: color),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: color),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: error ? _kRed : _kAccent, width: 1.5),
          ),
        ),
      ),
    );
  }
}

// ─── Widgets auxiliares ──────────────────────────────────────────────────────

class _StatChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  const _StatChip({
    required this.label,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 13),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _ResultadoGuardado {
  final String nombre;
  final bool ok;
  final String? error;
  _ResultadoGuardado({required this.nombre, required this.ok, this.error});
}

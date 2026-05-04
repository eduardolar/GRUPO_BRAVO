import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:frontend/components/bravo_app_bar.dart';
import '../../models/producto_model.dart';
import '../../services/producto_service.dart';
import '../../core/colors_style.dart';

// ─── Colores locales ─────────────────────────────────────────────────────────
const _kGreen      = Color(0xFF34C759);
const _kOrange     = Color(0xFFFF9500);
const _kRed        = Color(0xFFFF3B30);
const _kAccent     = AppColors.button;

/// Elemento de edición: guarda el estado mutable de un producto.
class _ItemEdicion {
  final Producto original;
  late TextEditingController precioCtrl;
  late bool disponible;

  _ItemEdicion(this.original) {
    precioCtrl = TextEditingController(
      text: original.precio.toStringAsFixed(2),
    );
    disponible = original.estaDisponible;
  }

  bool get sucio {
    final nuevoPrecio = double.tryParse(precioCtrl.text) ?? original.precio;
    return nuevoPrecio != original.precio ||
        disponible != original.estaDisponible;
  }

  void dispose() => precioCtrl.dispose();
}

/// Resultado de guardar un producto: ok o error.
class _ResultadoGuardado {
  final String nombre;
  final bool ok;
  final String? error;
  _ResultadoGuardado({required this.nombre, required this.ok, this.error});
}

class CatalogoMasivoScreen extends StatefulWidget {
  const CatalogoMasivoScreen({super.key});

  @override
  State<CatalogoMasivoScreen> createState() => _CatalogoMasivoScreenState();
}

class _CatalogoMasivoScreenState extends State<CatalogoMasivoScreen> {
  // ─── Estado ──────────────────────────────────────────────────────────────
  List<_ItemEdicion> _items       = [];
  List<String>       _categorias  = [];
  bool               _cargando    = true;
  String?            _error;
  String             _busqueda    = '';
  bool               _guardando   = false;
  final Set<String>  _catExpandidas = {};

  final TextEditingController _buscadorCtrl = TextEditingController();
  final ScrollController      _scroll       = ScrollController();

  // ─── Ciclo de vida ───────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void dispose() {
    for (final it in _items) {
      it.dispose();
    }
    _buscadorCtrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  // ─── Carga ───────────────────────────────────────────────────────────────
  Future<void> _cargar() async {
    setState(() { _cargando = true; _error = null; });
    try {
      final results = await Future.wait([
        ProductoService.obtenerProductos(),
        ProductoService.obtenerCategorias(),
      ]);
      final productos  = results[0] as List<Producto>;
      final categorias = results[1] as List<String>;

      // Dispose old items
      for (final it in _items) {
        it.dispose();
      }

      // Orden: categorías que existen, luego sin categoría
      final cats = List<String>.from(categorias);
      for (final p in productos) {
        if (!cats.contains(p.categoria)) cats.add(p.categoria);
      }

      setState(() {
        _categorias   = cats;
        _items        = productos.map((p) => _ItemEdicion(p)).toList();
        _catExpandidas.addAll(cats); // todas abiertas por defecto
        _cargando     = false;
      });
    } catch (e) {
      setState(() { _error = e.toString(); _cargando = false; });
    }
  }

  // ─── Filtrado ─────────────────────────────────────────────────────────────
  List<_ItemEdicion> _filtrar(String categoria) {
    return _items.where((it) {
      if (it.original.categoria != categoria) return false;
      if (_busqueda.isEmpty) return true;
      return it.original.nombre
          .toLowerCase()
          .contains(_busqueda.toLowerCase());
    }).toList();
  }


  int get _totalSucio => _items.where((it) => it.sucio).length;

  // ─── Guardar ─────────────────────────────────────────────────────────────
  Future<void> _guardarCambios() async {
    final sucios = _items.where((it) => it.sucio).toList();
    if (sucios.isEmpty) return;

    setState(() => _guardando = true);

    final resultados = await Future.wait(
      sucios.map((it) async {
        try {
          final nuevoPrecio =
              double.tryParse(it.precioCtrl.text) ?? it.original.precio;
          final datos = it.original.toMap()
            ..['precio']        = nuevoPrecio
            ..['estaDisponible'] = it.disponible
            ..['disponible']    = it.disponible;
          await ProductoService.actualizarProducto(it.original.id, datos);
          return _ResultadoGuardado(nombre: it.original.nombre, ok: true);
        } catch (e) {
          return _ResultadoGuardado(
              nombre: it.original.nombre, ok: false, error: e.toString());
        }
      }),
    );

    setState(() => _guardando = false);

    final errores = resultados.where((r) => !r.ok).toList();

    if (!mounted) return;

    if (errores.isEmpty) {
      _mostrarSnack('✓ ${resultados.length} producto(s) actualizados', _kGreen);
      await _cargar();
    } else {
      final msg = errores.length == 1
          ? 'Error en "${errores[0].nombre}": ${errores[0].error}'
          : '${errores.length} errores al guardar. Los demás se aplicaron.';
      _mostrarSnack(msg, _kRed);
      // Recargar igualmente para sincronizar los que sí se guardaron
      await _cargar();
    }
  }

  void _mostrarSnack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(color: Colors.white)),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  // ─── Descarte ────────────────────────────────────────────────────────────
  Future<void> _descartarTodo() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.background,
        title: const Text('Descartar cambios',
            style: TextStyle(color: AppColors.textPrimary)),
        content: Text(
          'Se perderán $_totalSucio cambio(s) sin guardar.',
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar',
                  style: TextStyle(color: AppColors.textSecondary))),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Descartar', style: TextStyle(color: _kRed))),
        ],
      ),
    );
    if (ok == true) await _cargar();
  }

  // ─── BUILD ────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
      floatingActionButton: _totalSucio > 0 ? _buildFAB() : null,
    );
  }

  Widget _buildBody() {
    if (_cargando) {
      return const Center(
          child: CircularProgressIndicator(color: _kAccent));
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, color: _kRed, size: 48),
            const SizedBox(height: 12),
            Text(_error!,
                style: const TextStyle(color: Colors.white70),
                textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _cargar,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Reintentar'),
              style: ElevatedButton.styleFrom(backgroundColor: _kAccent),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
          child: Row(children: [
            Container(width: 3, height: 18, color: AppColors.button),
            const SizedBox(width: 10),
            const Text('EDICIÓN MASIVA',
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: Colors.white70,
                    letterSpacing: 2)),
            const Spacer(),
            if (_totalSucio > 0)
              TextButton.icon(
                onPressed: _guardando ? null : _descartarTodo,
                icon: const Icon(Icons.undo_rounded,
                    color: _kOrange, size: 18),
                label: const Text('Descartar',
                    style: TextStyle(color: _kOrange, fontSize: 13)),
              ),
          ]),
        ),
        _buildBuscador(),
        _buildResumenBarra(),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _cargar,
            color: _kAccent,
            child: ListView(
              controller: _scroll,
              padding: const EdgeInsets.only(
                  left: 16, right: 16, top: 8, bottom: 100),
              children: [
                for (final cat in _categorias) _buildCategoria(cat),
                if (_items.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 80),
                    child: Center(
                      child: Text('Sin productos',
                          style:
                              TextStyle(color: Colors.white60, fontSize: 16)),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ─── Buscador ─────────────────────────────────────────────────────────────
  Widget _buildBuscador() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: TextField(
            controller: _buscadorCtrl,
            onChanged: (v) => setState(() => _busqueda = v),
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Buscar producto…',
              hintStyle: const TextStyle(color: Colors.white60),
              prefixIcon:
                  const Icon(Icons.search_rounded, color: Colors.white70),
              suffixIcon: _busqueda.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear_rounded,
                          color: Colors.white70),
                      onPressed: () {
                        _buscadorCtrl.clear();
                        setState(() => _busqueda = '');
                      },
                    )
                  : null,
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.08),
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 12),
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

  // ─── Barra de resumen ─────────────────────────────────────────────────────
  Widget _buildResumenBarra() {
    final total  = _items.length;
    final sucio  = _totalSucio;
    final dispon = _items.where((it) => it.disponible).length;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Row(
        children: [
          _StatChip(label: '$total productos',
              icon: Icons.restaurant_menu_rounded, color: Colors.white70),
          const SizedBox(width: 8),
          _StatChip(label: '$dispon disponibles',
              icon: Icons.check_circle_outline_rounded, color: _kGreen),
          const SizedBox(width: 8),
          if (sucio > 0)
            _StatChip(label: '$sucio sin guardar',
                icon: Icons.edit_note_rounded, color: _kOrange),
        ],
      ),
    );
  }

  // ─── Sección de categoría ─────────────────────────────────────────────────
  Widget _buildCategoria(String categoria) {
    final items    = _filtrar(categoria);
    if (_busqueda.isNotEmpty && items.isEmpty) return const SizedBox.shrink();

    final expandida = _catExpandidas.contains(categoria);
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
                // Cabecera
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => setState(() {
                      if (expandida) {
                        _catExpandidas.remove(categoria);
                      } else {
                        _catExpandidas.add(categoria);
                      }
                    }),
                    borderRadius: BorderRadius.circular(20),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 13),
                      child: Row(
                        children: [
                          const Icon(Icons.folder_rounded,
                              color: _kAccent, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              categoria.isEmpty ? 'Sin categoría' : categoria,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 15),
                            ),
                          ),
                          if (suciosCat > 0) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: _kOrange.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                    color: _kOrange.withValues(alpha: 0.3)),
                              ),
                              child: Text('$suciosCat editado(s)',
                                  style: const TextStyle(
                                      color: _kOrange,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600)),
                            ),
                            const SizedBox(width: 8),
                          ],
                          Text('${items.length}',
                              style: const TextStyle(
                                  color: Colors.white60, fontSize: 13)),
                          const SizedBox(width: 6),
                          Icon(
                            expandida
                                ? Icons.keyboard_arrow_up_rounded
                                : Icons.keyboard_arrow_down_rounded,
                            color: Colors.white70,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                // Filas de productos
                if (expandida) ...[
                  const Divider(color: Colors.white12, height: 1),
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: items.length,
                    separatorBuilder: (_, _) =>
                        const Divider(color: Colors.white12, height: 1),
                    itemBuilder: (_, i) => _FilaProducto(
                      item: items[i],
                      onChanged: () => setState(() {}),
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

  // ─── FAB ──────────────────────────────────────────────────────────────────
  Widget _buildFAB() {
    return FloatingActionButton.extended(
      onPressed: _guardando ? null : _guardarCambios,
      backgroundColor: _kAccent,
      foregroundColor: Colors.white,
      icon: _guardando
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                  color: Colors.white, strokeWidth: 2))
          : const Icon(Icons.save_rounded),
      label: Text(
        _guardando
            ? 'Guardando…'
            : 'Aplicar cambios ($_totalSucio)',
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
    );
  }
}

// ─── Fila de producto ─────────────────────────────────────────────────────────

class _FilaProducto extends StatefulWidget {
  final _ItemEdicion item;
  final VoidCallback  onChanged;

  const _FilaProducto({required this.item, required this.onChanged});

  @override
  State<_FilaProducto> createState() => _FilaProductoState();
}

class _FilaProductoState extends State<_FilaProducto> {
  @override
  Widget build(BuildContext context) {
    final it     = widget.item;
    final sucio  = it.sucio;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      color: sucio
          ? _kOrange.withValues(alpha: 0.05)
          : Colors.transparent,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          // Indicador de cambio
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 3,
            height: 40,
            decoration: BoxDecoration(
              color: sucio ? _kOrange : Colors.transparent,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 10),
          // Imagen o placeholder
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: it.original.imagenUrl != null &&
                    it.original.imagenUrl!.isNotEmpty
                ? Image.network(
                    it.original.imagenUrl!,
                    width: 44,
                    height: 44,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => _placeholder(),
                  )
                : _placeholder(),
          ),
          const SizedBox(width: 12),
          // Nombre + disponible
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  it.original.nombre,
                  style: TextStyle(
                    color: it.disponible ? Colors.white : Colors.white60,
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                    decoration: it.disponible
                        ? TextDecoration.none
                        : TextDecoration.lineThrough,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                _BadgeDisponible(disponible: it.disponible),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Campo precio
          SizedBox(
            width: 80,
            child: TextField(
              controller: it.precioCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
              ],
              textAlign: TextAlign.right,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600),
              onChanged: (_) {
                setState(() {});
                widget.onChanged();
              },
              decoration: InputDecoration(
                prefixText: '€ ',
                prefixStyle:
                    const TextStyle(color: Colors.white60, fontSize: 12),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 8),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.08),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Colors.white24),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(
                      color: sucio ? _kOrange : Colors.white24),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide:
                      const BorderSide(color: _kAccent, width: 1.5),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          // Toggle disponible
          Switch.adaptive(
            value: it.disponible,
            activeThumbColor: _kGreen,
            inactiveThumbColor: Colors.white60,
            onChanged: (v) {
              setState(() => it.disponible = v);
              widget.onChanged();
            },
          ),
        ],
      ),
    );
  }

  Widget _placeholder() => Container(
        width: 44,
        height: 44,
        color: Colors.white.withValues(alpha: 0.08),
        child: const Icon(Icons.fastfood_rounded,
            color: Colors.white60, size: 22),
      );
}

// ─── Widgets auxiliares ───────────────────────────────────────────────────────

class _BadgeDisponible extends StatelessWidget {
  final bool disponible;
  const _BadgeDisponible({required this.disponible});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            color: disponible ? _kGreen : _kRed,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          disponible ? 'Disponible' : 'No disponible',
          style: TextStyle(
            color: disponible ? _kGreen : _kRed,
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  const _StatChip(
      {required this.label, required this.icon, required this.color});

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
          Text(label,
              style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

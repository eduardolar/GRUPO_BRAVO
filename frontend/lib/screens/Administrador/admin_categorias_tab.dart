import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:frontend/core/colors_style.dart';
import 'package:frontend/services/api_service.dart';

/// Tab/sección de gestión CRUD de categorías. Notifica al padre cuando hay
/// cambios para que pueda recargar la lista de productos si comparte estado.
class AdminCategoriasTab extends StatefulWidget {
  final VoidCallback? onCambio;
  const AdminCategoriasTab({super.key, this.onCambio});

  @override
  State<AdminCategoriasTab> createState() => _AdminCategoriasTabState();
}

class _AdminCategoriasTabState extends State<AdminCategoriasTab> {
  List<String> _categorias = [];
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    try {
      final cats = await ApiService.obtenerCategorias();
      if (!mounted) return;
      setState(() {
        _categorias = cats;
        _cargando = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _cargando = false);
    }
  }

  Future<void> _crear() async {
    final nombre = await _pedirNombre(
      titulo: 'Nueva categoría',
      cta: 'Crear',
    );
    if (nombre == null || nombre.trim().isEmpty) return;
    try {
      await ApiService.crearCategoria(nombre.trim());
      await _cargar();
      widget.onCambio?.call();
      if (mounted) _toast('Categoría creada');
    } catch (e) {
      if (mounted) _toast('Error: $e');
    }
  }

  Future<void> _renombrar(String actual) async {
    final nombre = await _pedirNombre(
      titulo: 'Renombrar categoría',
      cta: 'Guardar',
      inicial: actual,
    );
    if (nombre == null || nombre.trim().isEmpty || nombre.trim() == actual) {
      return;
    }
    try {
      await ApiService.renombrarCategoria(actual, nombre.trim());
      await _cargar();
      widget.onCambio?.call();
      if (mounted) _toast('Categoría renombrada');
    } catch (e) {
      if (mounted) _toast('Error: $e');
    }
  }

  Future<void> _reordenar(int oldIndex, int newIndex) async {
    if (newIndex > oldIndex) newIndex -= 1;
    final previo = List<String>.from(_categorias);

    setState(() {
      final item = _categorias.removeAt(oldIndex);
      _categorias.insert(newIndex, item);
    });

    try {
      await ApiService.reordenarCategorias(_categorias);
      widget.onCambio?.call();
    } catch (e) {
      if (!mounted) return;
      setState(() => _categorias = previo);
      _toast('No se pudo guardar el orden: $e');
    }
  }

  Future<void> _eliminar(String nombre) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        titleTextStyle: const TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
        contentTextStyle: const TextStyle(color: Colors.white70),
        title: const Text('Eliminar categoría'),
        content: Text(
          'Se eliminarán también los productos de "$nombre". ¿Continuar?',
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
      await ApiService.eliminarCategoria(nombre);
      await _cargar();
      widget.onCambio?.call();
      if (mounted) _toast('Categoría eliminada');
    } catch (e) {
      if (mounted) _toast('Error: $e');
    }
  }

  Future<String?> _pedirNombre({
    required String titulo,
    required String cta,
    String? inicial,
  }) {
    final ctrl = TextEditingController(text: inicial ?? '');
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        titleTextStyle: const TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
        title: Text(titulo),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          cursorColor: AppColors.button,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Nombre',
            hintStyle: const TextStyle(color: Colors.white38),
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.07),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0x33FFFFFF)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:
                  const BorderSide(color: AppColors.button, width: 2),
            ),
          ),
          onSubmitted: (v) => Navigator.pop(ctx, v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'Cancelar',
              style: TextStyle(color: Colors.white60),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.button,
              foregroundColor: Colors.white,
            ),
            child: Text(cta),
          ),
        ],
      ),
    );
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    if (_cargando) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.button),
      );
    }

    return Stack(
      children: [
        if (_categorias.isEmpty)
          const Center(
            child: Text(
              'No hay categorías. Pulsa el botón + para crear la primera.',
              style: TextStyle(color: Colors.white70),
              textAlign: TextAlign.center,
            ),
          )
        else
          RefreshIndicator(
            color: AppColors.button,
            onRefresh: _cargar,
            child: ReorderableListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
              itemCount: _categorias.length,
              buildDefaultDragHandles: false,
              onReorder: _reordenar,
              proxyDecorator: (child, _, animation) {
                return AnimatedBuilder(
                  animation: animation,
                  builder: (_, _) => Material(
                    elevation: 6,
                    color: Colors.transparent,
                    shadowColor: AppColors.shadow,
                    borderRadius: BorderRadius.circular(14),
                    child: child,
                  ),
                );
              },
              itemBuilder: (_, i) {
                final c = _categorias[i];
                return Padding(
                  key: ValueKey('cat_$c'),
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _buildCategoriaTile(c, i),
                );
              },
            ),
          ),
        Positioned(
          bottom: 16,
          right: 16,
          child: FloatingActionButton.extended(
            heroTag: 'fab-cat',
            onPressed: _crear,
            backgroundColor: AppColors.button,
            foregroundColor: Colors.white,
            icon: const Icon(Icons.add),
            label: const Text('Nueva categoría'),
          ),
        ),
      ],
    );
  }

  Widget _buildCategoriaTile(String nombre, int index) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.45),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.15),
              width: 1.5,
            ),
          ),
          child: ListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            leading: ReorderableDragStartListener(
              index: index,
              child: Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                child: const Icon(
                  Icons.drag_indicator,
                  color: Colors.white54,
                ),
              ),
            ),
            title: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.button.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: AppColors.button.withValues(alpha: 0.4),
                    ),
                  ),
                  child: const Icon(
                    Icons.category,
                    color: AppColors.button,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    nombre,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            trailing: PopupMenuButton<String>(
              tooltip: 'Acciones',
              icon: const Icon(Icons.more_vert, color: Colors.white70),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              color: const Color(0xFF1C1C1E),
              onSelected: (v) {
                if (v == 'rename') _renombrar(nombre);
                if (v == 'delete') _eliminar(nombre);
              },
              itemBuilder: (_) => const [
                PopupMenuItem(
                  value: 'rename',
                  child: Row(
                    children: [
                      Icon(Icons.edit, color: AppColors.button, size: 18),
                      SizedBox(width: 10),
                      Text(
                        'Renombrar',
                        style: TextStyle(color: Colors.white),
                      ),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete_outline,
                          color: AppColors.error, size: 18),
                      SizedBox(width: 10),
                      Text(
                        'Eliminar',
                        style: TextStyle(color: AppColors.error),
                      ),
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

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:frontend/core/colors_style.dart';
import 'package:frontend/models/ingrediente_model.dart';
import 'package:frontend/models/producto_model.dart';
import 'package:frontend/services/api_service.dart';

const _kSheetBg = Color(0xFF1A1A1A);
const _kBorder = Color(0x33FFFFFF); // white 20%
const _kBorderFocus = AppColors.button;

/// Devuelve `true` si el producto fue creado, actualizado o eliminado.
Future<bool> mostrarEditorProducto(
  BuildContext context, {
  Producto? producto,
}) async {
  final resultado = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.7),
    builder: (_) => _EditorProductoSheet(producto: producto),
  );
  return resultado ?? false;
}

class _EditorProductoSheet extends StatefulWidget {
  final Producto? producto;
  const _EditorProductoSheet({this.producto});

  @override
  State<_EditorProductoSheet> createState() => _EditorProductoSheetState();
}

class _EditorProductoSheetState extends State<_EditorProductoSheet> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nombre;
  late final TextEditingController _descripcion;
  late final TextEditingController _precio;
  late final TextEditingController _imagen;

  String? _categoriaSeleccionada;
  bool _disponible = true;

  final Map<String, _ItemReceta> _items = {};

  List<String> _categorias = [];
  List<Ingrediente> _ingredientesDisponibles = [];
  bool _cargando = true;
  bool _guardando = false;

  bool get _esEdicion => widget.producto != null;

  @override
  void initState() {
    super.initState();
    final p = widget.producto;
    _nombre = TextEditingController(text: p?.nombre ?? '');
    _descripcion = TextEditingController(text: p?.descripcion ?? '');
    _precio = TextEditingController(
      text: p == null ? '' : p.precio.toStringAsFixed(2),
    );
    _imagen = TextEditingController(text: p?.imagenUrl ?? '');
    _categoriaSeleccionada = p?.categoria;
    _disponible = p?.estaDisponible ?? true;

    if (p != null) {
      for (final ing in p.ingredientes) {
        final cantidad = ing.cantidadReceta == 0 ? 1.0 : ing.cantidadReceta;
        _items[ing.id.isEmpty ? ing.nombre : ing.id] = _ItemReceta(
          ingrediente: ing,
          cantidad: cantidad,
          controller: TextEditingController(text: _fmt(cantidad)),
        );
      }
    }
    _cargarCatalogos();
  }

  @override
  void dispose() {
    _nombre.dispose();
    _descripcion.dispose();
    _precio.dispose();
    _imagen.dispose();
    for (final item in _items.values) {
      item.controller.dispose();
    }
    super.dispose();
  }

  String _fmt(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();

  Future<void> _cargarCatalogos() async {
    try {
      final categorias = await ApiService.obtenerCategorias();
      final ingredientes = await ApiService.obtenerIngredientes();
      if (!mounted) return;
      setState(() {
        _categorias = categorias;
        _ingredientesDisponibles = ingredientes;
        if (_categoriaSeleccionada != null &&
            !_categorias.contains(_categoriaSeleccionada)) {
          _categoriaSeleccionada = null;
        }
        _cargando = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _cargando = false);
    }
  }

  Future<void> _abrirSelectorIngredientes() async {
    final yaPuestos = _items.keys.toSet();
    final pendientes = _ingredientesDisponibles
        .where((i) => !yaPuestos.contains(i.id))
        .toList();

    if (pendientes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No quedan ingredientes disponibles para añadir'),
        ),
      );
      return;
    }

    final seleccion = <Ingrediente>{};
    final elegidos = await showModalBottomSheet<List<Ingrediente>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: _kSheetBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.4,
          maxChildSize: 0.95,
          expand: false,
          builder: (_, scroll) {
            return StatefulBuilder(
              builder: (ctx, setSheet) {
                return Column(
                  children: [
                    const SizedBox(height: 12),
                    Container(
                      width: 44,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 20),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Añadir ingredientes',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: ListView.separated(
                        controller: scroll,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        itemCount: pendientes.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 4),
                        itemBuilder: (_, index) {
                          final item = pendientes[index];
                          final marcado = seleccion.contains(item);
                          return CheckboxListTile(
                            value: marcado,
                            controlAffinity: ListTileControlAffinity.trailing,
                            activeColor: AppColors.button,
                            checkColor: Colors.white,
                            title: Text(
                              item.nombre,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                            subtitle: Text(
                              '${item.categoria} · ${item.unidad}',
                              style: const TextStyle(
                                color: Colors.white60,
                                fontSize: 12,
                              ),
                            ),
                            onChanged: (v) {
                              setSheet(() {
                                if (v == true) {
                                  seleccion.add(item);
                                } else {
                                  seleccion.remove(item);
                                }
                              });
                            },
                          );
                        },
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                      child: SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.add),
                          onPressed: seleccion.isEmpty
                              ? null
                              : () => Navigator.pop(ctx, seleccion.toList()),
                          label: Text(
                            seleccion.isEmpty
                                ? 'Selecciona al menos uno'
                                : 'Añadir ${seleccion.length} ingrediente${seleccion.length == 1 ? '' : 's'}',
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.button,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );

    if (elegidos == null || elegidos.isEmpty) return;
    setState(() {
      for (final ing in elegidos) {
        _items[ing.id] = _ItemReceta(
          ingrediente: ing,
          cantidad: 1,
          controller: TextEditingController(text: '1'),
        );
      }
    });
  }

  Future<void> _guardar() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_categoriaSeleccionada == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Selecciona una categoría')));
      return;
    }

    setState(() => _guardando = true);
    try {
      final ingredientes = _items.values.map((it) {
        final cantidad =
            double.tryParse(it.controller.text.replaceAll(',', '.')) ??
            it.cantidad;
        return it.ingrediente.copyWith(cantidadReceta: cantidad).toJson();
      }).toList();

      final imagen = _imagen.text.trim();
      final datos = <String, dynamic>{
        'nombre': _nombre.text.trim(),
        'descripcion': _descripcion.text.trim(),
        'precio': double.tryParse(_precio.text.replaceAll(',', '.')) ?? 0,
        'categoria': _categoriaSeleccionada,
        'imagen': imagen,
        'disponible': _disponible,
        'ingredientes': ingredientes,
      };

      if (_esEdicion) {
        await ApiService.actualizarProducto(widget.producto!.id, datos);
      } else {
        await ApiService.crearProducto(datos);
      }
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _guardando = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error al guardar: $e')));
    }
  }

  Future<void> _eliminar() async {
    if (!_esEdicion) return;
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
        title: const Text('Eliminar producto'),
        content: Text(
          '¿Seguro que quieres eliminar "${widget.producto!.nombre}"?',
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
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmar != true) return;

    setState(() => _guardando = true);
    try {
      await ApiService.eliminarProducto(widget.producto!.id);
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _guardando = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error al eliminar: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final viewInsets = MediaQuery.of(context).viewInsets;

    return DraggableScrollableSheet(
      initialChildSize: 0.92,
      minChildSize: 0.55,
      maxChildSize: 0.97,
      expand: false,
      builder: (_, scroll) {
        return Container(
          decoration: const BoxDecoration(
            color: _kSheetBg,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Padding(
            padding: EdgeInsets.only(bottom: viewInsets.bottom),
            child: Column(
              children: [
                _buildDragHandle(),
                _buildHeader(),
                Divider(height: 1, color: Colors.white.withValues(alpha: 0.12)),
                if (_cargando)
                  const Expanded(
                    child: Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    ),
                  )
                else
                  Expanded(
                    child: Form(
                      key: _formKey,
                      child: ListView(
                        controller: scroll,
                        padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                        children: [
                          _buildCampoTexto(
                            controlador: _nombre,
                            etiqueta: 'Nombre del plato',
                            icono: Icons.restaurant_menu,
                            requerido: true,
                          ),
                          _buildCampoTexto(
                            controlador: _descripcion,
                            etiqueta: 'Descripción',
                            icono: Icons.notes,
                            maxLines: 3,
                            requerido: true,
                          ),
                          Row(
                            children: [
                              Expanded(
                                child: _buildCampoTexto(
                                  controlador: _precio,
                                  etiqueta: 'Precio',
                                  icono: Icons.euro,
                                  teclado:
                                      const TextInputType.numberWithOptions(
                                        decimal: true,
                                      ),
                                  requerido: true,
                                  esNumero: true,
                                  formatters: [_DecimalInputFormatter()],
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(child: _buildCategoriaDropdown()),
                            ],
                          ),
                          _buildCampoTexto(
                            controlador: _imagen,
                            etiqueta: 'URL de imagen (opcional)',
                            icono: Icons.image_outlined,
                          ),
                          _buildSwitchDisponible(),
                          const SizedBox(height: 8),
                          _buildSeccionIngredientes(),
                          const SizedBox(height: 24),
                          _buildBotones(),
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

  Widget _buildDragHandle() {
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 8),
      child: Container(
        width: 44,
        height: 4,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(4),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 8, 16),
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
              _esEdicion ? Icons.edit_note : Icons.add_circle_outline,
              color: AppColors.button,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _esEdicion ? 'Editar producto' : 'Nuevo producto',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                if (_esEdicion)
                  Text(
                    widget.producto!.nombre,
                    style: const TextStyle(fontSize: 12, color: Colors.white60),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white60),
            onPressed: () => Navigator.pop(context, false),
          ),
        ],
      ),
    );
  }

  InputDecoration _fieldDecoration({
    required String etiqueta,
    required IconData icono,
  }) {
    return InputDecoration(
      labelText: etiqueta,
      labelStyle: const TextStyle(color: Colors.white60),
      prefixIcon: Icon(icono, color: AppColors.gold),
      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.07),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: _kBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: _kBorderFocus, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: AppColors.error.withValues(alpha: 0.8)),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.error, width: 2),
      ),
      errorStyle: const TextStyle(color: AppColors.error),
    );
  }

  Widget _buildCampoTexto({
    required TextEditingController controlador,
    required String etiqueta,
    required IconData icono,
    int maxLines = 1,
    bool requerido = false,
    bool esNumero = false,
    TextInputType? teclado,
    List<TextInputFormatter>? formatters,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextFormField(
        controller: controlador,
        maxLines: maxLines,
        keyboardType: teclado,
        inputFormatters: formatters,
        style: const TextStyle(color: Colors.white),
        cursorColor: AppColors.button,
        validator: (v) {
          if (!requerido) return null;
          if (v == null || v.trim().isEmpty) return 'Campo obligatorio';
          if (esNumero) {
            final n = double.tryParse(v.replaceAll(',', '.'));
            if (n == null) return 'Debe ser un número';
            if (n <= 0) return 'Debe ser mayor que 0';
          }
          return null;
        },
        decoration: _fieldDecoration(etiqueta: etiqueta, icono: icono),
      ),
    );
  }

  Widget _buildCategoriaDropdown() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: DropdownButtonFormField<String>(
        initialValue: _categoriaSeleccionada,
        isExpanded: true,
        dropdownColor: _kSheetBg,
        style: const TextStyle(color: Colors.white),
        iconEnabledColor: Colors.white60,
        items: _categorias
            .map(
              (c) => DropdownMenuItem(
                value: c,
                child: Text(c, style: const TextStyle(color: Colors.white)),
              ),
            )
            .toList(),
        onChanged: (v) => setState(() => _categoriaSeleccionada = v),
        validator: (v) =>
            (v == null || v.isEmpty) ? 'Selecciona una categoría' : null,
        decoration: _fieldDecoration(
          etiqueta: 'Categoría',
          icono: Icons.category,
        ),
      ),
    );
  }

  Widget _buildSwitchDisponible() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _kBorder),
        ),
        child: Row(
          children: [
            Icon(
              _disponible ? Icons.check_circle : Icons.cancel,
              color: _disponible ? AppColors.disp : AppColors.noDisp,
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Disponible para vender',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
            Switch(
              value: _disponible,
              activeThumbColor: AppColors.button,
              activeTrackColor: AppColors.button.withValues(alpha: 0.4),
              inactiveThumbColor: Colors.white38,
              inactiveTrackColor: Colors.white12,
              onChanged: (v) => setState(() => _disponible = v),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSeccionIngredientes() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.kitchen, size: 18, color: AppColors.button),
            const SizedBox(width: 8),
            const Text(
              'Ingredientes y cantidades',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.button.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: AppColors.button.withValues(alpha: 0.4),
                ),
              ),
              child: Text(
                '${_items.length}',
                style: const TextStyle(
                  color: AppColors.button,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_items.isEmpty)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _kBorder),
            ),
            child: const Center(
              child: Text(
                'Aún no se han añadido ingredientes',
                style: TextStyle(color: Colors.white60),
              ),
            ),
          )
        else
          ..._items.values.map(_buildFilaIngrediente),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          height: 46,
          child: OutlinedButton.icon(
            onPressed: _abrirSelectorIngredientes,
            icon: const Icon(Icons.add),
            label: const Text('Añadir ingrediente'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: const BorderSide(color: Color(0x55FFFFFF)),
              backgroundColor: Colors.white.withValues(alpha: 0.06),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFilaIngrediente(_ItemReceta item) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 8, 6, 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _kBorder),
        ),
        child: Row(
          children: [
            Expanded(
              flex: 5,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.ingrediente.nombre,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (item.ingrediente.categoria.isNotEmpty)
                    Text(
                      item.ingrediente.categoria,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.white54,
                      ),
                    ),
                ],
              ),
            ),
            SizedBox(
              width: 70,
              child: TextFormField(
                controller: item.controller,
                textAlign: TextAlign.center,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                  signed: false,
                ),
                inputFormatters: [_DecimalInputFormatter()],
                cursorColor: AppColors.button,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
                decoration: InputDecoration(
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    vertical: 8,
                    horizontal: 8,
                  ),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.1),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: _kBorder),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(
                      color: _kBorderFocus,
                      width: 2,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 6),
            SizedBox(
              width: 38,
              child: Text(
                item.ingrediente.unidad,
                style: const TextStyle(
                  color: Colors.white54,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            IconButton(
              icon: Icon(
                Icons.delete_outline,
                color: AppColors.error.withValues(alpha: 0.8),
              ),
              onPressed: () {
                setState(() {
                  final key = item.ingrediente.id.isEmpty
                      ? item.ingrediente.nombre
                      : item.ingrediente.id;
                  _items[key]?.controller.dispose();
                  _items.remove(key);
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBotones() {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 54,
          child: ElevatedButton(
            onPressed: _guardando ? null : _guardar,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.button,
              foregroundColor: Colors.white,
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
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Text(
                    _esEdicion ? 'GUARDAR CAMBIOS' : 'CREAR PRODUCTO',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
          ),
        ),
        if (_esEdicion) ...[
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton.icon(
              onPressed: _guardando ? null : _eliminar,
              icon: const Icon(Icons.delete_forever_outlined),
              label: const Text('Eliminar producto'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.error,
                side: BorderSide(color: AppColors.error.withValues(alpha: 0.7)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _ItemReceta {
  final Ingrediente ingrediente;
  double cantidad;
  final TextEditingController controller;
  _ItemReceta({
    required this.ingrediente,
    required this.cantidad,
    required this.controller,
  });
}

class _DecimalInputFormatter extends TextInputFormatter {
  static final _re = RegExp(r'^\d*[.,]?\d*$');
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) return newValue;
    return _re.hasMatch(newValue.text) ? newValue : oldValue;
  }
}

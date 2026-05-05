import 'package:flutter/material.dart';
import 'package:frontend/components/Cliente/entrada_texto.dart';
import 'package:frontend/core/colors_style.dart';
import 'package:frontend/models/ingrediente_model.dart';
import 'package:frontend/providers/auth_provider.dart';
import 'package:frontend/services/api_service.dart';
import 'package:provider/provider.dart';

class AdminAnadirMenu extends StatefulWidget {
  const AdminAnadirMenu({super.key});

  @override
  State<AdminAnadirMenu> createState() => _AdminAnadirMenuState();
}

class _AdminAnadirMenuState extends State<AdminAnadirMenu> {
  final _formKey = GlobalKey<FormState>();

  String? _categoriaSeleccionada;
  List<Ingrediente> _ingredientesProducto = [];
  List<String> _categorias = [];
  List<Ingrediente> _ingredientes = [];
  bool _cargando = true;
  bool _guardando = false;

  final TextEditingController _nombreplato = TextEditingController();
  final TextEditingController _descripcionPlato = TextEditingController();
  final TextEditingController _precio = TextEditingController();

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  @override
  void dispose() {
    _nombreplato.dispose();
    _descripcionPlato.dispose();
    _precio.dispose();
    super.dispose();
  }

  Future<void> _cargarDatos() async {
    try {
      final categorias = await ApiService.obtenerCategorias();
      final ingredientes = await ApiService.obtenerIngredientes();
      if (!mounted) return;
      setState(() {
        _categorias = categorias;
        _ingredientes = ingredientes;
        _cargando = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _cargando = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error al cargar datos: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        centerTitle: true,
        title: const Text("AÑADIR AL MENÚ"),
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : _buildBody(),
    );
  }

  Widget _buildBody() {
    return Padding(
      padding: const EdgeInsets.all(10),
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            const SizedBox(height: 30),
            _campoDatos("Nombre", Icons.abc, _nombreplato, _validarObligatorio),
            _campoDatos(
              "Descripción",
              Icons.abc,
              _descripcionPlato,
              _validarObligatorio,
            ),
            _campoDatos("Precio", Icons.euro, _precio, _validarPrecio),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text("Categoría"),
                const SizedBox(width: 16),
                DropdownButton<String>(
                  value: _categoriaSeleccionada,
                  hint: const Text("Seleccionar"),
                  items: _categorias.map((String valor) {
                    return DropdownMenuItem<String>(
                      value: valor,
                      child: Text(valor),
                    );
                  }).toList(),
                  onChanged: (String? nuevoValor) {
                    setState(() => _categoriaSeleccionada = nuevoValor);
                  },
                ),
              ],
            ),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.only(top: 10),
              child: ElevatedButton.icon(
                icon: const Icon(Icons.add),
                label: const Text("Añadir ingredientes"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.backgroundButton,
                  foregroundColor: Colors.white,
                ),
                onPressed: _abrirSelectorIngredientes,
              ),
            ),
            Expanded(
              child: _ingredientesProducto.isEmpty
                  ? const Center(child: Text("No tiene ingredientes"))
                  : ListView.builder(
                      itemCount: _ingredientesProducto.length,
                      itemBuilder: (context, index) {
                        return Padding(
                          padding: const EdgeInsets.all(10.0),
                          child: Container(
                            decoration: BoxDecoration(
                              color: AppColors.sombra.withValues(alpha: 0.1),
                              border: Border.all(
                                color: AppColors.backgroundButton,
                                width: 3,
                              ),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                    ),
                                    child: Text(
                                      _ingredientesProducto[index].nombre,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  onPressed: () {
                                    setState(() {
                                      _ingredientesProducto.removeAt(index);
                                    });
                                  },
                                  icon: const Icon(Icons.remove),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
            _botonGuardar(),
          ],
        ),
      ),
    );
  }

  Padding _campoDatos(
    String etiqueta,
    IconData icono,
    TextEditingController controlador,
    String? Function(String?) validador,
  ) {
    return Padding(
      padding: const EdgeInsets.only(right: 16, left: 16, bottom: 16),
      child: EntradaTexto(
        etiqueta: etiqueta,
        icono: icono,
        controlador: controlador,
        validador: validador,
      ),
    );
  }

  String? _validarObligatorio(String? valor) {
    if (valor == null || valor.trim().isEmpty) return "Campo obligatorio";
    return null;
  }

  String? _validarPrecio(String? valor) {
    if (valor == null || valor.trim().isEmpty) return "Campo obligatorio";
    if (double.tryParse(valor) == null) return "Tiene que ser un número";
    return null;
  }

  Widget _botonGuardar() {
    return Container(
      width: double.infinity,
      height: 55,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(15),
        boxShadow: const [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 10,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: _guardando ? null : _guardar,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.button,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          elevation: 0,
        ),
        child: _guardando
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Text("CREAR PRODUCTO"),
      ),
    );
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;

    if (_categoriaSeleccionada == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Selecciona una categoría")));
      return;
    }

    setState(() => _guardando = true);

    // Sucursal del admin actual: el producto se crea SIEMPRE asignado a su
    // restaurante. Sin esto el producto quedaba huérfano y desaparecía al
    // filtrar por sucursal en cualquier listado del panel.
    final restauranteId = context
        .read<AuthProvider>()
        .usuarioActual
        ?.restauranteId;

    try {
      await ApiService.crearProducto({
        'nombre': _nombreplato.text.trim(),
        'descripcion': _descripcionPlato.text.trim(),
        'precio': double.parse(_precio.text.trim()),
        'categoria': _categoriaSeleccionada,
        'ingredientes': _ingredientesProducto.map((i) => i.nombre).toList(),
        'disponible': true,
        if (restauranteId != null && restauranteId.isNotEmpty)
          'restaurante_id': restauranteId,
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Producto creado correctamente")),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error al crear el producto: $e")));
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  void _abrirSelectorIngredientes() async {
    // Pre-cargamos los ya seleccionados para evitar duplicados
    List<Ingrediente> seleccionados = List.from(_ingredientesProducto);

    final resultado = await showModalBottomSheet<List<Ingrediente>>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return SizedBox(
              height: 400,
              child: Column(
                children: [
                  Expanded(
                    child: ListView.builder(
                      itemCount: _ingredientes.length,
                      itemBuilder: (context, index) {
                        final item = _ingredientes[index];
                        return CheckboxListTile(
                          title: Text(item.nombre),
                          value: seleccionados.any(
                            (i) => i.nombre == item.nombre,
                          ),
                          onChanged: (bool? marcado) {
                            setModalState(() {
                              if (marcado == true) {
                                seleccionados.add(item);
                              } else {
                                seleccionados.removeWhere(
                                  (i) => i.nombre == item.nombre,
                                );
                              }
                            });
                          },
                        );
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.backgroundButton,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 48),
                      ),
                      onPressed: () => Navigator.pop(context, seleccionados),
                      child: const Text("CONFIRMAR SELECCIÓN"),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    if (resultado != null) {
      setState(() => _ingredientesProducto = resultado);
    }
  }
}

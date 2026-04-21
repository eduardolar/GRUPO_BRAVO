import 'package:flutter/material.dart';
import 'package:frontend/components/Cliente/entrada_texto.dart';
import 'package:frontend/core/colors_style.dart';
import 'package:frontend/models/ingrediente_model.dart';
import 'package:frontend/services/api_service.dart';

class AdminAnadirMenu extends StatefulWidget {
  const AdminAnadirMenu({super.key});

  @override
  State<AdminAnadirMenu> createState() => _AdminAnadirMenuState();
}

class _AdminAnadirMenuState extends State<AdminAnadirMenu> {
  // Key para el formulario
  final _formKey = GlobalKey<FormState>();

  // Variables para registrar las elecciones hechas mediante botones, no pudiendo usar controladores
  String? _categoriaSeleccionada;
  List<Ingrediente> _ingredientesProducto = [];

  // Obtenemos listas con los datos que ya tenemos en la base de datos de las CATEGORÍAS disponibles e INGREDIENTES
  List<String> _categorias = [];
  List<Ingrediente> _ingredientes = [];
  bool _cargando = true;

  // Controladores campos de texto
  final TextEditingController _nombreplato = TextEditingController();
  final TextEditingController _descripcionPlato = TextEditingController();
  final TextEditingController _precio = TextEditingController();

  @override
  void initState() {
    super.initState();
    _cargarDatos();
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
    }
  }

  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBarAnadirMenu(),
      body: BodyAnadirMenu(),
    );
  }

  Widget BodyAnadirMenu() {
    return Padding(
      padding: EdgeInsetsGeometry.all(10),
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            SizedBox(height: 30),
            DatosProducto("Nombre", Icons.abc, _nombreplato, validadorCampoObligatorioString),
            DatosProducto("Descripción", Icons.abc, _descripcionPlato, validadorCampoObligatorioString),
            DatosProducto("Precio", Icons.euro, _precio, validadorCampoObligatorioInt),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text("Categoría"),
                SizedBox(width: 16),
                DropdownButton(
                  value: _categoriaSeleccionada,
                  hint: const Text(""),
                  items: _categorias.map((String valor) {
                    return DropdownMenuItem<String>(
                      value: valor,
                      child: Text(valor),
                    );
                  }).toList(),
                  onChanged: (String? nuevoValor) {
                    setState(() {
                      _categoriaSeleccionada = nuevoValor;
                    });
                  },
                ),
              ],
            ),
            Container(
              width: double.infinity,
              padding: EdgeInsets.only(top: 10),
              child: FloatingActionButton(
                backgroundColor: AppColors.backgroundButton,
                foregroundColor: Colors.white,
                child: Text("Añadir ingredientes"),
                onPressed: () {
                  _abrirSelectorMultiple();
                },
              ),
            ),
            Expanded(
              child: Container(
                child: _ingredientesProducto.isEmpty
                    ? const Center(child: Text("No tiene ingredientes"))
                    : ListView.builder(
                        itemCount: _ingredientesProducto.length,
                        /*itemBuilder: (context, index) => ListTile(
                    
                    title: Text(_ingredientesProducto[index].nombre, style: ,),*/
                        // ASI FUNCIONARIA
                        itemBuilder: (context, index) {
                          return Padding(
                            padding: const EdgeInsets.all(10.0),
                            child: Container(
                              decoration: BoxDecoration(
                                color: AppColors.sombra.withOpacity(0.1),
                                border: Border.all(
                                  color: AppColors.backgroundButton,
                                  width: 3,
                                ),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                // Fila por cada ingrediente añadido al plato
                                children: [
                                  Expanded(
                                    child: Text(
                                      _ingredientesProducto[index].nombre,
                                    ),
                                  ), // Nombre del ingrediente
                                  IconButton(
                                    onPressed: () {
                                      _ingredientesProducto.remove(
                                        _ingredientesProducto[index],
                                      ); // boton para eliminarlo
                                      setState(() {});
                                    },
                                    icon: Icon(Icons.remove),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ),
            botonGuardar(),
          ],
        ),
      ),
    );
  }

  AppBar AppBarAnadirMenu() {
    return AppBar(
      backgroundColor: AppColors.background,
      centerTitle: true,
      title: Text("AÑADIR AL MENÚ"),
    );
  }

  Padding DatosProducto(
    String etiqueta,
    IconData icono,
    TextEditingController controlador,
    String? Function(String?) validador,
  ) {
    return Padding(
      padding: EdgeInsetsGeometry.only(right: 16, left: 16, bottom: 16),
      child: EntradaTexto(
        etiqueta: etiqueta,
        icono: icono,
        controlador: controlador,
        validador: validador, // Validación para campos obligatorios
      ),
    );
  }

  String? validadorCampoObligatorioString(String? valor) {
    if (valor == null || valor.isEmpty) {
      return "Campo obligatorio";
    }
    return null;
  }

  String? validadorCampoObligatorioInt(String? valor) {
    if (valor == null || valor.isEmpty) {
      return "Campo obligatorio";
    }
    if (double.tryParse(valor) == null) {
      return "Tiene que ser un número";
    }
    return null;
  }

  Widget botonGuardar() {
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
        onPressed: () {
          if (_formKey.currentState!.validate()) {
            // Añadir lógica para enviar este nuevo ingrediente al servidor
            print("guardando nuevo plato...");
            Navigator.pop(context);
          } else {
            print("Formulario no válido");
          }
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.button,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          elevation: 0,
        ),
        child: Text("CREAR PRODUCTO"),
      ),
    );
  }

  void _abrirSelectorMultiple() async {
    // Lista temporal para manejar las selecciones en la ventana emergente
    List<Ingrediente> ingredientesSeleccionados = [];

    final resultado = await showModalBottomSheet<List<Ingrediente>>(
      context: context,
      builder: (context) {
        // Usamos un StatefulBuilder para refrescar solo el panel emergente
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Container(
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
                          value: ingredientesSeleccionados.contains(item),
                          onChanged: (bool? marcado) {
                            setModalState(() {
                              if (marcado == true) {
                                ingredientesSeleccionados.add(item);
                              } else {
                                ingredientesSeleccionados.remove(item);
                              }
                            });
                          },
                        );
                      },
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () =>
                        Navigator.pop(context, ingredientesSeleccionados),
                    child: const Text("AÑADIR INGREDIENTES"),
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    // Al cerrar el panel, añadimos los seleccionados a la lista principal
    if (resultado != null && resultado.isNotEmpty) {
      setState(() {
        _ingredientesProducto.addAll(resultado);
      });
    }
  }
}

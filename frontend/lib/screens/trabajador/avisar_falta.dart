import 'package:flutter/material.dart';
import '../../core/colors_style.dart';
import '../../services/api_service.dart';
import '../../models/producto_model.dart';

class AvisarFaltaScreen extends StatefulWidget {
  const AvisarFaltaScreen({super.key});
  @override
  State<AvisarFaltaScreen> createState() => _AvisarFaltaScreenState();
}

class _AvisarFaltaScreenState extends State<AvisarFaltaScreen> {
  List<Producto> _ingredientes = [];
  final Set<String> _seleccionados = {};
  bool _cargando = true;

   void initState() {
    super.initState();
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    final productos = await ApiService.obtenerIngredientes();
    setState(() {
      _ingredientes = productos;
      _cargando = false;
    });
  }

  void _enviarReporte() {
    // Simulación de envío de correo
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Enviando aviso de ${_seleccionados.length} productos al jefe...")),
    );
    setState(() => _seleccionados.clear());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text("AVISAR BAJO STOCK"), backgroundColor: AppColors.background),
      body: _cargando 
        ? const Center(child: CircularProgressIndicator()) 
        : Column(
            children: [
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _ingredientes.length,
                  itemBuilder: (context, index) {
                    final p = _ingredientes[index];
                    final esSeleccionado = _seleccionados.contains(p.id);
                    return CheckboxListTile(
                      title: Text(p.nombre, style: const TextStyle(color: Colors.white)),
                      subtitle: Text(p.categoria, style: const TextStyle(color: AppColors.textSecondary)),
                      tileColor: AppColors.panel,
                      checkColor: Colors.black,
                      activeColor: AppColors.gold,
                      value: esSeleccionado,
                      onChanged: (val) {
                        setState(() {
                          val! ? _seleccionados.add(p.id) : _seleccionados.remove(p.id);
                        });
                      },
                    );
                  },
                ),
              ),
              if (_seleccionados.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.gold),
                      onPressed: _enviarReporte,
                      icon: const Icon(Icons.mail_outline, color: Colors.black),
                      label: const Text("NOTIFICAR AL JEFE", style: TextStyle(color: Colors.black)),
                    ),
                  ),
                ),
            ],
          ),
    );
  }
}
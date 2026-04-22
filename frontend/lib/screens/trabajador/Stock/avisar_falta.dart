import 'package:flutter/material.dart';
import '../../../core/colors_style.dart';
import '../../../services/api_service.dart';
import '../../../models/ingrediente_model.dart';
import '../../../components/trabajador/app_layout.dart';

class AvisarFaltaScreen extends StatefulWidget {
  const AvisarFaltaScreen({super.key});
  @override
  State<AvisarFaltaScreen> createState() => _AvisarFaltaScreenState();
}

class _AvisarFaltaScreenState extends State<AvisarFaltaScreen> {
  List<Ingrediente> _ingredientes = [];
  final Set<String> _seleccionados = {};
  bool _cargando = true;

   void initState() {
    super.initState();
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    final ingredientes = await ApiService.obtenerIngredientes();
    setState(() {
      _ingredientes = ingredientes;
      _cargando = false;
    });
  }

  void _enviarReporte() {
    // Simulación de envío de correo
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Enviando aviso de ${_seleccionados.length} ingredientes al jefe...")),
    );
    setState(() => _seleccionados.clear());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      extendBodyBehindAppBar: true,
      appBar: const TrabajadorAppBar(title: "Avisar Falta de Producto"),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: kToolbarHeight + 40),
            Expanded(
              child: _cargando
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
                            return GestureDetector(
                              onTap: () {
                                setState(() {
                                  esSeleccionado ? _seleccionados.remove(p.id) : _seleccionados.add(p.id);
                                });
                              },
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 10),
                                decoration: BoxDecoration(
                                  color: AppColors.backgroundButton,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: esSeleccionado ? AppColors.background : AppColors.line,
                                    width: esSeleccionado ? 2 : 1,
                                  ),
                                ),
                                child: ListTile(
                                  title: Text(
                                    p.nombre,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  subtitle: Text(
                                    "${p.cantidadActual.toStringAsFixed(1)} ${p.unidad} (mín: ${p.stockMinimo.toStringAsFixed(1)})",
                                    style: const TextStyle(color: Colors.white70),
                                  ),
                                  trailing: Icon(
                                    esSeleccionado ? Icons.check_circle : Icons.circle_outlined,
                                    color: esSeleccionado ? AppColors.background : Colors.white70,
                                  ),
                                ),
                              ),
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
                              style: ElevatedButton.styleFrom(backgroundColor: AppColors.backgroundButton),
                              onPressed: _enviarReporte,
                              icon: const Icon(Icons.mail_outline, color: Colors.white),
                              label: const Text("NOTIFICAR AL JEFE", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            ),
                          ),
                        ),
                    ],
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      color: AppColors.backgroundButton,
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
      child: Column(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 1.5),
            ),
            child: const Icon(
              Icons.warning_amber_outlined,
              color: Colors.white,
              size: 24,
            ),
          ),

          const SizedBox(height: 12),

          const Text(
            "Avisar de Falta",
            style: TextStyle(
              fontFamily: 'Playfair Display',
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),

          const SizedBox(height: 6),

          Text(
            "SELECCIONA LOS INGREDIENTES",
            style: TextStyle(
              color: Colors.white70,
              fontSize: 10,
              letterSpacing: 3,
              fontWeight: FontWeight.w400,
            ),
          ),

          const SizedBox(height: 16),

          Row(
            children: [
              const Expanded(child: Divider(color: AppColors.line)),
              Container(
                width: 60,
                height: 1.5,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.transparent,
                      Colors.white,
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
              const Expanded(child: Divider(color: AppColors.line)),
            ],
          ),
        ],
      ),
    );
  }
}
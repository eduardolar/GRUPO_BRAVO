import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/colors_style.dart';
import '../../../core/app_snackbar.dart';
import '../../../providers/auth_provider.dart';
import '../../../services/api_service.dart';
import '../../../services/aviso_falta_service.dart';
import '../../../models/ingrediente_model.dart';
import '../appbar_trabajador.dart';

class AvisarFaltaScreen extends StatefulWidget {
  const AvisarFaltaScreen({super.key});
  @override
  State<AvisarFaltaScreen> createState() => _AvisarFaltaScreenState();
}

class _AvisarFaltaScreenState extends State<AvisarFaltaScreen> {
  List<Ingrediente> _ingredientes = [];
  final Set<String> _seleccionados = {};
  bool _cargando = true;
  bool _enviando = false;
  final TextEditingController _notasCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  @override
  void dispose() {
    _notasCtrl.dispose();
    super.dispose();
  }

  Future<void> _cargarDatos() async {
    final restauranteId =
        context.read<AuthProvider>().usuarioActual?.restauranteId;
    try {
      final ingredientes = await ApiService.obtenerIngredientes(
        restauranteId: restauranteId,
      );
      if (!mounted) return;
      setState(() {
        _ingredientes = ingredientes;
        _cargando = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _cargando = false);
      handleApiError(context, e, prefix: 'Error al cargar ingredientes');
    }
  }

  Future<void> _notificar() async {
    if (_seleccionados.isEmpty || _enviando) return;

    setState(() => _enviando = true);
    try {
      final seleccionados = _ingredientes
          .where((p) => _seleccionados.contains(p.id))
          .toList();
      final notas = _notasCtrl.text.trim();

      // Enviamos un aviso por cada ingrediente seleccionado
      await Future.wait(
        seleccionados.map(
          (ing) => AvisoFaltaService.crear(
            nombre: ing.nombre,
            ingredienteId: ing.id,
            notas: notas.isNotEmpty ? notas : null,
          ),
        ),
      );

      if (!mounted) return;
      showAppSuccess(
        context,
        '${seleccionados.length == 1 ? 'Aviso enviado' : '${seleccionados.length} avisos enviados'} al administrador.',
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      setState(() => _enviando = false);
      handleApiError(context, e, prefix: 'No se pudo enviar el aviso');
    }
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
                              final esSeleccionado = _seleccionados.contains(
                                p.id,
                              );
                              return GestureDetector(
                                onTap: () {
                                  setState(() {
                                    esSeleccionado
                                        ? _seleccionados.remove(p.id)
                                        : _seleccionados.add(p.id);
                                  });
                                },
                                child: Container(
                                  margin: const EdgeInsets.only(bottom: 10),
                                  decoration: BoxDecoration(
                                    color: AppColors.backgroundButton,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: esSeleccionado
                                          ? AppColors.background
                                          : AppColors.line,
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
                                      style: const TextStyle(
                                        color: Colors.white70,
                                      ),
                                    ),
                                    trailing: Icon(
                                      esSeleccionado
                                          ? Icons.check_circle
                                          : Icons.circle_outlined,
                                      color: esSeleccionado
                                          ? AppColors.background
                                          : Colors.white70,
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        if (_seleccionados.isNotEmpty) ...[
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                            child: TextField(
                              controller: _notasCtrl,
                              style: const TextStyle(color: Colors.white),
                              maxLines: 2,
                              decoration: InputDecoration(
                                hintText: 'Notas adicionales (opcional)',
                                hintStyle: const TextStyle(
                                  color: Colors.white54,
                                ),
                                filled: true,
                                fillColor: AppColors.backgroundButton,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(
                                    color: AppColors.line,
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(
                                    color: AppColors.line,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                            child: SizedBox(
                              width: double.infinity,
                              height: 55,
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.backgroundButton,
                                ),
                                onPressed: _enviando ? null : _notificar,
                                icon: _enviando
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          color: Colors.white70,
                                          strokeWidth: 1.5,
                                        ),
                                      )
                                    : const Icon(
                                        Icons.mail_outline,
                                        color: Colors.white,
                                      ),
                                label: Text(
                                  _enviando
                                      ? 'ENVIANDO...'
                                      : 'NOTIFICAR AL JEFE',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

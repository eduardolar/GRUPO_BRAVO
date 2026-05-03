import 'package:flutter/material.dart';
import '../../core/colors_style.dart';
import '../../models/pedido_model.dart';
import '../../services/pedido_service.dart';
import 'package:intl/intl.dart';

class AdminContabilidadScreen extends StatefulWidget {
  const AdminContabilidadScreen({super.key});

  @override
  State<AdminContabilidadScreen> createState() => _AdminContabilidadScreenState();
}

class _AdminContabilidadScreenState extends State<AdminContabilidadScreen> {
  DateTime _fechaInicio = DateTime.now();
  DateTime _fechaFin = DateTime.now();
  
  final DateFormat _dateFormat = DateFormat('dd/MM/yyyy');

  // Función única que abre el calendario pequeño para Desde o Hasta
  Future<void> _seleccionarFecha(BuildContext context, bool esInicio) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      helpText: esInicio ? 'SELECCIONA FECHA DE INICIO' : 'SELECCIONA FECHA DE FIN',
      initialDate: esInicio ? _fechaInicio : _fechaFin,
      firstDate: DateTime(2023),
      lastDate: DateTime.now(),
      builder: (context, child) => _pickerTheme(context, child!),
    );

    if (picked != null) {
      setState(() {
        if (esInicio) {
          _fechaInicio = picked;
          // Si el inicio es después del fin, actualizamos el fin automáticamente
          if (_fechaInicio.isAfter(_fechaFin)) {
            _fechaFin = _fechaInicio;
          }
        } else {
          _fechaFin = picked;
          // Si el fin es antes del inicio, actualizamos el inicio automáticamente
          if (_fechaFin.isBefore(_fechaInicio)) {
            _fechaInicio = _fechaFin;
          }
        }
      });
    }
  }

  // Tematizamos el calendario pequeño con los colores corporativos
  Widget _pickerTheme(BuildContext context, Widget child) {
    return Theme(
      data: Theme.of(context).copyWith(
        colorScheme: const ColorScheme.light(
          primary: AppColors.button,
          onPrimary: Colors.white,
          onSurface: AppColors.textPrimary,
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(foregroundColor: AppColors.button),
        ),
      ),
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('CONTABILIDAD Y VENTAS', 
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1.2, fontSize: 16)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Stack(
        children: [
          Container(
            width: double.infinity, height: double.infinity,
            decoration: const BoxDecoration(
              image: DecorationImage(image: AssetImage('assets/images/Bravo restaurante.jpg'), fit: BoxFit.cover),
            ),
          ),
          Container(
            width: double.infinity, height: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter,
                colors: [Colors.black.withValues(alpha:0.7), Colors.black.withValues(alpha:0.9)]),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                // NUEVA TARJETA DE FILTRO (Estilo "Desde" / "Hasta")
                _buildFilterCard(),

                Expanded(
                  child: FutureBuilder<List<Pedido>>(
                    future: PedidoService.obtenerTodosLosPedidos(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator(color: AppColors.button));
                      }
                      
                      final pedidos = (snapshot.data ?? []).where((p) {
                        DateTime f = DateTime.tryParse(p.fecha.toString()) ?? DateTime.now();
                        
                        // Normalizamos las fechas para que coja todo el día desde las 00:00 hasta las 23:59
                        DateTime inicioFiltro = DateTime(_fechaInicio.year, _fechaInicio.month, _fechaInicio.day);
                        DateTime finFiltro = DateTime(_fechaFin.year, _fechaFin.month, _fechaFin.day, 23, 59, 59);

                        return f.isAfter(inicioFiltro.subtract(const Duration(seconds: 1))) &&
                               f.isBefore(finFiltro.add(const Duration(seconds: 1)));
                      }).toList();

                      double totalIngresos = pedidos.fold(0, (sum, p) => sum + p.total);
                      double ticketMedio = pedidos.isEmpty ? 0 : totalIngresos / pedidos.length;

                      return Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16.0),
                            child: Row(
                              children: [
                                _buildMetricCard('Ingresos', '${totalIngresos.toStringAsFixed(2)}€', Icons.euro, AppColors.disp),
                                const SizedBox(width: 10),
                                _buildMetricCard('Pedidos', '${pedidos.length}', Icons.shopping_bag, const Color(0xFF3B82F6)),
                                const SizedBox(width: 10),
                                _buildMetricCard('Ticket Medio', '${ticketMedio.toStringAsFixed(2)}€', Icons.analytics, Colors.orangeAccent),
                              ],
                            ),
                          ),
                          const Padding(
                            padding: EdgeInsets.all(20.0),
                            child: Align(alignment: Alignment.centerLeft,
                              child: Text('HISTORIAL DE VENTAS', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                          ),
                          Expanded(
                            child: pedidos.isEmpty 
                              ? const Center(child: Text("No hay datos para esta selección", style: TextStyle(color: Colors.white54)))
                              : ListView.builder(
                                  padding: const EdgeInsets.symmetric(horizontal: 16),
                                  itemCount: pedidos.length,
                                  itemBuilder: (context, index) {
                                    final pedido = pedidos[index];
                                    DateTime f = DateTime.tryParse(pedido.fecha.toString()) ?? DateTime.now();
                                    return Card(
                                      color: Colors.white.withValues(alpha:0.95),
                                      margin: const EdgeInsets.only(bottom: 12),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                      child: ListTile(
                                        title: Text('Pedido #${pedido.id.substring(pedido.id.length - 5)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                                        subtitle: Text('${_dateFormat.format(f)} - ${pedido.tipoEntrega}'),
                                        trailing: Text('${pedido.total.toStringAsFixed(2)}€', style: const TextStyle(color: AppColors.disp, fontWeight: FontWeight.w900)),
                                      ),
                                    );
                                  },
                                ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterCard() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha:0.3), blurRadius: 10)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('FILTRAR POR FECHAS', style: TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Row(
            children: [
              // BOTÓN DESDE
              Expanded(
                child: GestureDetector(
                  onTap: () => _seleccionarFecha(context, true),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Desde', style: TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.calendar_today, size: 14, color: AppColors.button),
                            const SizedBox(width: 6),
                            Text(_dateFormat.format(_fechaInicio), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 10),
                child: Icon(Icons.arrow_forward_ios, color: Colors.grey, size: 14),
              ),
              // BOTÓN HASTA
              Expanded(
                child: GestureDetector(
                  onTap: () => _seleccionarFecha(context, false),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Hasta', style: TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.calendar_today, size: 14, color: AppColors.button),
                            const SizedBox(width: 6),
                            Text(_dateFormat.format(_fechaFin), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard(String label, String value, IconData icon, Color accentColor) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha:0.9),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: accentColor.withValues(alpha:0.5), width: 2),
        ),
        child: Column(
          children: [
            Icon(icon, color: accentColor.withValues(alpha:0.8), size: 22),
            const SizedBox(height: 8),
            Text(value, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: Colors.black87)),
            Text(label, style: const TextStyle(fontSize: 9, color: Colors.black54, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
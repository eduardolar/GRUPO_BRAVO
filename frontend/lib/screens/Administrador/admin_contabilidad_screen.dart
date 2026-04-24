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
  DateTime _fechaInicio = DateTime.now().subtract(const Duration(days: 7));
  DateTime _fechaFin = DateTime.now();
  
  // Formateador para mostrar las fechas bonitas
  final DateFormat _dateFormat = DateFormat('dd/MM/yyyy');

  Future<void> _seleccionarRangoFechas(BuildContext context) async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2023),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      initialDateRange: DateTimeRange(start: _fechaInicio, end: _fechaFin),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.button,
              onPrimary: Colors.white,
              onSurface: AppColors.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _fechaInicio = picked.start;
        _fechaFin = picked.end;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100, // Fondo ligeramente más gris para contrastar con las tarjetas blancas
      appBar: AppBar(
        title: const Text('Contabilidad y Ventas'),
        backgroundColor: AppColors.backgroundButton,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_month),
            onPressed: () => _seleccionarRangoFechas(context),
          ),
        ],
      ),
      body: Column(
        children: [
          // Selector de fechas visual (Ahora es una tarjeta definida)
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 8,
                  offset: Offset(0, 2),
                )
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Rango seleccionado:', 
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade700, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${_dateFormat.format(_fechaInicio)} - ${_dateFormat.format(_fechaFin)}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87),
                    ),
                  ],
                ),
                ElevatedButton.icon(
                  onPressed: () => _seleccionarRangoFechas(context),
                  icon: const Icon(Icons.filter_list, size: 18),
                  label: const Text('Filtrar'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.button,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                )
              ],
            ),
          ),

          Expanded(
            child: FutureBuilder<List<Pedido>>(
              future: PedidoService.obtenerTodosLosPedidos(), // Conexión al Backend
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      'Error: ${snapshot.error}',
                      style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                    ),
                  );
                }

                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return Center(
                    child: Text(
                      'No hay pedidos registrados en el sistema.',
                      style: TextStyle(color: Colors.grey.shade800, fontSize: 16),
                    ),
                  );
                }

                // Filtrar pedidos por el rango de fechas seleccionado
                final pedidos = snapshot.data!.where((p) {
                  DateTime fechaPedido;
                  try {
                    fechaPedido = DateTime.parse(p.fecha.toString());
                  } catch (e) {
                    fechaPedido = DateTime.now(); 
                  }

                  return fechaPedido.isAfter(_fechaInicio.subtract(const Duration(seconds: 1))) &&
                         fechaPedido.isBefore(_fechaFin.add(const Duration(days: 1)));
                }).toList();

                if (pedidos.isEmpty) {
                  return Center(
                    child: Text(
                      'No hay pedidos en este rango de fechas.',
                      style: TextStyle(color: Colors.grey.shade800, fontSize: 16),
                    ),
                  );
                }

                // CÁLCULO DE MÉTRICAS 
                double totalIngresos = pedidos.fold(0, (sum, p) => sum + p.total);
                double ticketMedio = totalIngresos / pedidos.length;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Dashboard de Resumen con alto contraste
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Row(
                        children: [
                          _buildMetricCard('Ingresos', '${totalIngresos.toStringAsFixed(2)}€', Icons.euro, Colors.green.shade600),
                          const SizedBox(width: 12),
                          _buildMetricCard('Pedidos', '${pedidos.length}', Icons.shopping_bag, Colors.blue.shade600),
                          const SizedBox(width: 12),
                          _buildMetricCard('Ticket Medio', '${ticketMedio.toStringAsFixed(2)}€', Icons.analytics, Colors.orange.shade700),
                        ],
                      ),
                    ),
                    
                    const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Text(
                        'Detalle de Ventas',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
                      ),
                    ),

                    // Lista de Pedidos rediseñada
                    Expanded(
                      child: ListView.builder(
                        itemCount: pedidos.length,
                        itemBuilder: (context, index) {
                          final pedido = pedidos[index];
                          
                          DateTime fechaMostrar;
                          try {
                            fechaMostrar = DateTime.parse(pedido.fecha.toString());
                          } catch (e) {
                            fechaMostrar = DateTime.now();
                          }

                          return Card(
                            elevation: 2, // Sombra más definida
                            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(color: Colors.grey.shade200), // Borde sutil
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              leading: CircleAvatar(
                                radius: 24,
                                backgroundColor: AppColors.button.withOpacity(0.1),
                                child: const Icon(Icons.receipt_long, color: AppColors.button),
                              ),
                              title: Text(
                                'Pedido #${pedido.id.substring(pedido.id.length - 5)}',
                                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87),
                              ),
                              subtitle: Padding(
                                padding: const EdgeInsets.only(top: 4.0),
                                child: Text(
                                  '${_dateFormat.format(fechaMostrar)} - ${pedido.tipoEntrega}',
                                  style: TextStyle(color: Colors.grey.shade800, fontWeight: FontWeight.w500),
                                ),
                              ),
                              trailing: Text(
                                '${pedido.total.toStringAsFixed(2)}€',
                                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: Colors.green.shade700),
                              ),
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
    );
  }

  // Widget auxiliar rediseñado con alto contraste
  Widget _buildMetricCard(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.3), width: 1.5), // Borde de color
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.1), // Sombra coloreada sutil
              blurRadius: 10, 
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 28), // Icono más grande y saturado
            ),
            const SizedBox(height: 12),
            Text(
              value, 
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Colors.black87), // Valor oscuro y grueso
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              label, 
              style: TextStyle(fontSize: 11, color: Colors.grey.shade700, fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
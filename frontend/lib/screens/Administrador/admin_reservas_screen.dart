import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../components/bravo_app_bar.dart';
import '../../core/colors_style.dart';
import '../../models/mesa_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/mesa_service.dart';
import '../../services/reserva_service.dart';

// ─── Constantes de estilo ─────────────────────────────────────────────────────
const _kSheetBg = AppColors.bottomSheetBg;
// Negro translúcido (alpha ~55%): sobre la imagen Bravo de fondo el blanco
// translúcido se confundía con el papel claro y dejaba el texto invisible.
const _kFieldFill = Color(0x8C000000);
const _kBorder = Color(0x33FFFFFF);

class AdminReservasScreen extends StatefulWidget {
  const AdminReservasScreen({super.key});

  @override
  State<AdminReservasScreen> createState() => _AdminReservasScreenState();
}

class _AdminReservasScreenState extends State<AdminReservasScreen> {
  List<Map<String, dynamic>> _reservas = [];
  bool _cargando = true;
  String? _error;

  DateTime _fechaSeleccionada = DateTime.now();
  // null = todas
  String? _filtroEstado;

  static const _estadosFiltro = [
    null,
    'Pendiente',
    'Confirmada',
    'Cancelada',
    'Llegado',
    'NoShow',
  ];
  static const _etiquetasFiltro = [
    'Todas',
    'Pendientes',
    'Confirmadas',
    'Canceladas',
    'Llegado',
    'No Show',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _cargar());
  }

  String get _fechaStr {
    final f = _fechaSeleccionada;
    return '${f.year.toString().padLeft(4, '0')}-'
        '${f.month.toString().padLeft(2, '0')}-'
        '${f.day.toString().padLeft(2, '0')}';
  }

  Future<void> _cargar() async {
    if (!mounted) return;
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final lista = await ReservaService.obtenerReservasAdmin(
        fecha: _fechaStr,
        estado: _filtroEstado,
      );
      if (!mounted) return;
      setState(() {
        _reservas = lista;
        _cargando = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _cargando = false;
      });
    }
  }

  Future<void> _seleccionarFecha() async {
    final elegida = await showDatePicker(
      context: context,
      initialDate: _fechaSeleccionada,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (ctx, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(
            primary: AppColors.button,
            surface: AppColors.bottomSheetBg,
          ),
        ),
        child: child!,
      ),
    );
    if (elegida != null && elegida != _fechaSeleccionada) {
      setState(() => _fechaSeleccionada = elegida);
      _cargar();
    }
  }

  Future<void> _cambiarEstado(String id, String nuevoEstado) async {
    try {
      await ReservaService.cambiarEstadoReserva(id, nuevoEstado);
      _cargar();
    } catch (e) {
      if (mounted) {
        _showSnack(e.toString());
      }
    }
  }

  Future<void> _abrirAsignarMesa(Map<String, dynamic> reserva) async {
    final restauranteId =
        context.read<AuthProvider>().usuarioActual?.restauranteId;
    List<Mesa> mesas = [];
    bool cargandoMesas = true;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setS) {
            // Cargamos las mesas una sola vez al abrir
            if (cargandoMesas) {
              MesaService.obtenerMesas(restauranteId: restauranteId).then((m) {
                setS(() {
                  mesas = m;
                  cargandoMesas = false;
                });
              }).catchError((_) {
                setS(() => cargandoMesas = false);
              });
            }

            return Container(
              decoration: const BoxDecoration(
                color: _kSheetBg,
                borderRadius:
                    BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'ASIGNAR MESA',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (cargandoMesas)
                    const Center(
                      child: CircularProgressIndicator(
                          color: AppColors.button),
                    )
                  else if (mesas.isEmpty)
                    const Text(
                      'No hay mesas disponibles.',
                      style: TextStyle(color: Colors.white54),
                    )
                  else
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight:
                            MediaQuery.of(ctx).size.height * 0.4,
                      ),
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: mesas.length,
                        separatorBuilder: (_, _) =>
                            const Divider(color: Colors.white12),
                        itemBuilder: (_, i) {
                          final m = mesas[i];
                          return ListTile(
                            title: Text(
                              'Mesa ${m.numero}',
                              style: const TextStyle(color: Colors.white),
                            ),
                            subtitle: Text(
                              '${m.capacidad} personas · ${m.ubicacion}'
                              '${m.disponible ? '' : ' · Ocupada'}',
                              style: TextStyle(
                                color: m.disponible
                                    ? Colors.white54
                                    : AppColors.error,
                              ),
                            ),
                            trailing: m.disponible
                                ? const Icon(Icons.check_circle_outline,
                                    color: AppColors.disp)
                                : null,
                            onTap: () async {
                              Navigator.pop(ctx);
                              try {
                                await ReservaService.asignarMesaReserva(
                                  reserva['id'] as String,
                                  m.id,
                                );
                                _cargar();
                                if (mounted) {
                                  _showSnack(
                                    'Mesa ${m.numero} asignada',
                                    esExito: true,
                                  );
                                }
                              } catch (e) {
                                if (mounted) _showSnack(e.toString());
                              }
                            },
                          );
                        },
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showSnack(String msg, {bool esExito = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg,
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: esExito ? AppColors.disp : AppColors.error,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: const BravoAppBar(title: 'RESERVAS'),
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
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withValues(alpha: 0.5),
                Colors.black.withValues(alpha: 0.92),
              ],
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                _buildCabecera(),
                _buildChipsFiltro(),
                const SizedBox(height: 4),
                Expanded(child: _buildCuerpo()),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCabecera() {
    final hoy = DateTime.now();
    final esHoy = _fechaSeleccionada.year == hoy.year &&
        _fechaSeleccionada.month == hoy.month &&
        _fechaSeleccionada.day == hoy.day;
    final esManana = _fechaSeleccionada.difference(
              DateTime(hoy.year, hoy.month, hoy.day),
            ).inDays ==
        1;

    String etiqueta;
    if (esHoy) {
      etiqueta = 'Hoy';
    } else if (esManana) {
      etiqueta = 'Mañana';
    } else {
      etiqueta = _fechaStr;
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        children: [
          // Selector de fecha
          Expanded(
            child: InkWell(
              onTap: _seleccionarFecha,
              borderRadius: BorderRadius.circular(12),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: _kFieldFill,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _kBorder),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today,
                            color: AppColors.button, size: 18),
                        const SizedBox(width: 10),
                        Text(
                          etiqueta,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),
                        const Spacer(),
                        const Icon(Icons.expand_more,
                            color: Colors.white38, size: 20),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          // Botón actualizar
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                decoration: BoxDecoration(
                  color: _kFieldFill,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _kBorder),
                ),
                child: IconButton(
                  icon: _cargando
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.button,
                          ),
                        )
                      : const Icon(Icons.refresh,
                          color: Colors.white70),
                  onPressed: _cargando ? null : _cargar,
                  tooltip: 'Actualizar reservas',
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChipsFiltro() {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _estadosFiltro.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final seleccionado = _filtroEstado == _estadosFiltro[i];
          return GestureDetector(
            onTap: () {
              setState(() => _filtroEstado = _estadosFiltro[i]);
              _cargar();
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: seleccionado
                    ? AppColors.button
                    : Colors.black.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: seleccionado
                      ? AppColors.button
                      : Colors.white24,
                ),
              ),
              child: Text(
                _etiquetasFiltro[i],
                style: TextStyle(
                  color:
                      seleccionado ? Colors.white : Colors.white60,
                  fontSize: 13,
                  fontWeight: seleccionado
                      ? FontWeight.bold
                      : FontWeight.normal,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildCuerpo() {
    if (_cargando) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.button),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.cloud_off_outlined,
                  color: Colors.white54, size: 64),
              const SizedBox(height: 16),
              Text(_error!,
                  style: const TextStyle(color: Colors.white70),
                  textAlign: TextAlign.center),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.button,
                    foregroundColor: Colors.white),
                onPressed: _cargar,
                icon: const Icon(Icons.refresh),
                label: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      );
    }

    if (_reservas.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.event_busy_outlined,
                color: Colors.white24, size: 64),
            const SizedBox(height: 16),
            Text(
              _filtroEstado != null
                  ? 'No hay reservas con estado "$_filtroEstado" para este día.'
                  : 'No hay reservas para este día.',
              style: const TextStyle(color: Colors.white54, fontSize: 15),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: AppColors.button,
      backgroundColor: Colors.black87,
      onRefresh: _cargar,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        itemCount: _reservas.length,
        itemBuilder: (_, i) => _cardReserva(_reservas[i]),
      ),
    );
  }

  Widget _cardReserva(Map<String, dynamic> r) {
    final estado = r['estado'] as String? ?? 'Pendiente';
    final hora = r['hora'] as String? ?? '';
    final nombre = r['nombreCompleto'] as String? ?? '—';
    final comensales = r['comensales'] ?? 0;
    final numeroMesa = r['numeroMesa'];
    final notas = r['notas'] as String?;
    final id = r['id'] as String? ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Fila superior: hora + badge estado
                Row(
                  children: [
                    Text(
                      hora,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        nombre,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    _badgeEstado(estado),
                  ],
                ),
                const SizedBox(height: 8),

                // Comensales y mesa
                Row(
                  children: [
                    const Icon(Icons.people_outline,
                        color: Colors.white54, size: 16),
                    const SizedBox(width: 4),
                    Text(
                      '$comensales comensales',
                      style: const TextStyle(
                          color: Colors.white60, fontSize: 13),
                    ),
                    const SizedBox(width: 16),
                    const Icon(Icons.table_restaurant_outlined,
                        color: Colors.white54, size: 16),
                    const SizedBox(width: 4),
                    Text(
                      numeroMesa != null
                          ? 'Mesa $numeroMesa'
                          : 'Sin asignar',
                      style: TextStyle(
                        color: numeroMesa != null
                            ? Colors.white60
                            : AppColors.warningLight,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),

                if (notas != null && notas.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.notes,
                          color: Colors.white30, size: 14),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          notas,
                          style: const TextStyle(
                              color: Colors.white54, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ],

                const SizedBox(height: 12),
                const Divider(color: Colors.white12, height: 1),
                const SizedBox(height: 10),

                // Botones de acción según estado
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    ..._botonesSegunEstado(id, estado),
                    // Asignar mesa siempre disponible si no tiene
                    if (numeroMesa == null)
                      _botonAccion(
                        label: 'Asignar mesa',
                        icono: Icons.table_restaurant,
                        color: AppColors.warningText,
                        onTap: () => _abrirAsignarMesa(r),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _botonesSegunEstado(String id, String estado) {
    switch (estado) {
      case 'Pendiente':
        return [
          _botonAccion(
            label: 'Confirmar',
            icono: Icons.check,
            color: AppColors.success,
            onTap: () => _cambiarEstado(id, 'Confirmada'),
          ),
          _botonAccion(
            label: 'Rechazar',
            icono: Icons.close,
            color: AppColors.lineStrong,
            onTap: () => _cambiarEstado(id, 'Cancelada'),
          ),
        ];
      case 'Confirmada':
        return [
          _botonAccion(
            label: 'Llegado',
            icono: Icons.how_to_reg,
            color: AppColors.info,
            onTap: () => _cambiarEstado(id, 'Llegado'),
          ),
          _botonAccion(
            label: 'No Show',
            icono: Icons.person_off,
            color: AppColors.textTertiary,
            onTap: () => _cambiarEstado(id, 'NoShow'),
          ),
        ];
      default:
        return [];
    }
  }

  Widget _botonAccion({
    required String label,
    required IconData icono,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icono, color: color, size: 15),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _badgeEstado(String estado) {
    final Color color;
    switch (estado) {
      case 'Confirmada':
        color = AppColors.success;
        break;
      case 'Cancelada':
        color = AppColors.error;
        break;
      case 'Llegado':
        color = AppColors.info;
        break;
      case 'NoShow':
        color = AppColors.lineStrong;
        break;
      case 'Pendiente':
      default:
        color = AppColors.warning;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        estado == 'NoShow' ? 'No Show' : estado,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

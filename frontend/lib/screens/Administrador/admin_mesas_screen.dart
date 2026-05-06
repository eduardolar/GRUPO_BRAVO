import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:frontend/core/colors_style.dart';
import 'package:frontend/models/mesa_model.dart';
import 'package:frontend/providers/auth_provider.dart';
import 'package:frontend/screens/Administrador/qr_imprimible_screen.dart';
import 'package:frontend/services/http_client.dart';
import 'package:frontend/services/mesa_service.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

// ── Constantes de look glass ──────────────────────────────────────────────────
const _kSheetBg = Color(0xFF1A1A1A);

class AdminMesasScreen extends StatefulWidget {
  const AdminMesasScreen({super.key});

  @override
  State<AdminMesasScreen> createState() => _AdminMesasScreenState();
}

class _AdminMesasScreenState extends State<AdminMesasScreen> {
  List<Mesa> _mesas = [];
  bool _cargando = true;
  String? _restauranteId;

  // ── Filtros ───────────────────────────────────────────────────────────────
  final _busquedaCtrl = TextEditingController();
  String _busqueda = '';
  // 'todas' | 'libres' | 'ocupadas'
  String _filtroEstado = 'todas';
  // 'todas' | 'interior' | 'terraza'
  String _filtroZona = 'todas';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _restauranteId = context
          .read<AuthProvider>()
          .usuarioActual
          ?.restauranteId;
      _cargarMesas();
    });
  }

  @override
  void dispose() {
    _busquedaCtrl.dispose();
    super.dispose();
  }

  Future<void> _cargarMesas() async {
    try {
      // Aislamos por sucursal: el admin solo ve y opera sobre sus mesas.
      final mesas = await MesaService.obtenerMesas(
        restauranteId: _restauranteId,
      );
      if (!mounted) return;
      setState(() {
        _mesas = mesas;
        _cargando = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _cargando = false);
    }
  }

  /// Lista filtrada que se pasa al Wrap. Aplica búsqueda, estado y zona.
  List<Mesa> get _mesasFiltradas {
    var lista = List<Mesa>.from(_mesas);

    // Buscador: por número de mesa (texto) o código QR
    if (_busqueda.isNotEmpty) {
      final q = _busqueda.toLowerCase();
      lista = lista.where((m) {
        return m.numero.toString().contains(q) ||
            m.codigoQr.toLowerCase().contains(q);
      }).toList();
    }

    // Filtro por estado
    if (_filtroEstado == 'libres') {
      lista = lista.where((m) => m.disponible).toList();
    } else if (_filtroEstado == 'ocupadas') {
      lista = lista.where((m) => !m.disponible).toList();
    }

    // Filtro por zona
    if (_filtroZona != 'todas') {
      lista = lista.where((m) => m.ubicacion == _filtroZona).toList();
    }

    return lista;
  }

  /// Genera un código QR opaco para una mesa nueva. Mezcla la sucursal,
  /// el número y un sufijo aleatorio corto para que sea único globalmente
  /// y no choque con otra mesa de otra sucursal con el mismo número.
  String _autoQr(int numero, String ubicacion) {
    final prefijo = ubicacion == 'terraza' ? 'T' : 'M';
    final restPrefix = (_restauranteId ?? 'X').substring(
      0,
      _restauranteId != null && _restauranteId!.length >= 6 ? 6 : 1,
    );
    final sufijo = (Random().nextInt(0xFFFF))
        .toRadixString(16)
        .padLeft(4, '0')
        .toUpperCase();
    return '$prefijo${numero.toString().padLeft(2, '0')}-$restPrefix-$sufijo';
  }

  /// Abre la pantalla imprimible (fondo blanco + QR grande + datos).
  void _abrirImprimible(Mesa mesa) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => QrImprimibleScreen(mesa: mesa)),
    );
  }

  /// Abre el sheet de creación de mesa. Devuelve la Mesa creada o null.
  Future<void> _mostrarFormCrearMesa() async {
    final messenger = ScaffoldMessenger.of(context);
    final mesa = await showModalBottomSheet<Mesa>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.7),
      builder: (_) => const _SheetCrearMesa(),
    );

    if (mesa == null || !mounted) return;

    try {
      // Si el usuario dejó el QR vacío, lo generamos opaco para que sea
      // único entre sucursales (M01-69de62-A3F4 etc.).
      final qrFinal = mesa.codigoQr.trim().isEmpty
          ? _autoQr(mesa.numero, mesa.ubicacion)
          : mesa.codigoQr.trim();
      final nueva = await MesaService.crearMesa(
        numero: mesa.numero,
        capacidad: mesa.capacidad,
        ubicacion: mesa.ubicacion,
        codigoQr: qrFinal,
        restauranteId: _restauranteId,
      );
      if (!mounted) return;
      setState(() => _mesas.add(nueva));
      messenger.showSnackBar(
        SnackBar(
          content: Text('Mesa ${nueva.numero} creada correctamente'),
          backgroundColor: AppColors.button,
          behavior: SnackBarBehavior.floating,
          action: SnackBarAction(
            label: 'IMPRIMIR QR',
            textColor: Colors.white,
            onPressed: () => _abrirImprimible(nueva),
          ),
        ),
      );
      // UX: tras crear, abrimos directamente la vista imprimible.
      _abrirImprimible(nueva);
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  /// Abre el bottom sheet de gestión. Devuelve la acción elegida o null.
  Future<void> _gestionarMesa(Mesa mesa) async {
    final messenger = ScaffoldMessenger.of(context);

    // El sheet no devuelve valor directamente; manejamos la acción
    // dentro del propio sheet y recargamos aquí según el resultado.
    final accion = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.7),
      builder: (_) => _SheetGestionAdmin(mesa: mesa),
    );

    if (accion == null || !mounted) return;

    if (accion == 'imprimir') {
      _abrirImprimible(mesa);
      return;
    }

    if (accion == 'editar') {
      final mesaActualizada = await showModalBottomSheet<Mesa>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        barrierColor: Colors.black.withValues(alpha: 0.7),
        builder: (_) => _SheetEditarMesa(mesa: mesa),
      );

      if (mesaActualizada == null || !mounted) return;

      // Reemplazamos la mesa en la lista local por la devuelta del servicio.
      setState(() {
        final index = _mesas.indexWhere((m) => m.id == mesaActualizada.id);
        if (index != -1) _mesas[index] = mesaActualizada;
      });
      messenger.showSnackBar(
        SnackBar(
          content: Text('Mesa ${mesaActualizada.numero} actualizada'),
          backgroundColor: AppColors.button,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (accion == 'eliminar') {
      try {
        await MesaService.eliminarMesa(mesa.id);
        if (!mounted) return;
        setState(() => _mesas.removeWhere((m) => m.id == mesa.id));
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Mesa eliminada correctamente'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      } catch (e) {
        if (!mounted) return;
        messenger.showSnackBar(
          SnackBar(
            content: Text('Error al eliminar la mesa: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } else if (accion == 'liberar') {
      try {
        await MesaService.marcarMesaLibre(mesa.id);
        if (!mounted) return;
        setState(() {
          final index = _mesas.indexWhere((m) => m.id == mesa.id);
          if (index != -1) {
            _mesas[index] = _mesas[index].copyWith(disponible: true);
          }
        });
      } catch (e) {
        if (!mounted) return;
        messenger.showSnackBar(
          SnackBar(
            content: Text('Error al liberar la mesa: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } else if (accion == 'ocupar') {
      try {
        await MesaService.marcarMesaOcupada(mesa.id);
        if (!mounted) return;
        setState(() {
          final index = _mesas.indexWhere((m) => m.id == mesa.id);
          if (index != -1) {
            _mesas[index] = _mesas[index].copyWith(disponible: false);
          }
        });
      } catch (e) {
        if (!mounted) return;
        messenger.showSnackBar(
          SnackBar(
            content: Text('Error al ocupar la mesa: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Map<String, List<Mesa>> _agruparPorUbicacion(List<Mesa> mesas) {
    final Map<String, List<Mesa>> grupos = {};
    for (final mesa in mesas) {
      grupos.putIfAbsent(mesa.ubicacion, () => []).add(mesa);
    }
    return grupos;
  }

  // ── KPI stats ─────────────────────────────────────────────────────────────

  Widget _buildStatsRow() {
    final total = _mesas.length;
    final libres = _mesas.where((m) => m.disponible).length;
    final ocupadas = total - libres;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      child: Row(
        children: [
          _StatChip(
            label: '$total',
            sublabel: 'TOTAL',
            color: Colors.white70,
          ),
          const SizedBox(width: 8),
          _StatChip(
            label: '$libres',
            sublabel: 'LIBRES',
            color: AppColors.disp,
          ),
          const SizedBox(width: 8),
          _StatChip(
            label: '$ocupadas',
            sublabel: 'OCUPADAS',
            color: AppColors.error,
          ),
        ],
      ),
    );
  }

  // ── Buscador ──────────────────────────────────────────────────────────────

  Widget _buildBuscador() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Container(
            height: 42,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
            ),
            child: TextField(
              controller: _busquedaCtrl,
              cursorColor: AppColors.button,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              onChanged: (v) => setState(() => _busqueda = v.toLowerCase()),
              decoration: InputDecoration(
                hintText: 'Buscar por número o código QR...',
                hintStyle:
                    const TextStyle(color: Colors.white70, fontSize: 13),
                prefixIcon: const Icon(
                  Icons.search,
                  color: Colors.white60,
                  size: 18,
                ),
                suffixIcon: _busqueda.isNotEmpty
                    ? IconButton(
                        icon: const Icon(
                          Icons.clear,
                          color: Colors.white60,
                          size: 16,
                        ),
                        onPressed: () {
                          _busquedaCtrl.clear();
                          setState(() => _busqueda = '');
                        },
                      )
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 11),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Chips de filtro (estado y zona) ───────────────────────────────────────

  Widget _buildFiltros() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      child: Row(
        children: [
          // Filtro por estado
          _FiltroChip(
            label: 'Todas',
            activo: _filtroEstado == 'todas',
            onTap: () => setState(() => _filtroEstado = 'todas'),
          ),
          const SizedBox(width: 6),
          _FiltroChip(
            label: 'Libres',
            activo: _filtroEstado == 'libres',
            onTap: () => setState(() => _filtroEstado = 'libres'),
          ),
          const SizedBox(width: 6),
          _FiltroChip(
            label: 'Ocupadas',
            activo: _filtroEstado == 'ocupadas',
            onTap: () => setState(() => _filtroEstado = 'ocupadas'),
          ),
          const SizedBox(width: 14),
          // Separador vertical
          Container(width: 1, height: 18, color: Colors.white24),
          const SizedBox(width: 14),
          // Filtro por zona
          _FiltroChip(
            label: 'Interior',
            activo: _filtroZona == 'interior',
            onTap: () => setState(
              () => _filtroZona =
                  _filtroZona == 'interior' ? 'todas' : 'interior',
            ),
          ),
          const SizedBox(width: 6),
          _FiltroChip(
            label: 'Terraza',
            activo: _filtroZona == 'terraza',
            onTap: () => setState(
              () => _filtroZona =
                  _filtroZona == 'terraza' ? 'todas' : 'terraza',
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_cargando) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            Positioned.fill(
              child: Image.asset(
                'assets/images/Bravo restaurante.jpg',
                fit: BoxFit.cover,
              ),
            ),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.65),
                ),
              ),
            ),
            const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 1.5,
                    ),
                  ),
                  SizedBox(height: 18),
                  Text(
                    'CARGANDO MESAS',
                    style: TextStyle(
                      color: Colors.white60,
                      fontSize: 10,
                      letterSpacing: 3.0,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    final mesasFiltradas = _mesasFiltradas;
    final grupos = _agruparPorUbicacion(mesasFiltradas);
    final orderedKeys = ['interior', 'terraza']
        .where((k) => grupos.containsKey(k))
        .toList();

    return Scaffold(
      backgroundColor: Colors.black,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _mostrarFormCrearMesa,
        backgroundColor: AppColors.button,
        foregroundColor: Colors.white,
        elevation: 4,
        icon: const Icon(Icons.add, size: 20),
        label: const Text(
          'NUEVA MESA',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.4,
          ),
        ),
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/images/Bravo restaurante.jpg',
              fit: BoxFit.cover,
            ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.50),
                    Colors.black.withValues(alpha: 0.75),
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Header ──────────────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: const Icon(
                          Icons.arrow_back_ios_new,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'ADMINISTRAR MESAS',
                              style: GoogleFonts.playfairDisplay(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.5,
                                shadows: const [
                                  Shadow(
                                    color: Colors.black54,
                                    blurRadius: 8,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Pulsa una mesa para gestionarla',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 11,
                                letterSpacing: 0.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // ── KPI row ─────────────────────────────────────────────────
                _buildStatsRow(),

                // ── Buscador ────────────────────────────────────────────────
                _buildBuscador(),

                // ── Filtros ─────────────────────────────────────────────────
                _buildFiltros(),

                const SizedBox(height: 12),

                // ── Leyenda ─────────────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      _LegendaDot(
                        color: AppColors.button,
                        label: 'Disponible',
                      ),
                      const SizedBox(width: 20),
                      _LegendaDot(
                        color: AppColors.iconPrimary,
                        label: 'Ocupada',
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 14),

                // ── Lista de mesas ───────────────────────────────────────────
                Expanded(
                  child: mesasFiltradas.isEmpty
                      ? _buildVacio()
                      : ListView(
                          physics: const BouncingScrollPhysics(),
                          // padding-bottom 96 para que el FAB no tape la última fila
                          padding:
                              const EdgeInsets.fromLTRB(20, 0, 20, 96),
                          children: orderedKeys.map((ubicacion) {
                            final mesasGrupo = grupos[ubicacion]!;
                            final titulo = ubicacion[0].toUpperCase() +
                                ubicacion.substring(1);

                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 16),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 3,
                                        height: 16,
                                        decoration: BoxDecoration(
                                          color: AppColors.button,
                                          borderRadius:
                                              BorderRadius.circular(2),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        titulo.toUpperCase(),
                                        style: const TextStyle(
                                          color: Colors.white70,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          letterSpacing: 2.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Wrap(
                                  spacing: 20,
                                  runSpacing: 24,
                                  children: mesasGrupo
                                      .map(
                                        (mesa) => _MesaCard(
                                          mesa: mesa,
                                          onTap: () => _gestionarMesa(mesa),
                                        ),
                                      )
                                      .toList(),
                                ),
                                const SizedBox(height: 20),
                                const Divider(
                                  color: Colors.white24,
                                  thickness: 0.5,
                                ),
                                const SizedBox(height: 12),
                              ],
                            );
                          }).toList(),
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVacio() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.table_restaurant_outlined,
            size: 52,
            color: Colors.white24,
          ),
          const SizedBox(height: 12),
          Text(
            _busqueda.isNotEmpty
                ? 'Sin resultados para "$_busqueda"'
                : 'No hay mesas con los filtros actuales',
            style: const TextStyle(color: Colors.white60),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ── Sheet de Gestión de mesa ──────────────────────────────────────────────────

class _SheetGestionAdmin extends StatelessWidget {
  final Mesa mesa;

  const _SheetGestionAdmin({required this.mesa});

  String get _ubicacionLabel {
    return mesa.ubicacion == 'interior'
        ? 'Interior'
        : (mesa.ubicacion == 'terraza' ? 'Terraza' : mesa.ubicacion);
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.58,
      minChildSize: 0.35,
      maxChildSize: 0.80,
      expand: false,
      builder: (_, scroll) {
        return Container(
          decoration: const BoxDecoration(
            color: _kSheetBg,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: ListView(
            controller: scroll,
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
            children: [
              // ── Drag handle ──────────────────────────────────────────────
              Center(
                child: Padding(
                  padding: const EdgeInsets.only(top: 12, bottom: 8),
                  child: Container(
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ),

              // ── Header con icono granate + título + close ─────────────────
              Row(
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
                    child: const Icon(
                      Icons.table_restaurant_outlined,
                      color: AppColors.button,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'GESTIONAR MESA ${mesa.numero}',
                          style: GoogleFonts.playfairDisplay(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            letterSpacing: 1.2,
                          ),
                        ),
                        // Subtítulo: zona + capacidad
                        Text(
                          '$_ubicacionLabel · ${mesa.capacidad} personas',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                            letterSpacing: 0.3,
                          ),
                        ),
                        // Código QR como referencia visual
                        Text(
                          mesa.codigoQr,
                          style: const TextStyle(
                            color: Colors.white38,
                            fontSize: 10,
                            letterSpacing: 0.5,
                            fontFamily: 'monospace',
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white60),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),

              const SizedBox(height: 16),
              Divider(height: 1, color: Colors.white.withValues(alpha: 0.12)),
              const SizedBox(height: 20),

              // ── Mini preview de la mesa ──────────────────────────────────
              Center(
                child: SizedBox(
                  width: 84,
                  height: 84,
                  child: CustomPaint(
                    painter: _MesaPainter(
                      numero: mesa.numero,
                      capacidad: mesa.capacidad,
                      disponible: mesa.disponible,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // ── Botón dinámico según estado ──────────────────────────────
              if (!mesa.disponible)
                ElevatedButton.icon(
                  icon: const Icon(Icons.cleaning_services, size: 16),
                  label: const Text(
                    'MARCAR COMO LIBRE',
                    style: TextStyle(letterSpacing: 1.2, fontSize: 11),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.button,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 48),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: () => Navigator.pop(context, 'liberar'),
                ),

              if (mesa.disponible)
                ElevatedButton.icon(
                  icon: const Icon(Icons.people_alt_outlined, size: 16),
                  label: const Text(
                    'MARCAR COMO OCUPADA',
                    style: TextStyle(letterSpacing: 1.2, fontSize: 11),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.error,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 48),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: () => Navigator.pop(context, 'ocupar'),
                ),

              const SizedBox(height: 12),

              // ── Editar datos de la mesa ──────────────────────────────────
              OutlinedButton.icon(
                icon: const Icon(Icons.edit, size: 16),
                label: const Text(
                  'EDITAR DATOS',
                  style: TextStyle(letterSpacing: 1.2, fontSize: 11),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white70,
                  side: const BorderSide(color: Colors.white38),
                  minimumSize: const Size(double.infinity, 48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: () => Navigator.pop(context, 'editar'),
              ),

              const SizedBox(height: 12),

              // ── Ver / imprimir QR ────────────────────────────────────────
              OutlinedButton.icon(
                icon: const Icon(Icons.qr_code_2_rounded, size: 16),
                label: const Text(
                  'VER / IMPRIMIR QR',
                  style: TextStyle(letterSpacing: 1.2, fontSize: 11),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white24),
                  minimumSize: const Size(double.infinity, 48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: () => Navigator.pop(context, 'imprimir'),
              ),

              const SizedBox(height: 12),

              // ── Eliminar ─────────────────────────────────────────────────
              OutlinedButton.icon(
                icon: const Icon(Icons.delete_outline, size: 16),
                label: const Text(
                  'ELIMINAR MESA',
                  style: TextStyle(letterSpacing: 1.2, fontSize: 11),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.error,
                  side: const BorderSide(color: AppColors.error),
                  minimumSize: const Size(double.infinity, 48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: () => Navigator.pop(context, 'eliminar'),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ── Sheet de creación de mesa ─────────────────────────────────────────────────

class _SheetCrearMesa extends StatefulWidget {
  const _SheetCrearMesa();

  @override
  State<_SheetCrearMesa> createState() => _SheetCrearMesaState();
}

class _SheetCrearMesaState extends State<_SheetCrearMesa> {
  final _formKey = GlobalKey<FormState>();
  final _numeroCtrl = TextEditingController();
  final _capacidadCtrl = TextEditingController();
  final _qrCtrl = TextEditingController();
  final FocusNode _numeroFocus = FocusNode();
  String _ubicacion = 'interior';

  @override
  void dispose() {
    _numeroCtrl.dispose();
    _capacidadCtrl.dispose();
    _qrCtrl.dispose();
    _numeroFocus.dispose();
    super.dispose();
  }

  void _actualizarQrSugerido() {
    final n = _numeroCtrl.text.trim();
    if (n.isEmpty) {
      _qrCtrl.text = '';
      return;
    }
    final prefijo = _ubicacion == 'interior' ? 'Mesa' : 'Terraza';
    _qrCtrl.text = '${prefijo}_${n.padLeft(2, '0')}';
  }

  void _confirmar() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.pop(
      context,
      Mesa(
        id: '',
        numero: int.parse(_numeroCtrl.text.trim()),
        capacidad: int.parse(_capacidadCtrl.text.trim()),
        ubicacion: _ubicacion,
        codigoQr: _qrCtrl.text.trim(),
        disponible: true,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final viewInsets = MediaQuery.of(context).viewInsets;

    return DraggableScrollableSheet(
      initialChildSize: 0.82,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, scroll) {
        return Container(
          decoration: const BoxDecoration(
            color: _kSheetBg,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Padding(
            padding: EdgeInsets.only(bottom: viewInsets.bottom),
            child: Column(
              children: [
                // ── Drag handle ──────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.only(top: 12, bottom: 8),
                  child: Container(
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),

                // ── Header ───────────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 8, 12),
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
                        child: const Icon(
                          Icons.add_circle_outline,
                          color: AppColors.button,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'NUEVA MESA',
                              style: GoogleFonts.playfairDisplay(
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                                letterSpacing: 1.2,
                              ),
                            ),
                            const Text(
                              'Rellena los datos para añadir la mesa',
                              style: TextStyle(
                                color: Colors.white60,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white60),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),

                Divider(
                  height: 1,
                  color: Colors.white.withValues(alpha: 0.12),
                ),

                // ── Formulario scrolleable ────────────────────────────────
                Expanded(
                  child: Form(
                    key: _formKey,
                    child: ListView(
                      controller: scroll,
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                      children: [
                        _Campo(
                          controller: _numeroCtrl,
                          focusNode: _numeroFocus,
                          label: 'Número de mesa',
                          hint: 'Ej: 13',
                          keyboardType: TextInputType.number,
                          onChanged: (_) =>
                              WidgetsBinding.instance.addPostFrameCallback(
                            (_) => _actualizarQrSugerido(),
                          ),
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) {
                              return 'Campo obligatorio';
                            }
                            if (int.tryParse(v.trim()) == null) {
                              return 'Solo números';
                            }
                            if (int.parse(v.trim()) <= 0) {
                              return 'Debe ser mayor que 0';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),
                        _Campo(
                          controller: _capacidadCtrl,
                          label: 'Capacidad (personas)',
                          hint: 'Ej: 4',
                          keyboardType: TextInputType.number,
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) {
                              return 'Campo obligatorio';
                            }
                            if (int.tryParse(v.trim()) == null) {
                              return 'Solo números';
                            }
                            if (int.parse(v.trim()) <= 0) {
                              return 'Debe ser mayor que 0';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),
                        const Text(
                          'ZONA',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1.5,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            _ChipUbicacion(
                              label: 'Interior',
                              selected: _ubicacion == 'interior',
                              onTap: () => setState(() {
                                _ubicacion = 'interior';
                                _actualizarQrSugerido();
                              }),
                            ),
                            const SizedBox(width: 8),
                            _ChipUbicacion(
                              label: 'Terraza',
                              selected: _ubicacion == 'terraza',
                              onTap: () => setState(() {
                                _ubicacion = 'terraza';
                                _actualizarQrSugerido();
                              }),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        _Campo(
                          controller: _qrCtrl,
                          label: 'Código QR (opcional)',
                          hint: 'Se generará uno único si lo dejas en blanco',
                          // Si llega vacío el padre genera un código opaco
                          // con sucursal + sufijo aleatorio para garantizar
                          // unicidad entre sucursales.
                        ),
                        const SizedBox(height: 28),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () => Navigator.pop(context),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.white70,
                                  side: const BorderSide(
                                    color: Colors.white24,
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                child: const Text(
                                  'CANCELAR',
                                  style: TextStyle(
                                    fontSize: 11,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: _confirmar,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.button,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                child: const Text(
                                  'CREAR',
                                  style: TextStyle(
                                    fontSize: 11,
                                    letterSpacing: 1.2,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
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
}

// ── Sheet de edición de mesa ──────────────────────────────────────────────────

class _SheetEditarMesa extends StatefulWidget {
  final Mesa mesa;

  const _SheetEditarMesa({required this.mesa});

  @override
  State<_SheetEditarMesa> createState() => _SheetEditarMesaState();
}

class _SheetEditarMesaState extends State<_SheetEditarMesa> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _numeroCtrl;
  late final TextEditingController _capacidadCtrl;
  late final TextEditingController _qrCtrl;
  late String _ubicacion;
  bool _guardando = false;

  @override
  void initState() {
    super.initState();
    // Pre-rellenamos con los valores actuales de la mesa.
    _numeroCtrl = TextEditingController(
      text: widget.mesa.numero.toString(),
    );
    _capacidadCtrl = TextEditingController(
      text: widget.mesa.capacidad.toString(),
    );
    _qrCtrl = TextEditingController(text: widget.mesa.codigoQr);
    _ubicacion = widget.mesa.ubicacion;
  }

  @override
  void dispose() {
    _numeroCtrl.dispose();
    _capacidadCtrl.dispose();
    _qrCtrl.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _guardando = true);

    try {
      final mesaActualizada = await MesaService.editarMesa(
        widget.mesa.id,
        numero: int.parse(_numeroCtrl.text.trim()),
        capacidad: int.parse(_capacidadCtrl.text.trim()),
        ubicacion: _ubicacion,
        codigoQr: _qrCtrl.text.trim().isEmpty
            ? null
            : _qrCtrl.text.trim(),
      );
      if (!mounted) return;
      Navigator.pop(context, mesaActualizada);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _guardando = false);
      // 409 → duplicado de número o QR; mostramos el mensaje del backend.
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _guardando = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final viewInsets = MediaQuery.of(context).viewInsets;

    return DraggableScrollableSheet(
      initialChildSize: 0.82,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, scroll) {
        return Container(
          decoration: const BoxDecoration(
            color: _kSheetBg,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Padding(
            padding: EdgeInsets.only(bottom: viewInsets.bottom),
            child: Column(
              children: [
                // ── Drag handle ──────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.only(top: 12, bottom: 8),
                  child: Container(
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),

                // ── Header ───────────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 8, 12),
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
                        child: const Icon(
                          Icons.edit_outlined,
                          color: AppColors.button,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'EDITAR MESA',
                              style: GoogleFonts.playfairDisplay(
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                                letterSpacing: 1.2,
                              ),
                            ),
                            const Text(
                              'Modifica los datos y guarda los cambios',
                              style: TextStyle(
                                color: Colors.white60,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white60),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),

                Divider(
                  height: 1,
                  color: Colors.white.withValues(alpha: 0.12),
                ),

                // ── Formulario scrolleable ────────────────────────────────
                Expanded(
                  child: Form(
                    key: _formKey,
                    child: ListView(
                      controller: scroll,
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                      children: [
                        _Campo(
                          controller: _numeroCtrl,
                          label: 'Número de mesa',
                          hint: 'Ej: 13',
                          keyboardType: TextInputType.number,
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) {
                              return 'Campo obligatorio';
                            }
                            if (int.tryParse(v.trim()) == null) {
                              return 'Solo números';
                            }
                            if (int.parse(v.trim()) <= 0) {
                              return 'Debe ser mayor que 0';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),
                        _Campo(
                          controller: _capacidadCtrl,
                          label: 'Capacidad (personas)',
                          hint: 'Ej: 4',
                          keyboardType: TextInputType.number,
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) {
                              return 'Campo obligatorio';
                            }
                            if (int.tryParse(v.trim()) == null) {
                              return 'Solo números';
                            }
                            if (int.parse(v.trim()) <= 0) {
                              return 'Debe ser mayor que 0';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),
                        const Text(
                          'ZONA',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1.5,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            _ChipUbicacion(
                              label: 'Interior',
                              selected: _ubicacion == 'interior',
                              onTap: () =>
                                  setState(() => _ubicacion = 'interior'),
                            ),
                            const SizedBox(width: 8),
                            _ChipUbicacion(
                              label: 'Terraza',
                              selected: _ubicacion == 'terraza',
                              onTap: () =>
                                  setState(() => _ubicacion = 'terraza'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        _Campo(
                          controller: _qrCtrl,
                          label: 'Código QR',
                          hint: 'Déjalo vacío para no modificarlo',
                          // Si el usuario borra el QR y guarda vacío,
                          // enviamos null y el backend conserva el valor actual.
                        ),
                        const SizedBox(height: 28),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: _guardando
                                    ? null
                                    : () => Navigator.pop(context),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.white70,
                                  side: const BorderSide(
                                    color: Colors.white24,
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                child: const Text(
                                  'CANCELAR',
                                  style: TextStyle(
                                    fontSize: 11,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: _guardando ? null : _guardar,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.button,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                child: _guardando
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          color: Colors.white,
                                          strokeWidth: 1.5,
                                        ),
                                      )
                                    : const Text(
                                        'GUARDAR CAMBIOS',
                                        style: TextStyle(
                                          fontSize: 11,
                                          letterSpacing: 1.2,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                              ),
                            ),
                          ],
                        ),
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
}

// ── Painter de mesa ───────────────────────────────────────────────────────────

class _MesaPainter extends CustomPainter {
  final int numero;
  final int capacidad;
  final bool disponible;

  const _MesaPainter({
    required this.numero,
    required this.capacidad,
    required this.disponible,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final tableRadius = size.width * 0.28;
    final chairW = size.width * 0.11;
    final chairH = size.width * 0.075;
    final chairDist = tableRadius + chairH + 3.0;

    final tableColor = disponible ? AppColors.button : AppColors.iconPrimary;
    final chairColor = disponible ? AppColors.button : AppColors.iconPrimary;
    final borderColor = disponible ? AppColors.button : AppColors.iconPrimary;

    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.35)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    canvas.drawCircle(center + const Offset(2, 3), tableRadius, shadowPaint);

    final angles = List.generate(
      capacidad,
      (i) => (2 * pi * i) / capacidad - pi / 2,
    );
    final chairPaint = Paint()
      ..color = chairColor
      ..style = PaintingStyle.fill;
    final chairBorderPaint = Paint()
      ..color = borderColor.withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;

    for (final angle in angles) {
      final cx = center.dx + chairDist * cos(angle);
      final cy = center.dy + chairDist * sin(angle);
      final rect = RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(cx, cy),
          width: chairW * 2,
          height: chairH * 2,
        ),
        const Radius.circular(4),
      );
      canvas.drawRRect(rect, chairPaint);
      canvas.drawRRect(rect, chairBorderPaint);
    }

    final tablePaint = Paint()
      ..color = tableColor
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, tableRadius, tablePaint);

    final tableBorderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawCircle(center, tableRadius, tableBorderPaint);

    final textSpan = TextSpan(
      text: '$numero',
      style: TextStyle(
        color: Colors.white.withValues(alpha: disponible ? 1.0 : 0.6),
        fontSize: tableRadius * 0.82,
        fontWeight: FontWeight.bold,
      ),
    );
    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(
        center.dx - textPainter.width / 2,
        center.dy - textPainter.height / 2,
      ),
    );
  }

  @override
  bool shouldRepaint(_MesaPainter old) =>
      old.disponible != disponible ||
      old.numero != numero ||
      old.capacidad != capacidad;
}

// ── Tarjeta de mesa ───────────────────────────────────────────────────────────

class _MesaCard extends StatelessWidget {
  final Mesa mesa;
  final VoidCallback? onTap;

  const _MesaCard({required this.mesa, this.onTap});

  @override
  Widget build(BuildContext context) {
    final disponible = mesa.disponible;
    return GestureDetector(
      onTap: onTap,
      child: Opacity(
        opacity: disponible ? 1.0 : 0.45,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 90,
              height: 90,
              child: CustomPaint(
                painter: _MesaPainter(
                  numero: mesa.numero,
                  capacidad: mesa.capacidad,
                  disponible: disponible,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              disponible ? 'LIBRE' : 'OCUPADA',
              style: TextStyle(
                color: disponible ? Colors.white : AppColors.iconPrimary,
                fontSize: 9,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Leyenda ───────────────────────────────────────────────────────────────────

class _LegendaDot extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendaDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 11,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }
}

// ── Mini stat chip (KPI row) ──────────────────────────────────────────────────

class _StatChip extends StatelessWidget {
  final String label;
  final String sublabel;
  final Color color;

  const _StatChip({
    required this.label,
    required this.sublabel,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
          ),
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: '$label ',
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                ),
                TextSpan(
                  text: sublabel,
                  style: const TextStyle(
                    color: Colors.white38,
                    fontSize: 10,
                    letterSpacing: 0.5,
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

// ── Chip de filtro (estado / zona) ────────────────────────────────────────────

class _FiltroChip extends StatelessWidget {
  final String label;
  final bool activo;
  final VoidCallback onTap;

  const _FiltroChip({
    required this.label,
    required this.activo,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: activo ? AppColors.button : Colors.black.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: activo ? AppColors.button : Colors.white24,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: activo ? Colors.white : Colors.white60,
            fontSize: 11,
            fontWeight: activo ? FontWeight.w700 : FontWeight.w400,
            letterSpacing: 0.3,
          ),
        ),
      ),
    );
  }
}

// ── Campo de texto ────────────────────────────────────────────────────────────

class _Campo extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode? focusNode;
  final String label;
  final String hint;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  final void Function(String)? onChanged;

  const _Campo({
    required this.controller,
    this.focusNode,
    required this.label,
    required this.hint,
    this.keyboardType,
    this.validator,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 10,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          focusNode: focusNode,
          keyboardType: keyboardType,
          validator: validator,
          onChanged: onChanged,
          style: const TextStyle(color: Colors.white, fontSize: 14),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Colors.white38, fontSize: 13),
            filled: true,
            fillColor: Colors.black45,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 12,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Colors.white24),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Colors.white24),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(
                color: AppColors.button,
                width: 1.5,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppColors.error),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppColors.error),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Chip de ubicación (interior / terraza) ────────────────────────────────────

class _ChipUbicacion extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ChipUbicacion({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? AppColors.button : Colors.black45,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: selected ? AppColors.button : Colors.white24,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : Colors.white70,
            fontSize: 11,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}

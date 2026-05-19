import 'dart:ui';

import 'package:flutter/material.dart';

import '../../components/bravo_app_bar.dart';
import '../../models/cupon_model.dart';
import '../../models/restaurante_model.dart';
import '../../services/cupon_service.dart';
import '../../core/colors_style.dart';
import '../../services/restaurante_service.dart';

// ─── Colores ─────────────────────────────────────────────────────────────────
const _kCard = AppColors.surfaceDark;
const _kText = AppColors.textOnDark;
const _kSub = AppColors.textMidGrey;
const _kGreen = AppColors.successVibrant;
const _kRed = AppColors.error;
const _kBlue = AppColors.info;
const _kGranate = AppColors.primary; // granate para cupones globales
// Azul plateado: un único color para todos los iconos de acción (en vez de
// multicolor) — suave y legible sobre la tarjeta oscura.
const _kIcono = AppColors.detailOnDark;
const _kAccent = AppColors
    .primaryAccent; // fills sólidos con texto blanco (legible sobre oscuro)

class CuponesScreen extends StatefulWidget {
  const CuponesScreen({super.key});

  @override
  State<CuponesScreen> createState() => _CuponesScreenState();
}

class _CuponesScreenState extends State<CuponesScreen>
    with SingleTickerProviderStateMixin {
  List<Cupon> _cupones = [];
  List<Restaurante> _restaurantes = [];
  bool _cargando = true;
  String? _error;
  String _filtro = 'todos';
  String _busqueda = '';
  final String _orden = 'recientes';
  late TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
    _tabCtrl.addListener(() {
      if (!_tabCtrl.indexIsChanging) {
        setState(() {
          _filtro = ['todos', 'activos', 'inactivos'][_tabCtrl.index];
        });
      }
    });
    _cargar();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _cargar() async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final resultados = await Future.wait([
        CuponService.listar(),
        RestauranteService().obtenerTodos(),
      ]);
      if (!mounted) return;
      setState(() {
        _cupones = resultados[0] as List<Cupon>;
        _restaurantes = resultados[1] as List<Restaurante>;
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

  // ── Crear cupón con toggle global/sucursal ────────────────────────────────

  void _mostrarFormCrear() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _FormCrearCupon(
        restaurantes: _restaurantes,
        onCrear:
            (
              codigo,
              tipo,
              valor,
              descripcion,
              usosMaximos,
              fechaInicio,
              fechaFin,
              restauranteId,
            ) async {
              // restauranteId == _globalSentinel → cupón global (null)
              // restauranteId == String → cupón de sucursal
              final esGlobal = restauranteId == null;

              if (esGlobal) {
                // Doble confirmación antes de crear cupón global
                final confirmado = await _confirmarCuponGlobal();
                if (!confirmado || !mounted) return;
              }

              try {
                await CuponService.crear(
                  codigo: codigo,
                  tipo: tipo,
                  valor: valor,
                  descripcion: descripcion,
                  usosMaximos: usosMaximos,
                  fechaInicio: fechaInicio,
                  fechaFin: fechaFin,
                  restauranteId: esGlobal ? null : restauranteId,
                );
                if (mounted) {
                  Navigator.pop(context);
                  _mostrarSnackBar(
                    esGlobal
                        ? 'Cupon global creado en todas las sucursales'
                        : 'Cupon creado',
                    esError: false,
                  );
                  _cargar();
                }
              } catch (e) {
                if (mounted) _mostrarSnackBar('Error al crear el cupón: $e');
              }
            },
      ),
    );
  }

  /// Muestra el dialog de doble confirmación para cupón global.
  /// Devuelve true si el usuario confirmó.
  Future<bool> _confirmarCuponGlobal() async {
    final total = _restaurantes.length;
    final resultado = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _kCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(
              Icons.warning_amber_rounded,
              color: AppColors.warning,
              size: 22,
            ),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Confirmar cupón global',
                style: TextStyle(
                  color: _kText,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ],
        ),
        content: RichText(
          text: TextSpan(
            style: const TextStyle(color: _kText, fontSize: 13),
            children: [
              const TextSpan(text: 'Vas a crear un cupón aplicable en '),
              TextSpan(
                text: 'TODAS las sucursales ($total sucursales activas)',
                style: const TextStyle(
                  color: _kRed,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const TextSpan(text: '. ¿Confirmas?'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar', style: TextStyle(color: _kSub)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _kGranate,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'SI, CREAR GLOBAL',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
    return resultado == true;
  }

  // ── Envío masivo ──────────────────────────────────────────────────────────

  void _mostrarOpcionesEnvio(Cupon c) {
    String destino = 'todos';
    String? restauranteId;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: _kCard,
          title: Text(
            'Enviar ${c.codigo}',
            style: const TextStyle(color: _kText),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                '¿A quién deseas enviar el cupón?',
                style: TextStyle(color: _kText),
              ),
              const SizedBox(height: 20),
              DropdownButton<String>(
                dropdownColor: _kCard,
                value: destino,
                isExpanded: true,
                style: const TextStyle(color: _kText),
                items: const [
                  DropdownMenuItem(
                    value: 'todos',
                    child: Text('Todos los clientes'),
                  ),
                  DropdownMenuItem(
                    value: 'restaurante',
                    child: Text('Clientes de un restaurante específico'),
                  ),
                ],
                onChanged: (val) => setDialogState(() => destino = val!),
              ),
              if (destino == 'restaurante') ...[
                const SizedBox(height: 15),
                DropdownButton<String>(
                  dropdownColor: _kCard,
                  hint: const Text(
                    'Selecciona un restaurante',
                    style: TextStyle(color: _kSub),
                  ),
                  value: restauranteId,
                  isExpanded: true,
                  style: const TextStyle(color: _kText),
                  items: _restaurantes.map((r) {
                    return DropdownMenuItem<String>(
                      value: r.id,
                      child: Text(r.nombre, overflow: TextOverflow.ellipsis),
                    );
                  }).toList(),
                  onChanged: (val) => setDialogState(() => restauranteId = val),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar', style: TextStyle(color: _kSub)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: _kGreen),
              onPressed: (destino == 'restaurante' && restauranteId == null)
                  ? null
                  : () {
                      Navigator.pop(context);
                      _ejecutarEnvioMasivo(c, destino, restauranteId);
                    },
              child: const Text('Enviar emails'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _ejecutarEnvioMasivo(Cupon c, String tipo, String? resId) async {
    setState(() => _cargando = true);
    try {
      await CuponService.enviarNotificacionMasiva(
        cuponId: c.id,
        tipoFiltro: tipo,
        restauranteId: resId,
      );
      _mostrarSnackBar('Emails en cola de envío correctamente', esError: false);
    } catch (e) {
      _mostrarSnackBar('No se pudo enviar los emails: $e');
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  void _mostrarSnackBar(String msg, {bool esError = true}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: esError ? _kRed : _kGreen,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  List<Cupon> get _filtrados {
    var lista = _cupones;

    if (_filtro == 'activos') {
      lista = lista.where((c) => c.activo).toList();
    } else if (_filtro == 'inactivos') {
      lista = lista.where((c) => !c.activo).toList();
    }

    if (_busqueda.isNotEmpty) {
      final q = _busqueda.toLowerCase();
      lista = lista
          .where(
            (c) =>
                c.codigo.toLowerCase().contains(q) ||
                c.descripcion.toLowerCase().contains(q),
          )
          .toList();
    }

    if (_orden == 'usados') {
      lista.sort((a, b) => b.usosActuales.compareTo(a.usosActuales));
    } else {
      lista.sort((a, b) => b.id.compareTo(a.id));
    }

    return lista;
  }

  void _mostrarFormEditar(Cupon c) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _FormCrearCupon(
        restaurantes: _restaurantes,
        cuponEditar: c,
        onCrear:
            (
              codigo,
              tipo,
              valor,
              descripcion,
              usosMaximos,
              fechaInicio,
              fechaFin,
              restauranteId,
            ) async {
              // En edición el backend no permite cambiar código ni alcance.
              try {
                await CuponService.editar(
                  c.id,
                  tipo: tipo,
                  valor: valor,
                  descripcion: descripcion,
                  usosMaximos: usosMaximos,
                  fechaInicio: fechaInicio,
                  fechaFin: fechaFin,
                );
                if (mounted) {
                  Navigator.pop(context);
                  _mostrarSnackBar('Cupón actualizado', esError: false);
                  _cargar();
                }
              } catch (e) {
                if (mounted) _mostrarSnackBar('Error al editar: $e');
              }
            },
      ),
    );
  }

  Future<void> _eliminar(Cupon c) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _kCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          '¿Eliminar cupón?',
          style: TextStyle(color: _kText, fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Se eliminará "${c.codigo}" permanentemente. Esta acción no se '
          'puede deshacer.',
          style: const TextStyle(color: _kSub, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar', style: TextStyle(color: _kSub)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _kRed,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'ELIMINAR',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await CuponService.eliminar(c.id);
      if (mounted) {
        _mostrarSnackBar('Cupón eliminado', esError: false);
        _cargar();
      }
    } catch (e) {
      if (mounted) _mostrarSnackBar('No se pudo eliminar: $e');
    }
  }

  bool _expirado(Cupon c) {
    if (c.fechaFin == null) return false;
    return DateTime.tryParse(c.fechaFin!)?.isBefore(DateTime.now()) == true;
  }

  // ── Badge global / sucursal ───────────────────────────────────────────────

  Widget _badgeAlcance(Cupon c) {
    if (c.esGlobal) {
      // Badge granate para cupón global
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          color: _kGranate.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: _kGranate.withValues(alpha: 0.5)),
        ),
        child: const Text(
          'GLOBAL',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: _kGranate,
            letterSpacing: 1,
          ),
        ),
      );
    }

    // Badge azul con nombre de sucursal
    final nombre = _restaurantes
        .where((r) => r.id == c.restauranteId)
        .map((r) => r.nombre)
        .firstOrNull;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: _kBlue.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: _kBlue.withValues(alpha: 0.4)),
      ),
      child: Text(
        nombre ?? 'Sucursal',
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: _kBlue,
          letterSpacing: 0.8,
        ),
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  // ── BUILD ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: const BravoAppBar(title: 'CUPONES'),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _mostrarFormCrear,
        backgroundColor: _kAccent,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text(
          'NUEVO CUPON',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
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
                // Buscador (input claro para contraste sobre la imagen)
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                  child: TextField(
                    onChanged: (v) => setState(() => _busqueda = v),
                    style: const TextStyle(color: Colors.black87),
                    decoration: InputDecoration(
                      hintText: 'Buscar...',
                      hintStyle: const TextStyle(color: Colors.black54),
                      prefixIcon: const Icon(
                        Icons.search,
                        color: Colors.black54,
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),

                // Tabs filtro
                TabBar(
                  controller: _tabCtrl,
                  labelColor: AppColors.linkOnDark,
                  unselectedLabelColor: _kSub,
                  indicatorColor: AppColors.detailOnDark,
                  tabs: const [
                    Tab(text: 'Todos'),
                    Tab(text: 'Activos'),
                    Tab(text: 'Inactivos'),
                  ],
                ),

                // Contenido
                Expanded(
                  child: _cargando
                      ? const Center(
                          child: CircularProgressIndicator(
                            color: AppColors.primaryOnDark,
                          ),
                        )
                      : _error != null
                      ? _buildError()
                      : _filtrados.isEmpty
                      ? const Center(
                          child: Text(
                            'No hay cupones que mostrar.',
                            style: TextStyle(color: _kSub),
                          ),
                        )
                      : RefreshIndicator(
                          color: AppColors.primaryOnDark,
                          backgroundColor: Colors.black87,
                          onRefresh: _cargar,
                          child: ListView.builder(
                            physics: const AlwaysScrollableScrollPhysics(
                              parent: BouncingScrollPhysics(),
                            ),
                            padding: const EdgeInsets.fromLTRB(12, 8, 12, 90),
                            itemCount: _filtrados.length,
                            itemBuilder: (_, i) => _cardCupon(_filtrados[i]),
                          ),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Tarjeta glass de cupón ────────────────────────────────────────────────

  Widget _cardCupon(Cupon c) {
    final exp = _expirado(c);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: c.activo
                    ? Colors.white12
                    : Colors.white.withValues(alpha: 0.05),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  c.codigo,
                                  style: TextStyle(
                                    color: c.activo ? _kText : Colors.white38,
                                    fontSize: 17,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 1,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              _badgeAlcance(c),
                            ],
                          ),
                          if (c.descripcion.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(
                                c.descripcion,
                                style: const TextStyle(
                                  color: _kSub,
                                  fontSize: 12,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.detailOnDark.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: AppColors.detailOnDark.withValues(alpha: 0.4),
                        ),
                      ),
                      child: Text(
                        c.etiquetaValor,
                        style: const TextStyle(
                          color: AppColors.linkOnDark,
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: Wrap(
                        spacing: 12,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          _infoChip(
                            Icons.repeat,
                            c.ilimitado
                                ? 'Ilimitado'
                                : '${c.usosActuales}/${c.usosMaximos} usos',
                          ),
                          if (c.fechaFin != null)
                            _infoChip(
                              Icons.event,
                              'Hasta ${c.fechaFin!.substring(0, 10)}',
                              color: exp ? _kRed : null,
                            ),
                          if (exp)
                            _infoChip(
                              Icons.warning_amber,
                              'EXPIRADO',
                              color: _kRed,
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    _accion(
                      icono: Icons.email_outlined,
                      etiqueta: 'Enviar',
                      color: _kIcono,
                      onTap: () => _mostrarOpcionesEnvio(c),
                    ),
                    _accion(
                      icono: Icons.edit_outlined,
                      etiqueta: 'Editar',
                      color: _kIcono,
                      onTap: () => _mostrarFormEditar(c),
                    ),
                    _accion(
                      icono: Icons.delete_outline,
                      etiqueta: 'Eliminar',
                      color: _kIcono,
                      onTap: () => _eliminar(c),
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

  Widget _infoChip(IconData icono, String texto, {Color? color}) {
    final col = color ?? Colors.white38;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icono, size: 13, color: col),
        const SizedBox(width: 3),
        Text(texto, style: TextStyle(color: col, fontSize: 12)),
      ],
    );
  }

  Widget _accion({
    required IconData icono,
    required String etiqueta,
    required Color color,
    required VoidCallback onTap,
  }) {
    return IconButton(
      onPressed: onTap,
      icon: Icon(icono, size: 20, color: color),
      tooltip: etiqueta,
      visualDensity: VisualDensity.compact,
      splashRadius: 22,
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: _kRed, size: 48),
            const SizedBox(height: 12),
            const Text(
              'No se pudieron cargar los cupones',
              style: TextStyle(color: _kText, fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              _error!,
              style: const TextStyle(color: _kSub, fontSize: 12),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _cargar,
              icon: const Icon(Icons.refresh),
              label: const Text('Reintentar'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _kAccent,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Formulario de creación de cupón (bottom sheet) ────────────────────────────

typedef _OnCrearCupon =
    Future<void> Function(
      String codigo,
      String tipo,
      double valor,
      String descripcion,
      int? usosMaximos,
      String? fechaInicio,
      String? fechaFin,
      String? restauranteId, // null = global
    );

class _FormCrearCupon extends StatefulWidget {
  final List<Restaurante> restaurantes;
  final _OnCrearCupon onCrear;

  /// Si viene un cupón, el formulario abre en modo edición (código y alcance
  /// quedan bloqueados: el backend no permite cambiarlos).
  final Cupon? cuponEditar;

  const _FormCrearCupon({
    required this.restaurantes,
    required this.onCrear,
    this.cuponEditar,
  });

  @override
  State<_FormCrearCupon> createState() => _FormCrearCuponState();
}

class _FormCrearCuponState extends State<_FormCrearCupon> {
  final _formKey = GlobalKey<FormState>();
  final _codigoCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _valorCtrl = TextEditingController();
  final _usosCtrl = TextEditingController();
  final _fechaInicioCtrl = TextEditingController();
  final _fechaFinCtrl = TextEditingController();

  String _tipo = 'porcentaje';
  // true = cupón global, false = cupón de sucursal
  bool _esGlobal = true;
  Restaurante? _sucursalSeleccionada;
  bool _enviando = false;

  bool get _esEdicion => widget.cuponEditar != null;

  @override
  void initState() {
    super.initState();
    final c = widget.cuponEditar;
    if (c != null) {
      _codigoCtrl.text = c.codigo;
      _descCtrl.text = c.descripcion;
      _valorCtrl.text = c.valor.toString();
      _usosCtrl.text = c.usosMaximos?.toString() ?? '';
      _fechaInicioCtrl.text = c.fechaInicio ?? '';
      _fechaFinCtrl.text = c.fechaFin ?? '';
      _tipo = c.tipo;
      _esGlobal = c.esGlobal;
      if (!c.esGlobal) {
        _sucursalSeleccionada = widget.restaurantes
            .where((r) => r.id == c.restauranteId)
            .cast<Restaurante?>()
            .firstOrNull;
      }
    }
  }

  Future<void> _elegirFecha(TextEditingController ctrl) async {
    final base = DateTime.tryParse(ctrl.text) ?? DateTime.now();
    final elegida = await showDatePicker(
      context: context,
      initialDate: base,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 3)),
      builder: (ctx, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(
            primary: AppColors.primaryOnDark,
            surface: AppColors.backgroundDark,
          ),
        ),
        child: child!,
      ),
    );
    if (elegida != null) {
      setState(() {
        ctrl.text =
            '${elegida.year.toString().padLeft(4, '0')}-'
            '${elegida.month.toString().padLeft(2, '0')}-'
            '${elegida.day.toString().padLeft(2, '0')}';
      });
    }
  }

  @override
  void dispose() {
    _codigoCtrl.dispose();
    _descCtrl.dispose();
    _valorCtrl.dispose();
    _usosCtrl.dispose();
    _fechaInicioCtrl.dispose();
    _fechaFinCtrl.dispose();
    super.dispose();
  }

  Future<void> _enviar() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_esGlobal && _sucursalSeleccionada == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selecciona una sucursal'),
          backgroundColor: _kRed,
        ),
      );
      return;
    }

    setState(() => _enviando = true);
    try {
      await widget.onCrear(
        _codigoCtrl.text.trim(),
        _tipo,
        double.parse(_valorCtrl.text.replaceAll(',', '.')),
        _descCtrl.text.trim(),
        _usosCtrl.text.isNotEmpty ? int.tryParse(_usosCtrl.text) : null,
        _fechaInicioCtrl.text.isNotEmpty ? _fechaInicioCtrl.text : null,
        _fechaFinCtrl.text.isNotEmpty ? _fechaFinCtrl.text : null,
        _esGlobal ? null : _sucursalSeleccionada!.id,
      );
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.backgroundDark,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(20, 24, 20, 20 + bottom),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Indicador de agarre
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
                Text(
                  _esEdicion ? 'EDITAR CUPON' : 'NUEVO CUPON',
                  style: const TextStyle(
                    color: _kText,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 4),
                const Divider(color: Colors.white12),
                const SizedBox(height: 16),

                // ── Alcance: en edición no se puede cambiar ───────────
                IgnorePointer(
                  ignoring: _esEdicion,
                  child: Opacity(
                    opacity: _esEdicion ? 0.55 : 1,
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'ALCANCE DEL CUPON',
                            style: TextStyle(
                              color: Colors.white54,
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.4,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              // Opción Global
                              Expanded(
                                child: GestureDetector(
                                  onTap: () => setState(() => _esGlobal = true),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 10,
                                      horizontal: 12,
                                    ),
                                    decoration: BoxDecoration(
                                      color: _esGlobal
                                          ? _kGranate.withValues(alpha: 0.25)
                                          : Colors.transparent,
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: _esGlobal
                                            ? _kGranate
                                            : Colors.white24,
                                        width: _esGlobal ? 1.5 : 1,
                                      ),
                                    ),
                                    child: const Column(
                                      children: [
                                        Text(
                                          'GLOBAL',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        SizedBox(height: 2),
                                        Text(
                                          'Todas las sucursales',
                                          style: TextStyle(
                                            color: Colors.white54,
                                            fontSize: 12,
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              // Opción Sucursal
                              Expanded(
                                child: GestureDetector(
                                  onTap: () =>
                                      setState(() => _esGlobal = false),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 10,
                                      horizontal: 12,
                                    ),
                                    decoration: BoxDecoration(
                                      color: !_esGlobal
                                          ? _kBlue.withValues(alpha: 0.2)
                                          : Colors.transparent,
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: !_esGlobal
                                            ? _kBlue
                                            : Colors.white24,
                                        width: !_esGlobal ? 1.5 : 1,
                                      ),
                                    ),
                                    child: const Column(
                                      children: [
                                        Text(
                                          'SUCURSAL',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        SizedBox(height: 2),
                                        Text(
                                          'Una sucursal específica',
                                          style: TextStyle(
                                            color: Colors.white54,
                                            fontSize: 12,
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          // Dropdown de sucursal (visible solo si no es global)
                          if (!_esGlobal) ...[
                            const SizedBox(height: 12),
                            DropdownButtonFormField<Restaurante>(
                              dropdownColor: _kCard,
                              initialValue: _sucursalSeleccionada,
                              hint: const Text(
                                'Selecciona una sucursal',
                                style: TextStyle(color: Colors.white54),
                              ),
                              style: const TextStyle(color: _kText),
                              decoration: InputDecoration(
                                filled: true,
                                fillColor: Colors.white.withValues(alpha: 0.06),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: const BorderSide(
                                    color: Colors.white24,
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: const BorderSide(
                                    color: Colors.white24,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: const BorderSide(
                                    color: _kBlue,
                                    width: 1.5,
                                  ),
                                ),
                              ),
                              items: widget.restaurantes.map((r) {
                                return DropdownMenuItem(
                                  value: r,
                                  child: Text(r.nombre),
                                );
                              }).toList(),
                              onChanged: (r) =>
                                  setState(() => _sucursalSeleccionada = r),
                              validator: (_) =>
                                  (!_esGlobal && _sucursalSeleccionada == null)
                                  ? 'Selecciona una sucursal'
                                  : null,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
                if (_esEdicion)
                  const Padding(
                    padding: EdgeInsets.only(top: 6),
                    child: Text(
                      'El alcance no se puede cambiar al editar.',
                      style: TextStyle(color: Colors.white38, fontSize: 11),
                    ),
                  ),

                const SizedBox(height: 16),

                // ── Campos del cupón ──────────────────────────────────
                _campo(
                  ctrl: _codigoCtrl,
                  label: _esEdicion ? 'Código (no editable)' : 'Código',
                  readOnly: _esEdicion,
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Obligatorio' : null,
                ),
                const SizedBox(height: 12),
                _campo(ctrl: _descCtrl, label: 'Descripción'),
                const SizedBox(height: 12),

                // Tipo de descuento
                DropdownButtonFormField<String>(
                  dropdownColor: _kCard,
                  initialValue: _tipo,
                  style: const TextStyle(color: _kText),
                  decoration: _inputDeco('Tipo de descuento'),
                  items: const [
                    DropdownMenuItem(
                      value: 'porcentaje',
                      child: Text('Porcentaje (%)'),
                    ),
                    DropdownMenuItem(
                      value: 'fijo',
                      child: Text('Importe fijo (€)'),
                    ),
                  ],
                  onChanged: (v) => setState(() => _tipo = v!),
                ),
                const SizedBox(height: 12),
                _campo(
                  ctrl: _valorCtrl,
                  label: 'Valor',
                  keyboard: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Obligatorio';
                    if (double.tryParse(v.replaceAll(',', '.')) == null) {
                      return 'Número inválido';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                _campo(
                  ctrl: _usosCtrl,
                  label: 'Usos máximos (vacío = ilimitado)',
                  keyboard: TextInputType.number,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _campo(
                        ctrl: _fechaInicioCtrl,
                        label: 'Inicio (opcional)',
                        readOnly: true,
                        onTap: () => _elegirFecha(_fechaInicioCtrl),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _campo(
                        ctrl: _fechaFinCtrl,
                        label: 'Fin (opcional)',
                        readOnly: true,
                        onTap: () => _elegirFecha(_fechaFinCtrl),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // Botón crear
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _enviando ? null : _enviar,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _esGlobal ? _kGranate : _kAccent,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 52),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: _enviando
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            _esEdicion
                                ? 'GUARDAR CAMBIOS'
                                : (_esGlobal
                                      ? 'CREAR CUPON GLOBAL'
                                      : 'CREAR CUPON'),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Helpers de formulario ─────────────────────────────────────────────────

  Widget _campo({
    required TextEditingController ctrl,
    required String label,
    TextInputType? keyboard,
    FormFieldValidator<String>? validator,
    bool readOnly = false,
    VoidCallback? onTap,
  }) {
    return TextFormField(
      controller: ctrl,
      keyboardType: keyboard,
      readOnly: readOnly,
      onTap: onTap,
      style: TextStyle(color: readOnly ? Colors.white54 : _kText),
      decoration: _inputDeco(label),
      validator: validator,
    );
  }

  InputDecoration _inputDeco(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.white54, fontSize: 13),
      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.06),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Colors.white24),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.detailOnDark, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: _kRed),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: _kRed),
      ),
    );
  }
}

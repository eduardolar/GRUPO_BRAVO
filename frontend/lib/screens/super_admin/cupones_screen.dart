import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

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
const _kAccent = AppColors.primaryAccent; // fills sólidos con texto blanco (legible sobre oscuro)

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
        onCrear: (codigo, tipo, valor, descripcion, usosMaximos, fechaInicio,
            fechaFin, restauranteId) async {
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
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded,
                color: AppColors.warning, size: 22),
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
              const TextSpan(
                text:
                    'Vas a crear un cupón aplicable en ',
              ),
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
                onChanged: (val) =>
                    setDialogState(() => destino = val!),
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
                      child: Text(r.nombre,
                          overflow: TextOverflow.ellipsis),
                    );
                  }).toList(),
                  onChanged: (val) =>
                      setDialogState(() => restauranteId = val),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar',
                  style: TextStyle(color: _kSub)),
            ),
            ElevatedButton(
              style:
                  ElevatedButton.styleFrom(backgroundColor: _kGreen),
              onPressed: (destino == 'restaurante' &&
                      restauranteId == null)
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

  Future<void> _ejecutarEnvioMasivo(
    Cupon c,
    String tipo,
    String? resId,
  ) async {
    setState(() => _cargando = true);
    try {
      await CuponService.enviarNotificacionMasiva(
        cuponId: c.id,
        tipoFiltro: tipo,
        restauranteId: resId,
      );
      _mostrarSnackBar('Emails en cola de envío correctamente',
          esError: false);
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

  Future<void> _duplicar(Cupon c) async {
    await CuponService.crear(
      codigo: '${c.codigo}_COPY',
      tipo: c.tipo,
      valor: c.valor,
      descripcion: c.descripcion,
      usosMaximos: c.usosMaximos,
      fechaInicio: c.fechaInicio,
      fechaFin: c.fechaFin,
    );
    _cargar();
  }

  void _mostrarQR(Cupon c) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: _kCard,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                c.codigo,
                style: const TextStyle(
                  color: _kText,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 20),
              QrImageView(
                data: c.codigo,
                size: 200,
                backgroundColor: Colors.white,
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool _expirado(Cupon c) {
    if (c.fechaFin == null) return false;
    return DateTime.tryParse(c.fechaFin!)?.isBefore(DateTime.now()) ==
        true;
  }

  // ── Badge global / sucursal ───────────────────────────────────────────────

  Widget _badgeAlcance(Cupon c) {
    if (c.esGlobal) {
      // Badge granate para cupón global
      return Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
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
      body: Column(
        children: [
          // Buscador
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
            child: TextField(
              onChanged: (v) => setState(() => _busqueda = v),
              // Fondo blanco sólido + texto/iconos negros: input "claro"
              // tipo Google para garantizar contraste sobre la imagen Bravo.
              style: const TextStyle(color: Colors.black87),
              decoration: InputDecoration(
                hintText: 'Buscar...',
                hintStyle: const TextStyle(color: Colors.black54),
                prefixIcon: const Icon(Icons.search, color: Colors.black54),
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
                    child: CircularProgressIndicator(color: AppColors.primaryOnDark),
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
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(
                                12, 8, 12, 80),
                            itemCount: _filtrados.length,
                            itemBuilder: (_, i) {
                              final c = _filtrados[i];
                              final exp = _expirado(c);

                              return Card(
                                color: _kCard,
                                margin: const EdgeInsets.only(bottom: 8),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 8, horizontal: 4),
                                  child: ListTile(
                                    title: Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            c.codigo,
                                            style: const TextStyle(
                                                color: _kText,
                                                fontWeight:
                                                    FontWeight.bold),
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        // Badge de alcance
                                        _badgeAlcance(c),
                                      ],
                                    ),
                                    subtitle: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const SizedBox(height: 4),
                                        Text(
                                          c.descripcion,
                                          style: const TextStyle(
                                              color: _kSub),
                                        ),
                                        if (exp)
                                          const Text(
                                            'EXPIRADO',
                                            style: TextStyle(
                                                color: _kRed,
                                                fontSize: 11,
                                                fontWeight:
                                                    FontWeight.bold),
                                          ),
                                        Text(
                                          'Usos: ${c.usosActuales}'
                                          '${c.usosMaximos != null ? ' / ${c.usosMaximos}' : ''}',
                                          style: const TextStyle(
                                              color: _kSub,
                                              fontSize: 11),
                                        ),
                                      ],
                                    ),
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          icon: const Icon(
                                            Icons.email_outlined,
                                            color: _kBlue,
                                          ),
                                          tooltip: 'Enviar emails',
                                          onPressed: () =>
                                              _mostrarOpcionesEnvio(c),
                                        ),
                                        IconButton(
                                          icon: const Icon(
                                            Icons.qr_code,
                                            color: AppColors.detailOnDark,
                                          ),
                                          tooltip: 'Ver QR',
                                          onPressed: () => _mostrarQR(c),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.copy,
                                              color: _kBlue),
                                          tooltip: 'Copiar código',
                                          onPressed: () {
                                            Clipboard.setData(
                                              ClipboardData(
                                                  text: c.codigo),
                                            );
                                          },
                                        ),
                                        IconButton(
                                          icon: const Icon(
                                            Icons.copy_all,
                                            color: _kGreen,
                                          ),
                                          tooltip: 'Duplicar',
                                          onPressed: () => _duplicar(c),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
          ),
        ],
      ),
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

typedef _OnCrearCupon = Future<void> Function(
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

  const _FormCrearCupon({
    required this.restaurantes,
    required this.onCrear,
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
                const Text(
                  'NUEVO CUPON',
                  style: TextStyle(
                    color: _kText,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 4),
                const Divider(color: Colors.white12),
                const SizedBox(height: 16),

                // ── Toggle global / sucursal ──────────────────────────
                Container(
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
                              onTap: () =>
                                  setState(() => _esGlobal = true),
                              child: AnimatedContainer(
                                duration:
                                    const Duration(milliseconds: 200),
                                padding: const EdgeInsets.symmetric(
                                    vertical: 10, horizontal: 12),
                                decoration: BoxDecoration(
                                  color: _esGlobal
                                      ? _kGranate.withValues(alpha: 0.25)
                                      : Colors.transparent,
                                  borderRadius:
                                      BorderRadius.circular(10),
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
                                duration:
                                    const Duration(milliseconds: 200),
                                padding: const EdgeInsets.symmetric(
                                    vertical: 10, horizontal: 12),
                                decoration: BoxDecoration(
                                  color: !_esGlobal
                                      ? _kBlue.withValues(alpha: 0.2)
                                      : Colors.transparent,
                                  borderRadius:
                                      BorderRadius.circular(10),
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
                            fillColor:
                                Colors.white.withValues(alpha: 0.06),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide:
                                  const BorderSide(color: Colors.white24),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide:
                                  const BorderSide(color: Colors.white24),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(
                                  color: _kBlue, width: 1.5),
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
                          validator: (_) => (!_esGlobal &&
                                  _sucursalSeleccionada == null)
                              ? 'Selecciona una sucursal'
                              : null,
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // ── Campos del cupón ──────────────────────────────────
                _campo(
                  ctrl: _codigoCtrl,
                  label: 'Código',
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Obligatorio'
                      : null,
                ),
                const SizedBox(height: 12),
                _campo(
                  ctrl: _descCtrl,
                  label: 'Descripción',
                ),
                const SizedBox(height: 12),

                // Tipo de descuento
                DropdownButtonFormField<String>(
                  dropdownColor: _kCard,
                  initialValue: _tipo,
                  style: const TextStyle(color: _kText),
                  decoration: _inputDeco('Tipo de descuento'),
                  items: const [
                    DropdownMenuItem(
                        value: 'porcentaje', child: Text('Porcentaje (%)')),
                    DropdownMenuItem(
                        value: 'fijo', child: Text('Importe fijo (€)')),
                  ],
                  onChanged: (v) => setState(() => _tipo = v!),
                ),
                const SizedBox(height: 12),
                _campo(
                  ctrl: _valorCtrl,
                  label: 'Valor',
                  keyboard: const TextInputType.numberWithOptions(
                      decimal: true),
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
                        label: 'Inicio (YYYY-MM-DD)',
                        keyboard: TextInputType.datetime,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _campo(
                        ctrl: _fechaFinCtrl,
                        label: 'Fin (YYYY-MM-DD)',
                        keyboard: TextInputType.datetime,
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
                      backgroundColor:
                          _esGlobal ? _kGranate : _kAccent,
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
                            _esGlobal
                                ? 'CREAR CUPON GLOBAL'
                                : 'CREAR CUPON',
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
  }) {
    return TextFormField(
      controller: ctrl,
      keyboardType: keyboard,
      style: const TextStyle(color: _kText),
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

import 'dart:ui';
import 'package:flutter/material.dart';
import '../../components/admin/admin_max_width.dart';
import '../../components/bravo_app_bar.dart';
import '../../core/colors_style.dart';
import '../../models/cupon_model.dart';
import '../../services/cupon_service.dart';
import '../../services/http_client.dart';

// ─── Constantes de estilo ─────────────────────────────────────────────────────
const _kSheetBg = AppColors.bottomSheetBg;
// Negro translúcido (alpha ~55%): sobre la imagen Bravo de fondo el blanco
// translúcido se confundía con el papel claro y dejaba el texto invisible.
const _kFieldFill = Color(0x8C000000);
const _kBorder = Color(0x33FFFFFF);

class AdminCuponesScreen extends StatefulWidget {
  const AdminCuponesScreen({super.key});

  @override
  State<AdminCuponesScreen> createState() => _AdminCuponesScreenState();
}

class _AdminCuponesScreenState extends State<AdminCuponesScreen>
    with SingleTickerProviderStateMixin {
  List<Cupon> _cupones = [];
  bool _cargando = true;
  String? _error;
  String _busqueda = '';
  // 0 = todos, 1 = activos, 2 = inactivos
  int _tabIndex = 0;

  late TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this)
      ..addListener(() {
        if (!_tabCtrl.indexIsChanging) {
          setState(() => _tabIndex = _tabCtrl.index);
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
    if (!mounted) return;
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      // El backend ya filtra por restaurante del token — no pasamos restauranteId
      final lista = await CuponService.listar();
      if (!mounted) return;
      setState(() {
        _cupones = lista;
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

  List<Cupon> get _filtrados {
    var lista = _cupones;
    if (_tabIndex == 1) lista = lista.where((c) => c.activo).toList();
    if (_tabIndex == 2) lista = lista.where((c) => !c.activo).toList();
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
    // Más recientes primero
    lista.sort((a, b) => b.id.compareTo(a.id));
    return lista;
  }

  bool _expirado(Cupon c) {
    if (c.fechaFin == null) return false;
    return DateTime.tryParse(c.fechaFin!)?.isBefore(DateTime.now()) == true;
  }

  Future<void> _toggleActivo(Cupon c) async {
    try {
      await CuponService.toggleActivo(c.id, !c.activo);
      _cargar();
    } catch (e) {
      _showSnack(e.toString());
    }
  }

  void _abrirCrearCupon() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _FormularioCuponSheet(onGuardado: _cargar),
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
      appBar: const BravoAppBar(title: 'CUPONES'),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _abrirCrearCupon,
        backgroundColor: AppColors.button,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text(
          'NUEVO CUPÓN',
          style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1),
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
            child: AdminMaxWidth(
              child: Column(
                children: [
                // ─── Buscador glass ────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      // Fondo blanco sólido + texto/iconos negros: la imagen
                      // Bravo es muy clara y los overlays translúcidos no
                      // daban contraste suficiente. Patrón input "claro".
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.black.withValues(alpha: 0.15),
                        ),
                      ),
                      child: TextField(
                        style: const TextStyle(color: Colors.black87),
                        onChanged: (v) =>
                            setState(() => _busqueda = v.toLowerCase()),
                        decoration: const InputDecoration(
                          hintText: 'Buscar código o descripción…',
                          hintStyle: TextStyle(
                              color: Colors.black54, fontSize: 14),
                          prefixIcon: Icon(Icons.search,
                              color: Colors.black54),
                          border: InputBorder.none,
                          contentPadding:
                              EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                  ),
                ),

                // ─── Tabs ──────────────────────────────────────────
                TabBar(
                  controller: _tabCtrl,
                  indicatorColor: AppColors.button,
                  indicatorWeight: 3,
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.white38,
                  labelStyle: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    letterSpacing: 1,
                  ),
                  tabs: const [
                    Tab(text: 'TODOS'),
                    Tab(text: 'ACTIVOS'),
                    Tab(text: 'INACTIVOS'),
                  ],
                ),

                Expanded(child: _buildCuerpo()),
              ],
            ),
            ),
          ),
        ),
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

    final lista = _filtrados;

    if (lista.isEmpty) {
      return const Center(
        child: Text(
          'No hay cupones que mostrar.',
          style: TextStyle(color: Colors.white54, fontSize: 15),
        ),
      );
    }

    return RefreshIndicator(
      color: AppColors.button,
      backgroundColor: Colors.black87,
      onRefresh: _cargar,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics()),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
        itemCount: lista.length,
        itemBuilder: (_, i) => _cardCupon(lista[i]),
      ),
    );
  }

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
                color: c.activo ? Colors.white12 : Colors.white.withValues(alpha: 0.05),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Código + valor + toggle activo
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            c.codigo,
                            style: TextStyle(
                              color: c.activo
                                  ? Colors.white
                                  : Colors.white38,
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1,
                            ),
                          ),
                          if (c.descripcion.isNotEmpty)
                            Text(
                              c.descripcion,
                              style: const TextStyle(
                                  color: Colors.white54, fontSize: 12),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ),
                    ),
                    // Valor del cupón
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: AppColors.button.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: AppColors.button
                                .withValues(alpha: 0.4)),
                      ),
                      child: Text(
                        c.etiquetaValor,
                        style: const TextStyle(
                          color: AppColors.button,
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Switch activo/inactivo
                    Switch(
                      value: c.activo,
                      onChanged: (_) => _toggleActivo(c),
                      activeThumbColor: AppColors.disp,
                      activeTrackColor: AppColors.disp.withValues(alpha: 0.4),
                      inactiveThumbColor: Colors.white38,
                      inactiveTrackColor: Colors.white12,
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Usos y fechas
                Wrap(
                  spacing: 12,
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
                        color: exp ? AppColors.error : null,
                      ),
                    if (exp)
                      _infoChip(Icons.warning_amber,
                          'EXPIRADO',
                          color: AppColors.error),
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
    final c = color ?? Colors.white38;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icono, size: 13, color: c),
        const SizedBox(width: 3),
        Text(texto, style: TextStyle(color: c, fontSize: 12)),
      ],
    );
  }

}

// ─── Bottom sheet: crear cupón ────────────────────────────────────────────────

class _FormularioCuponSheet extends StatefulWidget {
  final VoidCallback onGuardado;

  const _FormularioCuponSheet({required this.onGuardado});

  @override
  State<_FormularioCuponSheet> createState() => _FormularioCuponSheetState();
}

class _FormularioCuponSheetState extends State<_FormularioCuponSheet> {
  final _formKey = GlobalKey<FormState>();
  final _codigoCtrl = TextEditingController();
  final _valorCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _usosCtrl = TextEditingController();
  final _fechaInicioCtrl = TextEditingController();
  final _fechaFinCtrl = TextEditingController();

  String _tipo = 'porcentaje';
  bool _guardando = false;

  @override
  void dispose() {
    _codigoCtrl.dispose();
    _valorCtrl.dispose();
    _descCtrl.dispose();
    _usosCtrl.dispose();
    _fechaInicioCtrl.dispose();
    _fechaFinCtrl.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _guardando = true);
    try {
      await CuponService.crear(
        codigo: _codigoCtrl.text.trim().toUpperCase(),
        tipo: _tipo,
        valor: double.parse(_valorCtrl.text.trim()),
        descripcion: _descCtrl.text.trim(),
        usosMaximos: _usosCtrl.text.trim().isNotEmpty
            ? int.tryParse(_usosCtrl.text.trim())
            : null,
        fechaInicio: _fechaInicioCtrl.text.trim(),
        fechaFin: _fechaFinCtrl.text.trim(),
      );
      if (!mounted) return;
      Navigator.pop(context);
      widget.onGuardado();
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message,
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold)),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString(),
                style: const TextStyle(color: Colors.white)),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  Future<void> _elegirFecha(TextEditingController ctrl) async {
    final elegida = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 3)),
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
    if (elegida != null) {
      ctrl.text =
          '${elegida.year.toString().padLeft(4, '0')}-'
          '${elegida.month.toString().padLeft(2, '0')}-'
          '${elegida.day.toString().padLeft(2, '0')}';
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      decoration: const BoxDecoration(
        color: _kSheetBg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(24, 20, 24, 24 + bottom),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
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
                'NUEVO CUPÓN',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 20),

              // Código
              _Campo(
                controlador: _codigoCtrl,
                etiqueta: 'Código (ej. VERANO20)',
                icono: Icons.local_offer_outlined,
                validador: (v) => (v == null || v.trim().isEmpty)
                    ? 'Campo obligatorio'
                    : null,
              ),
              const SizedBox(height: 14),

              // Tipo
              DropdownButtonFormField<String>(
                initialValue: _tipo,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                dropdownColor: _kSheetBg,
                decoration: InputDecoration(
                  labelText: 'Tipo',
                  labelStyle: const TextStyle(color: Colors.white60),
                  prefixIcon: const Icon(Icons.category_outlined,
                      color: Colors.white60),
                  filled: true,
                  fillColor: _kFieldFill,
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: _kBorder),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        const BorderSide(color: AppColors.button, width: 2),
                  ),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                items: const [
                  DropdownMenuItem(
                      value: 'porcentaje',
                      child: Text('Porcentaje (%)')),
                  DropdownMenuItem(
                      value: 'fijo', child: Text('Descuento fijo (€)')),
                ],
                onChanged: (v) => setState(() => _tipo = v!),
              ),
              const SizedBox(height: 14),

              // Valor
              _Campo(
                controlador: _valorCtrl,
                etiqueta: _tipo == 'porcentaje'
                    ? 'Valor (%)'
                    : 'Valor (€)',
                icono: Icons.percent,
                tipoTeclado: const TextInputType.numberWithOptions(decimal: true),
                validador: (v) {
                  if (v == null || v.trim().isEmpty) return 'Campo obligatorio';
                  if (double.tryParse(v.trim()) == null) return 'Número no válido';
                  return null;
                },
              ),
              const SizedBox(height: 14),

              // Descripción
              _Campo(
                controlador: _descCtrl,
                etiqueta: 'Descripción (opcional)',
                icono: Icons.description_outlined,
              ),
              const SizedBox(height: 14),

              // Usos máximos
              _Campo(
                controlador: _usosCtrl,
                etiqueta: 'Usos máximos (vacío = ilimitado)',
                icono: Icons.repeat,
                tipoTeclado: TextInputType.number,
              ),
              const SizedBox(height: 14),

              // Fecha inicio
              _CampoFecha(
                controlador: _fechaInicioCtrl,
                etiqueta: 'Fecha inicio (opcional)',
                onTap: () => _elegirFecha(_fechaInicioCtrl),
              ),
              const SizedBox(height: 14),

              // Fecha fin
              _CampoFecha(
                controlador: _fechaFinCtrl,
                etiqueta: 'Fecha fin (opcional)',
                onTap: () => _elegirFecha(_fechaFinCtrl),
              ),
              const SizedBox(height: 24),

              // Botón guardar
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.button,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: _guardando ? null : _guardar,
                  child: _guardando
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2),
                        )
                      : const Text(
                          'CREAR CUPÓN',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.5),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Widgets auxiliares ───────────────────────────────────────────────────────

class _Campo extends StatelessWidget {
  final TextEditingController controlador;
  final String etiqueta;
  final IconData icono;
  final TextInputType tipoTeclado;
  final String? Function(String?)? validador;

  const _Campo({
    required this.controlador,
    required this.etiqueta,
    required this.icono,
    this.tipoTeclado = TextInputType.text,
    this.validador,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controlador,
      keyboardType: tipoTeclado,
      style: const TextStyle(color: Colors.white),
      validator: validador,
      decoration: InputDecoration(
        labelText: etiqueta,
        labelStyle: const TextStyle(color: Colors.white60),
        prefixIcon: Icon(icono, color: Colors.white60),
        filled: true,
        fillColor: _kFieldFill,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _kBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.button, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.error, width: 2),
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}

class _CampoFecha extends StatelessWidget {
  final TextEditingController controlador;
  final String etiqueta;
  final VoidCallback onTap;

  const _CampoFecha({
    required this.controlador,
    required this.etiqueta,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controlador,
      readOnly: true,
      onTap: onTap,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: etiqueta,
        labelStyle: const TextStyle(color: Colors.white60),
        prefixIcon:
            const Icon(Icons.calendar_today, color: Colors.white60),
        filled: true,
        fillColor: _kFieldFill,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _kBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.button, width: 2),
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../components/bravo_app_bar.dart';
import '../../models/cupon_model.dart';
import '../../services/cupon_service.dart';
import '../../core/colors_style.dart';

// ─── Colores ─────────────────────────────────────────────────────────────────
const _kBg     = Color(0xFF0F0F0F);
const _kCard   = Color(0xFF1C1C1E);
const _kBorder = Color(0xFF2C2C2E);
const _kText   = Color(0xFFEAEAEA);
const _kSub    = Color(0xFF8E8E93);
const _kGreen  = Color(0xFF34C759);
const _kOrange = Color(0xFFFF9500);
const _kRed    = Color(0xFFFF3B30);
const _kBlue   = Color(0xFF0A84FF);
const _kAccent = AppColors.button;

class CuponesScreen extends StatefulWidget {
  const CuponesScreen({super.key});

  @override
  State<CuponesScreen> createState() => _CuponesScreenState();
}

class _CuponesScreenState extends State<CuponesScreen>
    with SingleTickerProviderStateMixin {
  List<Cupon> _cupones = [];
  bool        _cargando = true;
  String?     _error;
  String      _filtro = 'todos'; // todos | activos | inactivos
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

  // ─── Carga ───────────────────────────────────────────────────────────────
  Future<void> _cargar() async {
    setState(() { _cargando = true; _error = null; });
    try {
      final lista = await CuponService.listar();
      setState(() { _cupones = lista; _cargando = false; });
    } catch (e) {
      setState(() { _error = e.toString(); _cargando = false; });
    }
  }

  // ─── Filtrado ─────────────────────────────────────────────────────────────
  List<Cupon> get _filtrados {
    switch (_filtro) {
      case 'activos':   return _cupones.where((c) => c.activo).toList();
      case 'inactivos': return _cupones.where((c) => !c.activo).toList();
      default:          return _cupones;
    }
  }

  // ─── Acciones ────────────────────────────────────────────────────────────
  Future<void> _toggleActivo(Cupon c) async {
    try {
      await CuponService.toggleActivo(c.id, !c.activo);
      await _cargar();
    } catch (e) {
      _snack('Error: $e', _kRed);
    }
  }

  Future<void> _eliminar(Cupon c) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: _kCard,
        title: const Text('Eliminar cupón', style: TextStyle(color: _kText)),
        content: Text(
          '¿Eliminar "${c.codigo}"? Esta acción no se puede deshacer.',
          style: const TextStyle(color: _kSub),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar', style: TextStyle(color: _kSub))),
          TextButton(onPressed: () => Navigator.pop(context, true),
              child: const Text('Eliminar', style: TextStyle(color: _kRed))),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await CuponService.eliminar(c.id);
      await _cargar();
      _snack('Cupón eliminado', _kOrange);
    } catch (e) {
      _snack('Error: $e', _kRed);
    }
  }

  Future<void> _abrirFormulario({Cupon? cupon}) async {
    final guardado = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _FormularioCupon(cupon: cupon),
    );
    if (guardado == true) {
      await _cargar();
      _snack(cupon == null ? 'Cupón creado' : 'Cupón actualizado', _kGreen);
    }
  }

  void _snack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(color: Colors.white)),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  // ─── BUILD ────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: const BravoAppBar(title: 'CUPONES'),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _abrirFormulario(),
        backgroundColor: _kAccent,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Nuevo cupón',
            style: TextStyle(fontWeight: FontWeight.w600)),
      ),
      body: Container(
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
                Colors.black.withValues(alpha: 0.55),
                Colors.black.withValues(alpha: 0.88),
              ],
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                Container(
                  margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.06),
                    border: Border.all(color: Colors.white12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: TabBar(
                    controller: _tabCtrl,
                    indicatorColor: _kAccent,
                    labelColor: _kAccent,
                    unselectedLabelColor: _kSub,
                    labelStyle: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 13),
                    tabs: [
                      Tab(text: 'Todos (${_cupones.length})'),
                      Tab(text:
                          'Activos (${_cupones.where((c) => c.activo).length})'),
                      Tab(text:
                          'Inactivos (${_cupones.where((c) => !c.activo).length})'),
                    ],
                  ),
                ),
                Expanded(child: _buildBody()),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_cargando) {
      return const Center(child: CircularProgressIndicator(color: _kAccent));
    }
    if (_error != null) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.error_outline_rounded, color: _kRed, size: 48),
          const SizedBox(height: 12),
          Text(_error!, style: const TextStyle(color: _kSub)),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _cargar,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Reintentar'),
            style: ElevatedButton.styleFrom(backgroundColor: _kAccent),
          ),
        ]),
      );
    }
    final lista = _filtrados;
    if (lista.isEmpty) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.local_offer_outlined, color: _kSub, size: 56),
          const SizedBox(height: 16),
          Text(
            _filtro == 'todos'
                ? 'Sin cupones todavía.\nPulsa + para crear el primero.'
                : 'No hay cupones en esta categoría.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: _kSub, height: 1.6),
          ),
        ]),
      );
    }
    return RefreshIndicator(
      onRefresh: _cargar,
      color: _kAccent,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        itemCount: lista.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (_, i) => _TarjetaCupon(
          cupon: lista[i],
          onToggle: () => _toggleActivo(lista[i]),
          onEdit: () => _abrirFormulario(cupon: lista[i]),
          onDelete: () => _eliminar(lista[i]),
        ),
      ),
    );
  }
}

// ─── Tarjeta de cupón ─────────────────────────────────────────────────────────

class _TarjetaCupon extends StatelessWidget {
  final Cupon      cupon;
  final VoidCallback onToggle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _TarjetaCupon({
    required this.cupon,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final c = cupon;
    final porcentaje = c.tipo == 'porcentaje';

    return AnimatedOpacity(
      opacity: c.activo ? 1.0 : 0.55,
      duration: const Duration(milliseconds: 250),
      child: Container(
        decoration: BoxDecoration(
          color: _kCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: c.activo ? _kBorder : _kBorder.withValues(alpha: 0.5),
          ),
        ),
        child: Column(
          children: [
            // ── Cabecera: código + valor + switch ─────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 12, 10),
              child: Row(
                children: [
                  // Ícono tipo
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: (porcentaje ? _kBlue : _kGreen)
                          .withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      porcentaje
                          ? Icons.percent_rounded
                          : Icons.euro_rounded,
                      color: porcentaje ? _kBlue : _kGreen,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Código + copy
                        Row(
                          children: [
                            Text(
                              c.codigo,
                              style: const TextStyle(
                                color: _kText,
                                fontWeight: FontWeight.w800,
                                fontSize: 16,
                                letterSpacing: 1.2,
                              ),
                            ),
                            const SizedBox(width: 6),
                            GestureDetector(
                              onTap: () {
                                Clipboard.setData(
                                    ClipboardData(text: c.codigo));
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Código copiado'),
                                    duration: Duration(seconds: 1),
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                              },
                              child: const Icon(Icons.copy_rounded,
                                  size: 14, color: _kSub),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        // Descuento
                        RichText(
                          text: TextSpan(
                            children: [
                              TextSpan(
                                text: c.etiquetaValor,
                                style: TextStyle(
                                  color:
                                      porcentaje ? _kBlue : _kGreen,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 18,
                                ),
                              ),
                              TextSpan(
                                text: porcentaje
                                    ? ' de descuento'
                                    : ' de descuento fijo',
                                style: const TextStyle(
                                    color: _kSub, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Switch activo
                  Switch.adaptive(
                    value: c.activo,
                    activeThumbColor: _kGreen,
                    inactiveThumbColor: _kSub,
                    onChanged: (_) => onToggle(),
                  ),
                ],
              ),
            ),

            const Divider(color: _kBorder, height: 1),

            // ── Detalles ──────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (c.descripcion.isNotEmpty) ...[
                    Text(c.descripcion,
                        style: const TextStyle(color: _kSub, fontSize: 13)),
                    const SizedBox(height: 8),
                  ],
                  // Usos + fechas
                  Wrap(
                    spacing: 10,
                    runSpacing: 6,
                    children: [
                      _InfoChip(
                        icon: Icons.confirmation_num_outlined,
                        label: c.ilimitado
                            ? '${c.usosActuales} usos (ilimitado)'
                            : '${c.usosActuales} / ${c.usosMaximos} usos',
                        color: _usosColor(c),
                      ),
                      if (c.fechaInicio != null)
                        _InfoChip(
                          icon: Icons.calendar_today_outlined,
                          label: 'Desde ${_fmtFecha(c.fechaInicio!)}',
                          color: _kSub,
                        ),
                      if (c.fechaFin != null)
                        _InfoChip(
                          icon: Icons.event_busy_outlined,
                          label: 'Hasta ${_fmtFecha(c.fechaFin!)}',
                          color: _kOrange,
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  // Acciones
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton.icon(
                        onPressed: onEdit,
                        icon: const Icon(Icons.edit_outlined,
                            size: 16, color: _kAccent),
                        label: const Text('Editar',
                            style:
                                TextStyle(color: _kAccent, fontSize: 13)),
                        style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6)),
                      ),
                      TextButton.icon(
                        onPressed: onDelete,
                        icon: const Icon(Icons.delete_outline,
                            size: 16, color: _kRed),
                        label: const Text('Eliminar',
                            style: TextStyle(color: _kRed, fontSize: 13)),
                        style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _usosColor(Cupon c) {
    if (c.ilimitado) return _kSub;
    final ratio = c.usosActuales / c.usosMaximos!;
    if (ratio >= 1.0) return _kRed;
    if (ratio >= 0.75) return _kOrange;
    return _kGreen;
  }

  String _fmtFecha(String iso) {
    try {
      final d = DateTime.parse(iso);
      return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
    } catch (_) {
      return iso;
    }
  }
}

// ─── Chip de info ─────────────────────────────────────────────────────────────

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String   label;
  final Color    color;
  const _InfoChip(
      {required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(color: color, fontSize: 12)),
      ],
    );
  }
}

// ─── Formulario de creación / edición ─────────────────────────────────────────

class _FormularioCupon extends StatefulWidget {
  final Cupon? cupon;
  const _FormularioCupon({this.cupon});

  @override
  State<_FormularioCupon> createState() => _FormularioCuponState();
}

class _FormularioCuponState extends State<_FormularioCupon> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _codigoCtrl;
  late final TextEditingController _valorCtrl;
  late final TextEditingController _descCtrl;
  late final TextEditingController _usosCtrl;
  late final TextEditingController _inicioCtrl;
  late final TextEditingController _finCtrl;

  String _tipo = 'porcentaje';
  bool   _guardando = false;

  bool get _esEdicion => widget.cupon != null;

  @override
  void initState() {
    super.initState();
    final c = widget.cupon;
    _codigoCtrl = TextEditingController(text: c?.codigo ?? '');
    _valorCtrl  = TextEditingController(
        text: c != null ? c.valor.toStringAsFixed(2) : '');
    _descCtrl   = TextEditingController(text: c?.descripcion ?? '');
    _usosCtrl   = TextEditingController(
        text: c?.usosMaximos?.toString() ?? '');
    _inicioCtrl = TextEditingController(text: c?.fechaInicio ?? '');
    _finCtrl    = TextEditingController(text: c?.fechaFin ?? '');
    _tipo       = c?.tipo ?? 'porcentaje';
  }

  @override
  void dispose() {
    _codigoCtrl.dispose();
    _valorCtrl.dispose();
    _descCtrl.dispose();
    _usosCtrl.dispose();
    _inicioCtrl.dispose();
    _finCtrl.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _guardando = true);
    try {
      final valor      = double.parse(_valorCtrl.text);
      final usos       = int.tryParse(_usosCtrl.text.trim());
      final inicio     = _inicioCtrl.text.trim().isEmpty
          ? null
          : _inicioCtrl.text.trim();
      final fin        = _finCtrl.text.trim().isEmpty
          ? null
          : _finCtrl.text.trim();
      final descripcion = _descCtrl.text.trim();

      if (_esEdicion) {
        await CuponService.editar(
          widget.cupon!.id,
          descripcion: descripcion,
          valor: valor,
          tipo: _tipo,
          usosMaximos: usos,
          fechaInicio: inicio,
          fechaFin: fin,
        );
      } else {
        await CuponService.crear(
          codigo: _codigoCtrl.text.trim().toUpperCase(),
          tipo: _tipo,
          valor: valor,
          descripcion: descripcion,
          usosMaximos: usos,
          fechaInicio: inicio,
          fechaFin: fin,
        );
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error: $e',
              style: const TextStyle(color: Colors.white)),
          backgroundColor: _kRed,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(20),
      ),
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + bottomPad),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Título
              Row(children: [
                Icon(
                  _esEdicion
                      ? Icons.edit_outlined
                      : Icons.local_offer_outlined,
                  color: _kAccent,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Text(
                  _esEdicion ? 'Editar cupón' : 'Nuevo cupón',
                  style: const TextStyle(
                    color: _kText,
                    fontWeight: FontWeight.w700,
                    fontSize: 18,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: _kSub),
                  onPressed: () => Navigator.pop(context),
                ),
              ]),
              const SizedBox(height: 16),

              // Código
              if (!_esEdicion) ...[
                _Campo(
                  label: 'Código del cupón',
                  hint: 'Ej: VERANO20',
                  ctrl: _codigoCtrl,
                  caps: true,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'Campo obligatorio';
                    }
                    if (!RegExp(r'^[A-Z0-9_-]{2,20}$')
                        .hasMatch(v.trim().toUpperCase())) {
                      return 'Solo letras, números, - y _ (2-20 car.)';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),
              ],

              // Tipo + Valor
              Row(children: [
                // Tipo (segmented)
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Tipo',
                          style: TextStyle(
                              color: _kSub,
                              fontSize: 12,
                              fontWeight: FontWeight.w500)),
                      const SizedBox(height: 6),
                      Container(
                        decoration: BoxDecoration(
                          color: _kBg,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: _kBorder),
                        ),
                        child: Row(children: [
                          Expanded(
                              child: _SegBtn(
                            label: '% Porcentaje',
                            selected: _tipo == 'porcentaje',
                            onTap: () =>
                                setState(() => _tipo = 'porcentaje'),
                          )),
                          Expanded(
                              child: _SegBtn(
                            label: '€ Fijo',
                            selected: _tipo == 'fijo',
                            onTap: () => setState(() => _tipo = 'fijo'),
                          )),
                        ]),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                // Valor
                SizedBox(
                  width: 100,
                  child: _Campo(
                    label: _tipo == 'porcentaje' ? 'Valor (%)' : 'Valor (€)',
                    hint: _tipo == 'porcentaje' ? '20' : '5.00',
                    ctrl: _valorCtrl,
                    keyboard: const TextInputType.numberWithOptions(
                        decimal: true),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return 'Obligatorio';
                      }
                      final n = double.tryParse(v);
                      if (n == null || n <= 0) return 'Valor inválido';
                      if (_tipo == 'porcentaje' && n > 100) {
                        return 'Máx 100%';
                      }
                      return null;
                    },
                  ),
                ),
              ]),
              const SizedBox(height: 14),

              // Descripción
              _Campo(
                label: 'Descripción (opcional)',
                hint: 'Descuento de verano para clientes VIP',
                ctrl: _descCtrl,
                maxLines: 2,
              ),
              const SizedBox(height: 14),

              // Usos máximos
              _Campo(
                label: 'Usos máximos (vacío = ilimitado)',
                hint: '100',
                ctrl: _usosCtrl,
                keyboard: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              ),
              const SizedBox(height: 14),

              // Fechas
              Row(children: [
                Expanded(
                  child: _Campo(
                    label: 'Inicio (AAAA-MM-DD)',
                    hint: '2025-06-01',
                    ctrl: _inicioCtrl,
                    validator: _validarFecha,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _Campo(
                    label: 'Fin (AAAA-MM-DD)',
                    hint: '2025-08-31',
                    ctrl: _finCtrl,
                    validator: _validarFecha,
                  ),
                ),
              ]),
              const SizedBox(height: 22),

              // Botón guardar
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _guardando ? null : _guardar,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _kAccent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _guardando
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                      : Text(
                          _esEdicion ? 'Guardar cambios' : 'Crear cupón',
                          style: const TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 15),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String? _validarFecha(String? v) {
    if (v == null || v.trim().isEmpty) return null;
    try {
      DateTime.parse(v.trim());
      return null;
    } catch (_) {
      return 'Formato: AAAA-MM-DD';
    }
  }
}

// ─── Widgets auxiliares del formulario ───────────────────────────────────────

class _Campo extends StatelessWidget {
  final String label;
  final String? hint;
  final TextEditingController ctrl;
  final FormFieldValidator<String>? validator;
  final TextInputType? keyboard;
  final List<TextInputFormatter>? inputFormatters;
  final int maxLines;
  final bool caps;

  const _Campo({
    required this.label,
    required this.ctrl,
    this.hint,
    this.validator,
    this.keyboard,
    this.inputFormatters,
    this.maxLines = 1,
    this.caps = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                color: _kSub,
                fontSize: 12,
                fontWeight: FontWeight.w500)),
        const SizedBox(height: 6),
        TextFormField(
          controller: ctrl,
          keyboardType: keyboard,
          inputFormatters: inputFormatters,
          maxLines: maxLines,
          textCapitalization:
              caps ? TextCapitalization.characters : TextCapitalization.none,
          style: const TextStyle(color: _kText, fontSize: 14),
          validator: validator,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: _kSub, fontSize: 13),
            filled: true,
            fillColor: _kBg,
            isDense: true,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: _kBorder)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: _kBorder)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide:
                    const BorderSide(color: _kAccent, width: 1.5)),
            errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: _kRed)),
          ),
        ),
      ],
    );
  }
}

class _SegBtn extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _SegBtn(
      {required this.label,
      required this.selected,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.all(3),
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: selected ? _kAccent : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: selected ? Colors.white : _kSub,
            fontSize: 12,
            fontWeight:
                selected ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}

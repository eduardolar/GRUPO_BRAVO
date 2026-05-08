import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:frontend/core/app_snackbar.dart';
import 'package:frontend/core/colors_style.dart';
import 'package:frontend/screens/Administrador/admin_cierre_detalle_screen.dart';
import 'package:frontend/services/cierre_caja_service.dart';
import 'package:frontend/services/http_client.dart';
import 'package:intl/intl.dart';

// ── Constantes ────────────────────────────────────────────────────────────────

const _kTurnos = ['comida', 'cena'];

final _fmtFecha = DateFormat('dd/MM/yyyy');
final _fmtHora = DateFormat('HH:mm');
final _fmtEuros = NumberFormat('#,##0.00', 'es_ES');

// ── Pantalla principal ────────────────────────────────────────────────────────

class AdminCierreCajaScreen extends StatefulWidget {
  const AdminCierreCajaScreen({super.key});

  @override
  State<AdminCierreCajaScreen> createState() => _AdminCierreCajaScreenState();
}

class _AdminCierreCajaScreenState extends State<AdminCierreCajaScreen> {
  DateTime _fecha = DateTime.now();

  bool _cargando = false;
  String? _error;

  /// Mapa turno → doc cierre (null si no existe para ese turno+fecha)
  final Map<String, Map<String, dynamic>?> _cierres = {
    'comida': null,
    'cena': null,
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _cargar());
  }

  // ── Carga ─────────────────────────────────────────────────────────────────

  Future<void> _cargar() async {
    if (!mounted) return;
    setState(() {
      _cargando = true;
      _error = null;
    });

    try {
      final fechaStr = _fechaParaApi(_fecha);
      final lista = await CierreCajaService.listar(fecha: fechaStr);

      // Reiniciamos el mapa antes de rellenarlo
      final nuevo = <String, Map<String, dynamic>?>{
        'comida': null,
        'cena': null,
      };
      for (final doc in lista) {
        final turno = doc['turno'] as String?;
        if (turno != null && nuevo.containsKey(turno)) {
          nuevo[turno] = doc;
        }
      }

      if (!mounted) return;
      setState(() {
        _cierres.addAll(nuevo);
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

  // ── Selector de fecha ─────────────────────────────────────────────────────

  Future<void> _seleccionarFecha() async {
    final picked = await showDatePicker(
      context: context,
      helpText: 'SELECCIONAR FECHA',
      initialDate: _fecha,
      firstDate: DateTime(2023),
      lastDate: DateTime.now(),
      builder: (ctx, child) => _pickerTheme(ctx, child!),
    );
    if (picked == null || !mounted) return;
    setState(() => _fecha = picked);
    _cargar();
  }

  Widget _pickerTheme(BuildContext ctx, Widget child) {
    return Theme(
      data: Theme.of(ctx).copyWith(
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

  // ── Sheets ────────────────────────────────────────────────────────────────

  Future<void> _abrirSheetAbrir(String turno) async {
    final refrescar = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _SheetAbrir(turno: turno, fecha: _fechaParaApi(_fecha)),
    );
    if (refrescar == true) _cargar();
  }

  Future<void> _abrirSheetCerrar(Map<String, dynamic> cierre) async {
    final refrescar = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _SheetCerrar(cierre: cierre),
    );
    if (refrescar == true) _cargar();
  }

  Future<void> _abrirSheetReabrir(Map<String, dynamic> cierre) async {
    final refrescar = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _SheetReabrir(cierre: cierre),
    );
    if (refrescar == true) _cargar();
  }

  Future<void> _irADetalle(Map<String, dynamic> cierre) async {
    // Al volver del detalle recargamos por si el usuario reabrió desde allí
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AdminCierreDetalleScreen(cierreId: cierre['id'] as String),
      ),
    );
    _cargar();
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: _buildAppBar(),
      body: Stack(
        children: [
          // Fondo foto restaurante
          Container(
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/images/Bravo restaurante.jpg'),
                fit: BoxFit.cover,
              ),
            ),
          ),
          // Degradado oscuro
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.65),
                  Colors.black.withValues(alpha: 0.92),
                ],
              ),
            ),
          ),
          SafeArea(child: _buildBody()),
        ],
      ),
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      title: const Text(
        'CIERRE DE CAJA',
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
          fontSize: 16,
        ),
      ),
      backgroundColor: Colors.transparent,
      elevation: 0,
      centerTitle: true,
      iconTheme: const IconThemeData(color: Colors.white),
      actions: [
        Semantics(
          label: 'Refrescar cierres',
          button: true,
          child: IconButton(
            tooltip: 'Refrescar',
            onPressed: _cargando ? null : _cargar,
            icon: const Icon(Icons.refresh, color: Colors.white),
          ),
        ),
      ],
    );
  }

  Widget _buildBody() {
    return RefreshIndicator(
      color: AppColors.button,
      backgroundColor: Colors.black87,
      onRefresh: _cargar,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Selector de fecha
            _buildSelectorFecha(),
            const SizedBox(height: 20),

            // Estado: cargando
            if (_cargando)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 60),
                child: Center(
                  child: CircularProgressIndicator(color: AppColors.button),
                ),
              ),

            // Estado: error
            if (!_cargando && _error != null)
              _buildEstadoError(),

            // Estado: datos
            if (!_cargando && _error == null)
              ...(_kTurnos.map((t) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: _CardTurno(
                    turno: t,
                    cierre: _cierres[t],
                    onAbrir: () => _abrirSheetAbrir(t),
                    onCerrar: () => _abrirSheetCerrar(_cierres[t]!),
                    onVerDetalle: () => _irADetalle(_cierres[t]!),
                    onReabrir: () => _abrirSheetReabrir(_cierres[t]!),
                  ),
                );
              })),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectorFecha() {
    return Semantics(
      label: 'Fecha seleccionada: ${_fmtFecha.format(_fecha)}',
      button: true,
      child: GestureDetector(
        onTap: _seleccionarFecha,
        child: _GlassCard(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          child: Row(
            children: [
              const Icon(Icons.calendar_today, color: AppColors.button, size: 18),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'FECHA DEL TURNO',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      color: Colors.white54,
                      letterSpacing: 1.4,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _fmtFecha.format(_fecha),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              const Icon(
                Icons.arrow_drop_down,
                color: Colors.white54,
                size: 24,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEstadoError() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Center(
        child: Column(
          children: [
            const Icon(Icons.error_outline, color: AppColors.error, size: 48),
            const SizedBox(height: 12),
            const Text(
              'No se pudieron cargar los cierres',
              style: TextStyle(color: Colors.white),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              _error!,
              style: const TextStyle(color: Colors.white54, fontSize: 12),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _cargar,
              icon: const Icon(Icons.refresh),
              label: const Text('Reintentar'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.button,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Card de turno ─────────────────────────────────────────────────────────────

class _CardTurno extends StatelessWidget {
  final String turno;
  final Map<String, dynamic>? cierre;
  final VoidCallback onAbrir;
  final VoidCallback onCerrar;
  final VoidCallback onVerDetalle;
  final VoidCallback onReabrir;

  const _CardTurno({
    required this.turno,
    required this.cierre,
    required this.onAbrir,
    required this.onCerrar,
    required this.onVerDetalle,
    required this.onReabrir,
  });

  String get _labelTurno => switch (turno) {
        'comida' => 'COMIDA',
        'cena' => 'CENA',
        _ => turno.toUpperCase(),
      };

  IconData get _iconoTurno => switch (turno) {
        'comida' => Icons.restaurant_outlined,
        'cena' => Icons.nights_stay_outlined,
        _ => Icons.schedule,
      };

  String get _horasTurno => switch (turno) {
        'comida' => '05:00 - 17:00',
        'cena' => '17:00 - 05:00',
        _ => '',
      };

  @override
  Widget build(BuildContext context) {
    final estado = cierre?['estado'] as String?;

    return _GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cabecera del turno
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.button.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.button.withValues(alpha: 0.5),
                  ),
                ),
                child: Icon(_iconoTurno, color: AppColors.button, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _labelTurno,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      _horasTurno,
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              _ChipEstado(estado: estado),
            ],
          ),

          const SizedBox(height: 16),
          const Divider(color: Colors.white12, height: 1),
          const SizedBox(height: 16),

          // Contenido según estado
          if (estado == null) _buildSinAbrir(context),
          if (estado == 'abierto') _buildAbierto(context),
          if (estado == 'cerrado') _buildCerrado(context),
        ],
      ),
    );
  }

  Widget _buildSinAbrir(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'No hay cierre registrado para este turno.',
          style: TextStyle(color: Colors.white54, fontSize: 13),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: Semantics(
            label: 'Abrir turno $_labelTurno',
            button: true,
            child: ElevatedButton.icon(
              onPressed: onAbrir,
              icon: const Icon(Icons.play_arrow_rounded, size: 20),
              label: const Text(
                'ABRIR TURNO',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.button,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAbierto(BuildContext context) {
    final abiertoAt = _parseFecha(cierre?['abierto_at']);
    final abiertoStr = abiertoAt != null ? _fmtHora.format(abiertoAt) : '—';
    final abiertoBy = cierre?['abierto_por'] as String? ?? '—';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FilaDato(
          icono: Icons.access_time,
          label: 'Abierto a las',
          valor: abiertoStr,
        ),
        const SizedBox(height: 6),
        _FilaDato(
          icono: Icons.person_outline,
          label: 'Por',
          valor: abiertoBy,
        ),
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          child: Semantics(
            label: 'Cerrar turno $_labelTurno',
            button: true,
            child: ElevatedButton.icon(
              onPressed: onCerrar,
              icon: const Icon(Icons.lock_outline, size: 20),
              label: const Text(
                'CERRAR TURNO',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF8B0000), // granate oscuro
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCerrado(BuildContext context) {
    final totales = cierre?['totales'] as Map<String, dynamic>? ?? {};
    final ventasTotal = (totales['ventas_total'] as num?)?.toDouble() ?? 0.0;
    final pedidosCount = (totales['pedidos_count'] as num?)?.toInt() ?? 0;
    final efectivoDeclarado =
        (cierre?['efectivo_declarado'] as num?)?.toDouble() ?? 0.0;
    final descuadre = (cierre?['descuadre'] as num?)?.toDouble() ?? 0.0;

    // Color del descuadre según magnitud
    Color colorDescuadre;
    String textoDescuadre;
    if (descuadre == 0) {
      colorDescuadre = AppColors.disp;
      textoDescuadre = '0,00 €';
    } else if (descuadre.abs() <= 5) {
      colorDescuadre = Colors.amber;
      textoDescuadre = '${_fmtEuros.format(descuadre)} €';
    } else {
      colorDescuadre = AppColors.error;
      textoDescuadre = '${_fmtEuros.format(descuadre)} €';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Totales compactos
        Row(
          children: [
            Expanded(
              child: _MiniKpi(
                label: 'VENTAS',
                valor: '${_fmtEuros.format(ventasTotal)} €',
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _MiniKpi(
                label: 'PEDIDOS',
                valor: '$pedidosCount',
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _MiniKpi(
                label: 'EFECTIVO',
                valor: '${_fmtEuros.format(efectivoDeclarado)} €',
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _MiniKpi(
                label: 'DESCUADRE',
                valor: textoDescuadre,
                color: colorDescuadre,
              ),
            ),
          ],
        ),

        const SizedBox(height: 14),

        // Botones: VER DETALLE + REABRIR
        Row(
          children: [
            Expanded(
              child: Semantics(
                label: 'Ver detalle del turno $_labelTurno',
                button: true,
                child: ElevatedButton.icon(
                  onPressed: onVerDetalle,
                  icon: const Icon(Icons.info_outline, size: 18),
                  label: const Text(
                    'VER DETALLE',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white.withValues(alpha: 0.15),
                    foregroundColor: Colors.white,
                    minimumSize: const Size(0, 44),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                      side: const BorderSide(color: Colors.white24),
                    ),
                    elevation: 0,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Semantics(
              label: 'Reabrir turno $_labelTurno',
              button: true,
              child: OutlinedButton(
                onPressed: onReabrir,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white54,
                  minimumSize: const Size(0, 44),
                  side: const BorderSide(color: Colors.white24),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text(
                  'REABRIR',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ── Sheet: abrir turno ────────────────────────────────────────────────────────

class _SheetAbrir extends StatefulWidget {
  final String turno;
  final String fecha;

  const _SheetAbrir({required this.turno, required this.fecha});

  @override
  State<_SheetAbrir> createState() => _SheetAbrirState();
}

class _SheetAbrirState extends State<_SheetAbrir> {
  bool _enviando = false;

  String get _labelTurno => switch (widget.turno) {
        'comida' => 'Comida',
        'cena' => 'Cena',
        _ => widget.turno,
      };

  Future<void> _confirmar() async {
    setState(() => _enviando = true);
    try {
      await CierreCajaService.abrirCierre(
        turno: widget.turno,
        fecha: widget.fecha,
      );
      if (!mounted) return;
      showAppSuccess(context, 'Turno $_labelTurno abierto correctamente');
      Navigator.pop(context, true); // true = refrescar
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.statusCode == 409) {
        showAppError(context, 'Ya hay un cierre registrado para este turno');
      } else {
        handleApiError(context, e);
      }
    } catch (e) {
      if (!mounted) return;
      handleApiError(context, e);
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _BaseSheet(
      titulo: 'Abrir turno de $_labelTurno',
      icono: Icons.play_arrow_rounded,
      iconColor: AppColors.disp,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Se registrará la apertura del turno de $_labelTurno '
            'para la fecha ${widget.fecha}.',
            style: const TextStyle(color: Colors.white70, fontSize: 14),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _enviando ? null : _confirmar,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.button,
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
                  : const Text(
                      'CONFIRMAR APERTURA',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Sheet: cerrar turno ───────────────────────────────────────────────────────

class _SheetCerrar extends StatefulWidget {
  final Map<String, dynamic> cierre;

  const _SheetCerrar({required this.cierre});

  @override
  State<_SheetCerrar> createState() => _SheetCerrarState();
}

class _SheetCerrarState extends State<_SheetCerrar> {
  final _formKey = GlobalKey<FormState>();
  final _efectivoCtrl = TextEditingController();
  bool _enviando = false;

  String get _id => widget.cierre['id'] as String;

  String get _labelTurno {
    final t = widget.cierre['turno'] as String? ?? '';
    return switch (t) {
      'comida' => 'Comida',
      'cena' => 'Cena',
      _ => t,
    };
  }

  @override
  void dispose() {
    _efectivoCtrl.dispose();
    super.dispose();
  }

  Future<void> _cerrar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _enviando = true);

    final efectivo = double.tryParse(
          _efectivoCtrl.text.replaceAll(',', '.'),
        ) ??
        0.0;

    try {
      final resultado = await CierreCajaService.cerrarCierre(_id, efectivo);
      if (!mounted) return;
      // Mostramos el dialog de descuadre antes de cerrar el sheet
      await _mostrarDialogDescuadre(resultado);
      if (!mounted) return;
      Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.statusCode == 409) {
        // El backend indica cuántos pedidos pendientes hay en el mensaje
        showAppError(context, 'No puedes cerrar: ${e.message}');
        // El sheet permanece abierto para que el admin resuelva los pedidos
      } else {
        handleApiError(context, e);
      }
    } catch (e) {
      if (!mounted) return;
      handleApiError(context, e);
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  Future<void> _mostrarDialogDescuadre(Map<String, dynamic> doc) async {
    final descuadre = (doc['descuadre'] as num?)?.toDouble() ?? 0.0;

    String emoji;
    String titulo;
    Color color;

    if (descuadre == 0) {
      emoji = '✅'; // ✅
      titulo = 'Cuadre perfecto';
      color = AppColors.disp;
    } else if (descuadre > 0) {
      emoji = '⚠️'; // ⚠️
      titulo = 'Sobra ${_fmtEuros.format(descuadre)} €';
      color = Colors.amber;
    } else {
      emoji = '⛔'; // ⛔
      titulo = 'Falta ${_fmtEuros.format(descuadre.abs())} €';
      color = AppColors.error;
    }

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 28)),
            const SizedBox(width: 10),
            Text(
              titulo,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _DialogFilaDato(
              label: 'Efectivo sistema',
              valor: '${_fmtEuros.format((doc['efectivo_sistema'] as num?)?.toDouble() ?? 0)} €',
            ),
            _DialogFilaDato(
              label: 'Efectivo declarado',
              valor: '${_fmtEuros.format((doc['efectivo_declarado'] as num?)?.toDouble() ?? 0)} €',
            ),
            const SizedBox(height: 8),
            Divider(color: Colors.white24),
            _DialogFilaDato(
              label: 'Descuadre',
              valor: '${_fmtEuros.format(descuadre)} €',
              color: color,
              bold: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            style: TextButton.styleFrom(foregroundColor: Colors.white),
            child: const Text('ACEPTAR'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _BaseSheet(
      titulo: 'Cerrar turno de $_labelTurno',
      icono: Icons.lock_outline,
      iconColor: const Color(0xFF8B0000),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Introduce el efectivo contado en caja al final del turno.',
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _efectivoCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(color: Colors.white, fontSize: 18),
              decoration: InputDecoration(
                labelText: 'Efectivo contado (€)',
                labelStyle: const TextStyle(color: Colors.white54),
                prefixIcon: const Icon(Icons.euro, color: AppColors.button),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.white24),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.button),
                ),
                errorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.error),
                ),
                focusedErrorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.error),
                ),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.08),
              ),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Introduce un importe';
                final parsed = double.tryParse(v.replaceAll(',', '.'));
                if (parsed == null) return 'Número inválido';
                if (parsed < 0) return 'El importe no puede ser negativo';
                return null;
              },
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _enviando ? null : _cerrar,
                icon: _enviando
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.lock_outline, size: 20),
                label: Text(
                  _enviando ? 'CERRANDO...' : 'CERRAR TURNO',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF8B0000),
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 52),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Sheet: reabrir turno ──────────────────────────────────────────────────────

class _SheetReabrir extends StatefulWidget {
  final Map<String, dynamic> cierre;

  const _SheetReabrir({required this.cierre});

  @override
  State<_SheetReabrir> createState() => _SheetReabrirState();
}

class _SheetReabrirState extends State<_SheetReabrir> {
  final _formKey = GlobalKey<FormState>();
  final _motivoCtrl = TextEditingController();
  bool _enviando = false;

  String get _id => widget.cierre['id'] as String;

  @override
  void dispose() {
    _motivoCtrl.dispose();
    super.dispose();
  }

  Future<void> _reabrir() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _enviando = true);

    try {
      await CierreCajaService.reabrirCierre(_id, _motivoCtrl.text.trim());
      if (!mounted) return;
      showAppSuccess(context, 'Turno reabierto. Acción registrada en auditoría');
      Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (!mounted) return;
      handleApiError(context, e);
    } catch (e) {
      if (!mounted) return;
      handleApiError(context, e);
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _BaseSheet(
      titulo: 'Reabrir turno',
      icono: Icons.lock_open_outlined,
      iconColor: Colors.orange,
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Aviso de auditoría
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: Colors.amber.withValues(alpha: 0.4),
                ),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.warning_amber_rounded, color: Colors.amber, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Reabrir un cierre debe ser excepcional. '
                      'Quedará registrado en el log de auditoría.',
                      style: TextStyle(color: Colors.amber, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _motivoCtrl,
              maxLines: 4,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                labelText: 'Motivo de reapertura',
                labelStyle: const TextStyle(color: Colors.white54),
                alignLabelWithHint: true,
                hintText: 'Explica el motivo (mínimo 10 caracteres)...',
                hintStyle: const TextStyle(color: Colors.white30, fontSize: 13),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.white24),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.orange),
                ),
                errorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.error),
                ),
                focusedErrorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.error),
                ),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.08),
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'El motivo es obligatorio';
                if (v.trim().length < 10) {
                  return 'El motivo debe tener al menos 10 caracteres';
                }
                return null;
              },
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _enviando ? null : _reabrir,
                icon: _enviando
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.lock_open_outlined, size: 20),
                label: Text(
                  _enviando ? 'REABRIENDO...' : 'REABRIR TURNO',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange.shade700,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 52),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Widgets auxiliares ────────────────────────────────────────────────────────

/// Contenedor glass base que comparten las tres pantallas de cierre.
class _GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const _GlassCard({
    required this.child,
    this.padding = const EdgeInsets.all(16),
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          width: double.infinity,
          padding: padding,
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.40),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
          ),
          child: child,
        ),
      ),
    );
  }
}

/// Chip visual de estado (SIN ABRIR / ABIERTO / CERRADO).
class _ChipEstado extends StatelessWidget {
  final String? estado;

  const _ChipEstado({required this.estado});

  @override
  Widget build(BuildContext context) {
    final Color color;
    final String label;

    if (estado == 'abierto') {
      color = AppColors.disp;
      label = 'ABIERTO';
    } else if (estado == 'cerrado') {
      color = Colors.blue.shade400;
      label = 'CERRADO';
    } else {
      color = Colors.white38;
      label = 'SIN ABRIR';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.6)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

/// Fila de dato: icono + label + valor, usada en el estado "abierto".
class _FilaDato extends StatelessWidget {
  final IconData icono;
  final String label;
  final String valor;

  const _FilaDato({
    required this.icono,
    required this.label,
    required this.valor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icono, size: 14, color: Colors.white54),
        const SizedBox(width: 6),
        Text(
          '$label: ',
          style: const TextStyle(color: Colors.white54, fontSize: 13),
        ),
        Text(
          valor,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

/// Mini KPI para la card cerrada: label + valor coloreado.
class _MiniKpi extends StatelessWidget {
  final String label;
  final String valor;
  final Color color;

  const _MiniKpi({
    required this.label,
    required this.valor,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 8,
              fontWeight: FontWeight.w800,
              color: Colors.white54,
              letterSpacing: 1.0,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            valor,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: color,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

/// Sheet base con fondo glass y scroll interno para evitar desbordamiento.
class _BaseSheet extends StatelessWidget {
  final String titulo;
  final IconData icono;
  final Color iconColor;
  final Widget child;

  const _BaseSheet({
    required this.titulo,
    required this.icono,
    required this.iconColor,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF111111),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(20, 24, 20, 20 + bottom),
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
              // Cabecera
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: iconColor.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icono, color: iconColor, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      titulo,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const Divider(color: Colors.white12),
              const SizedBox(height: 16),
              child,
            ],
          ),
        ),
      ),
    );
  }
}

/// Fila de dato en el dialog de descuadre.
class _DialogFilaDato extends StatelessWidget {
  final String label;
  final String valor;
  final Color? color;
  final bool bold;

  const _DialogFilaDato({
    required this.label,
    required this.valor,
    this.color,
    this.bold = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
          Text(
            valor,
            style: TextStyle(
              color: color ?? Colors.white,
              fontSize: 13,
              fontWeight: bold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Helpers ────────────────────────────────────────────────────────────────────

String _fechaParaApi(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

DateTime? _parseFecha(dynamic raw) {
  if (raw == null) return null;
  try {
    return DateTime.parse(raw.toString()).toLocal();
  } catch (_) {
    return null;
  }
}

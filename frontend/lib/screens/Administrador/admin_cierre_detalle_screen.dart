import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:frontend/core/app_snackbar.dart';
import 'package:frontend/core/colors_style.dart';
import 'package:frontend/services/cierre_caja_service.dart';
import 'package:frontend/services/http_client.dart';
import 'package:intl/intl.dart';

// ── Formateadores locales ──────────────────────────────────────────────────────

final _fmtFechaHora = DateFormat('dd/MM/yyyy HH:mm');
final _fmtEuros = NumberFormat('#,##0.00', 'es_ES');

// ── Pantalla de detalle ───────────────────────────────────────────────────────

class AdminCierreDetalleScreen extends StatefulWidget {
  final String cierreId;

  const AdminCierreDetalleScreen({super.key, required this.cierreId});

  @override
  State<AdminCierreDetalleScreen> createState() =>
      _AdminCierreDetalleScreenState();
}

class _AdminCierreDetalleScreenState extends State<AdminCierreDetalleScreen> {
  bool _cargando = false;
  String? _error;
  Map<String, dynamic>? _cierre;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _cargar());
  }

  // ── Carga ──────────────────────────────────────────────────────────────────

  Future<void> _cargar() async {
    if (!mounted) return;
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final doc = await CierreCajaService.obtener(widget.cierreId);
      if (!mounted) return;
      setState(() {
        _cierre = doc;
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

  // ── Reabrir desde detalle ──────────────────────────────────────────────────

  Future<void> _abrirSheetReabrir() async {
    if (_cierre == null) return;
    final refrescar = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _SheetReabrirDetalle(cierre: _cierre!),
    );
    if (refrescar == true) _cargar();
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
          Container(
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/images/Bravo restaurante.jpg'),
                fit: BoxFit.cover,
              ),
            ),
          ),
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
        'DETALLE DE CIERRE',
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
          label: 'Refrescar detalle',
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
    if (_cargando) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.button),
      );
    }

    if (_error != null) {
      return _buildEstadoError();
    }

    if (_cierre == null) {
      return const Center(
        child: Text(
          'No se encontró el cierre',
          style: TextStyle(color: Colors.white54),
        ),
      );
    }

    return _buildContenido(_cierre!);
  }

  Widget _buildEstadoError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: AppColors.error, size: 48),
            const SizedBox(height: 12),
            const Text(
              'No se pudo cargar el detalle',
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

  Widget _buildContenido(Map<String, dynamic> doc) {
    final estado = doc['estado'] as String? ?? '—';
    final turno = doc['turno'] as String? ?? '—';
    final fecha = doc['fecha'] as String? ?? '—';
    final totales = doc['totales'] as Map<String, dynamic>? ?? {};
    final reaperturas = (doc['reaperturas'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>();

    final ventasTotal = (totales['ventas_total'] as num?)?.toDouble() ?? 0.0;
    final ventasEfectivo =
        (totales['ventas_efectivo'] as num?)?.toDouble() ?? 0.0;
    final ventasTarjeta =
        (totales['ventas_tarjeta'] as num?)?.toDouble() ?? 0.0;
    final ventasOtros = (totales['ventas_otros'] as num?)?.toDouble() ?? 0.0;
    final pedidosCount = (totales['pedidos_count'] as num?)?.toInt() ?? 0;
    final efectivoDeclarado =
        (doc['efectivo_declarado'] as num?)?.toDouble();
    final efectivoSistema =
        (doc['efectivo_sistema'] as num?)?.toDouble();
    final descuadre = (doc['descuadre'] as num?)?.toDouble();

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Cabecera: turno + fecha + estado ───────────────────────────
          _GlassCard(
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.button.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppColors.button.withValues(alpha: 0.5),
                    ),
                  ),
                  child: Icon(
                    _iconoTurno(turno),
                    color: AppColors.button,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _labelTurno(turno),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        fecha,
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                _ChipEstado(estado: estado),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // ── Sección: Totales de ventas ─────────────────────────────────
          _buildSeccionTitulo('TOTALES DE VENTAS'),
          const SizedBox(height: 8),
          _GlassCard(
            child: Column(
              children: [
                _buildFilaTotal(
                  icono: Icons.euro_outlined,
                  label: 'Total ventas',
                  valor: '${_fmtEuros.format(ventasTotal)} €',
                  color: Colors.white,
                  destacado: true,
                ),
                const Divider(color: Colors.white12, height: 20),
                _buildFilaTotal(
                  icono: Icons.payments_outlined,
                  label: 'Efectivo',
                  valor: '${_fmtEuros.format(ventasEfectivo)} €',
                  color: AppColors.disp,
                ),
                const SizedBox(height: 8),
                _buildFilaTotal(
                  icono: Icons.credit_card_outlined,
                  label: 'Tarjeta',
                  valor: '${_fmtEuros.format(ventasTarjeta)} €',
                  color: AppColors.info,
                ),
                const SizedBox(height: 8),
                _buildFilaTotal(
                  icono: Icons.payment_outlined,
                  label: 'Otros',
                  valor: '${_fmtEuros.format(ventasOtros)} €',
                  color: AppColors.primaryAccent,
                ),
                const Divider(color: Colors.white12, height: 20),
                _buildFilaTotal(
                  icono: Icons.receipt_long_outlined,
                  label: 'Pedidos',
                  valor: '$pedidosCount',
                  color: Colors.white,
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // ── Sección: Cuadre de caja (solo si está cerrado) ─────────────
          if (estado == 'cerrado') ...[
            _buildSeccionTitulo('CUADRE DE CAJA'),
            const SizedBox(height: 8),
            _buildCuadreCard(
              efectivoDeclarado: efectivoDeclarado,
              efectivoSistema: efectivoSistema,
              descuadre: descuadre,
            ),
            const SizedBox(height: 14),
          ],

          // ── Sección: Auditoría de apertura/cierre ─────────────────────
          _buildSeccionTitulo('AUDITORÍA'),
          const SizedBox(height: 8),
          _GlassCard(
            child: Column(
              children: [
                if (doc['abierto_por'] != null)
                  _buildFilaAuditoria(
                    icono: Icons.play_arrow_rounded,
                    label: 'Abierto por',
                    valor: doc['abierto_por'] as String? ?? '—',
                    fecha: _parseFecha(doc['abierto_at']),
                    iconColor: AppColors.disp,
                  ),
                if (doc['cerrado_por'] != null) ...[
                  const Divider(color: Colors.white12, height: 20),
                  _buildFilaAuditoria(
                    icono: Icons.lock_outline,
                    label: 'Cerrado por',
                    valor: doc['cerrado_por'] as String? ?? '—',
                    fecha: _parseFecha(doc['cerrado_at']),
                    iconColor: AppColors.info,
                  ),
                ],
              ],
            ),
          ),

          // ── Sección: Reaperturas ───────────────────────────────────────
          if (reaperturas.isNotEmpty) ...[
            const SizedBox(height: 14),
            _buildSeccionTitulo('HISTORIAL DE REAPERTURAS'),
            const SizedBox(height: 8),
            ...reaperturas.asMap().entries.map((entry) {
              final i = entry.key;
              final r = entry.value;
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _buildReoperturaCard(r, i + 1),
              );
            }),
          ],

          const SizedBox(height: 20),

          // ── Botón reabrir (solo si está cerrado) ──────────────────────
          if (estado == 'cerrado')
            SizedBox(
              width: double.infinity,
              child: Semantics(
                label: 'Reabrir este cierre de caja',
                button: true,
                child: OutlinedButton.icon(
                  onPressed: _abrirSheetReabrir,
                  icon: const Icon(Icons.lock_open_outlined, size: 18),
                  label: const Text(
                    'REABRIR TURNO',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.warningLight,
                    minimumSize: const Size(double.infinity, 52),
                    side: BorderSide(
                      color: AppColors.warningLight.withValues(alpha: 0.6),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ── Helpers de build ──────────────────────────────────────────────────────

  Widget _buildSeccionTitulo(String titulo) {
    return Row(
      children: [
        Container(width: 3, height: 14, color: AppColors.button),
        const SizedBox(width: 8),
        Text(
          titulo,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: Colors.white70,
            letterSpacing: 1.8,
          ),
        ),
      ],
    );
  }

  Widget _buildFilaTotal({
    required IconData icono,
    required String label,
    required String valor,
    required Color color,
    bool destacado = false,
  }) {
    return Row(
      children: [
        Icon(icono, size: 16, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: destacado ? Colors.white : Colors.white70,
              fontSize: destacado ? 15 : 13,
              fontWeight:
                  destacado ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
        Text(
          valor,
          style: TextStyle(
            color: color,
            fontSize: destacado ? 16 : 13,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildCuadreCard({
    required double? efectivoDeclarado,
    required double? efectivoSistema,
    required double? descuadre,
  }) {
    final desc = descuadre ?? 0.0;

    Color colorDescuadre;
    String textoDescuadre;
    String subtexto;

    if (desc == 0) {
      colorDescuadre = AppColors.disp;
      textoDescuadre = '0,00 €';
      subtexto = 'Cuadre perfecto';
    } else if (desc > 0) {
      colorDescuadre = AppColors.warning;
      textoDescuadre = '+${_fmtEuros.format(desc)} €';
      subtexto = 'Hay un sobrante en caja';
    } else {
      colorDescuadre = AppColors.error;
      textoDescuadre = '${_fmtEuros.format(desc)} €';
      subtexto = 'Hay un faltante en caja';
    }

    return _GlassCard(
      child: Column(
        children: [
          _buildFilaTotal(
            icono: Icons.computer_outlined,
            label: 'Efectivo en sistema',
            valor: efectivoSistema != null
                ? '${_fmtEuros.format(efectivoSistema)} €'
                : '—',
            color: Colors.white70,
          ),
          const SizedBox(height: 8),
          _buildFilaTotal(
            icono: Icons.payments_outlined,
            label: 'Efectivo declarado',
            valor: efectivoDeclarado != null
                ? '${_fmtEuros.format(efectivoDeclarado)} €'
                : '—',
            color: Colors.white70,
          ),
          const Divider(color: Colors.white12, height: 20),
          Row(
            children: [
              Icon(
                desc == 0
                    ? Icons.check_circle_outline
                    : desc > 0
                        ? Icons.arrow_upward
                        : Icons.arrow_downward,
                size: 16,
                color: colorDescuadre,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  subtexto,
                  style: TextStyle(
                    color: colorDescuadre,
                    fontSize: 13,
                  ),
                ),
              ),
              Text(
                textoDescuadre,
                style: TextStyle(
                  color: colorDescuadre,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilaAuditoria({
    required IconData icono,
    required String label,
    required String valor,
    required DateTime? fecha,
    required Color iconColor,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: Icon(icono, size: 16, color: iconColor),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(color: Colors.white54, fontSize: 11),
              ),
              Text(
                valor,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (fecha != null)
                Text(
                  _fmtFechaHora.format(fecha),
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 11,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildReoperturaCard(Map<String, dynamic> r, int numero) {
    final autor = r['reabierto_por'] as String? ?? '—';
    final motivo = r['motivo'] as String? ?? '—';
    final fecha = _parseFecha(r['reabierto_at']);

    return _GlassCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Número de reapertura
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.warningBg,
              shape: BoxShape.circle,
              border: Border.all(
                color: AppColors.warning.withValues(alpha: 0.5),
              ),
            ),
            child: Text(
              '$numero',
              style: const TextStyle(
                color: AppColors.warningText,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.person_outline,
                      size: 12,
                      color: Colors.white54,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      autor,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (fecha != null) ...[
                      const Spacer(),
                      Text(
                        _fmtFechaHora.format(fecha),
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  motivo,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Sheet de reabrir (reutilizado en detalle) ─────────────────────────────────

class _SheetReabrirDetalle extends StatefulWidget {
  final Map<String, dynamic> cierre;

  const _SheetReabrirDetalle({required this.cierre});

  @override
  State<_SheetReabrirDetalle> createState() => _SheetReabrirDetalleState();
}

class _SheetReabrirDetalleState extends State<_SheetReabrirDetalle> {
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
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.warningBg,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.lock_open_outlined,
                        color: AppColors.warningLight,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Reabrir turno',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(color: Colors.white12),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.warningBg,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: AppColors.warning.withValues(alpha: 0.4),
                    ),
                  ),
                  child: const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.warning_amber_rounded,
                        color: AppColors.warning,
                        size: 20,
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Reabrir un cierre debe ser excepcional. '
                          'Quedará registrado en el log de auditoría.',
                          style: TextStyle(color: AppColors.warningText, fontSize: 13),
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
                    hintStyle: const TextStyle(
                      color: Colors.white30,
                      fontSize: 13,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Colors.white24),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.warningLight),
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
                    if (v == null || v.trim().isEmpty) {
                      return 'El motivo es obligatorio';
                    }
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
                      backgroundColor: AppColors.warningText,
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
        ),
      ),
    );
  }
}

// ── Widgets auxiliares ────────────────────────────────────────────────────────

class _GlassCard extends StatelessWidget {
  final Widget child;

  const _GlassCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
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
      color = AppColors.info;
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

// ── Helpers ────────────────────────────────────────────────────────────────────

String _labelTurno(String turno) => switch (turno) {
      'desayuno' => 'Desayuno',
      'comida' => 'Comida',
      'cena' => 'Cena',
      _ => turno,
    };

IconData _iconoTurno(String turno) => switch (turno) {
      'desayuno' => Icons.wb_sunny_outlined,
      'comida' => Icons.restaurant_outlined,
      'cena' => Icons.nights_stay_outlined,
      _ => Icons.schedule,
    };

DateTime? _parseFecha(dynamic raw) {
  if (raw == null) return null;
  try {
    return DateTime.parse(raw.toString()).toLocal();
  } catch (_) {
    return null;
  }
}

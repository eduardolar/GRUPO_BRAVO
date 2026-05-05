import 'dart:math';
import 'package:flutter/material.dart';
import 'package:frontend/core/colors_style.dart';
import 'package:frontend/models/mesa_model.dart';
import 'package:frontend/providers/auth_provider.dart';
import 'package:frontend/services/mesa_service.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'crear_comanda.dart';

class SeleccionMesa extends StatefulWidget {
  const SeleccionMesa({super.key});

  @override
  State<SeleccionMesa> createState() => _SeleccionMesaState();
}

class _SeleccionMesaState extends State<SeleccionMesa> {
  List<Mesa> _mesas = [];
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargarMesas();
  }

  Future<void> _cargarMesas() async {
    final restauranteId = context.read<AuthProvider>().usuarioActual?.restauranteId;
    try {
      final mesas = await MesaService.obtenerMesas(restauranteId: restauranteId);
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

  Future<void> _mostrarFormCrearMesa() async {
    final mesa = await showGeneralDialog<Mesa>(
  context: context,
  barrierDismissible: true,
  barrierLabel: '',
  transitionDuration: const Duration(milliseconds: 260),
  pageBuilder: (_, _, _) => const SizedBox.shrink(),
  transitionBuilder: (context, animation, secondaryAnimation, child) {
    final curved = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutBack,
    );

    return FadeTransition(
      opacity: animation,
      child: ScaleTransition(
        scale: curved,
        child: const _DialogCrearMesa(),
      ),
    );
  },
);

    if (mesa == null || !mounted) return;
    try {
      final nueva = await MesaService.crearMesa(
        numero: mesa.numero,
        capacidad: mesa.capacidad,
        ubicacion: mesa.ubicacion,
        codigoQr: mesa.codigoQr,
      );
      if (!mounted) return;
      setState(() => _mesas.add(nueva));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Mesa ${nueva.numero} creada correctamente'),
          backgroundColor: AppColors.button,
          behavior: SnackBarBehavior.floating,
          shape: const RoundedRectangleBorder(),
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _confirmarMesa(Mesa mesa) async {
    final confirmado = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => _DialogConfirmacion(mesa: mesa),
    );
    if (confirmado != true || !mounted) return;

    try {
      await MesaService.marcarMesaOcupada(mesa.id);
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => CrearComanda(mesaId: mesa.id)),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error al asignar la mesa'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Map<String, List<Mesa>> _agruparPorUbicacion() {
    final Map<String, List<Mesa>> grupos = {};
    for (final mesa in _mesas) {
      grupos.putIfAbsent(mesa.ubicacion, () => []).add(mesa);
    }
    return grupos;
  }

  @override
  Widget build(BuildContext context) {
    if (_cargando) {
      return Scaffold(
        backgroundColor: AppColors.shadow,
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
                  color: AppColors.shadow.withValues(alpha: 0.65),
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
                        color: AppColors.background, strokeWidth: 1.5),
                  ),
                  SizedBox(height: 18),
                  Text(
                    'CARGANDO MESAS',
                    style: TextStyle(
                      color: AppColors.panel,
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

    final grupos = _agruparPorUbicacion();
    final orderedKeys = ['interior', 'terraza']
        .where((k) => grupos.containsKey(k))
        .toList();

    return Scaffold(
      backgroundColor: AppColors.shadow,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _mostrarFormCrearMesa,
        backgroundColor: AppColors.button,
        foregroundColor: AppColors.background,
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
                    AppColors.shadow.withValues(alpha: 0.50),
                    AppColors.shadow.withValues(alpha: 0.75),
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Cabecera ──────────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: const Icon(Icons.arrow_back_ios_new,
                            color: AppColors.background, size: 18),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'SELECCIONAR MESA',
                              style: GoogleFonts.playfairDisplay(
                                color: AppColors.background,
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.5,
                                shadows: const [
                                  Shadow(color: AppColors.shadow, blurRadius: 8),
                                ],
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Toca una mesa disponible para comenzar',
                              style: TextStyle(
                                color: AppColors.panel,
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

                const SizedBox(height: 14),

                // ── Leyenda ───────────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      _LegendaDot(
                          color: AppColors.button,
                          label: 'Disponible'),
                      const SizedBox(width: 20),
                      _LegendaDot(
                          color: AppColors.iconPrimary, label: 'Ocupada'),
                    ],
                  ),
                ),

                const SizedBox(height: 18),

                // ── Secciones por zona ────────────────────────────────────
                Expanded(
                  child: ListView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
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
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  titulo.toUpperCase(),
                                  style: const TextStyle(
                                    color: AppColors.panel,
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
                                .map((mesa) => _MesaCard(
                                      mesa: mesa,
                                      onTap: mesa.disponible
                                          ? () => _confirmarMesa(mesa)
                                          : null,
                                    ))
                                .toList(),
                          ),
                          const SizedBox(height: 20),
                          const Divider(color: AppColors.shadow, thickness: 0.5),
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
}

// ── Leyenda ──────────────────────────────────────────────────────────────────

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
            color: AppColors.panel,
            fontSize: 11,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }
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
                color: disponible
                    ? AppColors.background
                    : AppColors.iconPrimary,
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

    final tableColor =
        disponible ? AppColors.button : AppColors.iconPrimary;
    final chairColor =
        disponible ? AppColors.button : AppColors.iconPrimary;
    final borderColor =
        disponible ? AppColors.button : AppColors.iconPrimary;

    // Sombra de la mesa
    final shadowPaint = Paint()
      ..color = AppColors.shadow.withValues(alpha: 0.35)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    canvas.drawCircle(center + const Offset(2, 3), tableRadius, shadowPaint);

    // Sillas distribuidas uniformemente
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
            center: Offset(cx, cy), width: chairW * 2, height: chairH * 2),
        const Radius.circular(4),
      );
      canvas.drawRRect(rect, chairPaint);
      canvas.drawRRect(rect, chairBorderPaint);
    }

    // Mesa (círculo)
    final tablePaint = Paint()
      ..color = tableColor
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, tableRadius, tablePaint);

    // Borde de la mesa
    final tableBorderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawCircle(center, tableRadius, tableBorderPaint);

    // Número de la mesa
    final textSpan = TextSpan(
      text: '$numero',
      style: TextStyle(
        color: AppColors.background.withValues(alpha: disponible ? 1.0 : 0.6),
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

// ── Diálogo de confirmación ───────────────────────────────────────────────────

class _DialogConfirmacion extends StatelessWidget {
  final Mesa mesa;

  const _DialogConfirmacion({required this.mesa});

  String get _ubicacionLabel {
    switch (mesa.ubicacion) {
      case 'interior':
        return 'Interior';
      case 'terraza':
        return 'Terraza';
      default:
        return mesa.ubicacion;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.panel,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 84,
              height: 84,
              child: CustomPaint(
                painter: _MesaPainter(
                  numero: mesa.numero,
                  capacidad: mesa.capacidad,
                  disponible: true,
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'MESA ${mesa.numero}',
              style: GoogleFonts.playfairDisplay(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '$_ubicacionLabel · ${mesa.capacidad} personas',
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
                letterSpacing: 0.3,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.line),
              ),
              child: const Text(
                'Esta mesa quedará como ocupada y se iniciará la toma del pedido.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                  height: 1.6,
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context, false),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textSecondary,
                      side: const BorderSide(color: AppColors.line),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('CANCELAR',
                        style: TextStyle(fontSize: 11, letterSpacing: 1.2)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context, true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.button,
                      foregroundColor: AppColors.background,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('CONFIRMAR',
                        style: TextStyle(
                            fontSize: 11,
                            letterSpacing: 1.2,
                            fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Diálogo crear mesa ────────────────────────────────────────────────────────

class _DialogCrearMesa extends StatefulWidget {
  const _DialogCrearMesa();

  @override
  State<_DialogCrearMesa> createState() => _DialogCrearMesaState();
}

class _DialogCrearMesaState extends State<_DialogCrearMesa> {
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
    super.dispose();
  }

  void _autoQr() {
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
    return Dialog(
      backgroundColor: AppColors.panel,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'NUEVA MESA',
                style: GoogleFonts.playfairDisplay(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Rellena los datos para añadir la mesa',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
              ),
              const SizedBox(height: 20),

              _Campo(
                controller: _numeroCtrl,
                focusNode: _numeroFocus,
                label: 'Número de mesa',
                hint: 'Ej: 13',
                keyboardType: TextInputType.number,
                onChanged: (_) {
                   WidgetsBinding.instance.addPostFrameCallback((_) => _autoQr());
                },
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Campo obligatorio';
                  if (int.tryParse(v.trim()) == null) return 'Solo números';
                  if (int.parse(v.trim()) <= 0) return 'Debe ser mayor que 0';
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
                  if (v == null || v.trim().isEmpty) return 'Campo obligatorio';
                  if (int.tryParse(v.trim()) == null) return 'Solo números';
                  if (int.parse(v.trim()) <= 0) return 'Debe ser mayor que 0';
                  return null;
                },
              ),
              const SizedBox(height: 14),

              const Text(
                'ZONA',
                style: TextStyle(
                  color: AppColors.textSecondary,
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
                      _autoQr();
                    }),
                  ),
                  const SizedBox(width: 8),
                  _ChipUbicacion(
                    label: 'Terraza',
                    selected: _ubicacion == 'terraza',
                    onTap: () => setState(() {
                      _ubicacion = 'terraza';
                      _autoQr();
                    }),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              _Campo(
                controller: _qrCtrl,
                label: 'Código QR',
                hint: 'Ej: Mesa_13',
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Campo obligatorio';
                  return null;
                },
              ),
              const SizedBox(height: 24),

              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.textSecondary,
                        side: const BorderSide(color: AppColors.line),
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                      child: const Text('CANCELAR',
                          style: TextStyle(fontSize: 11, letterSpacing: 1.2)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _confirmar,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.button,
                        foregroundColor: AppColors.background,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                      child: const Text('CREAR',
                          style: TextStyle(
                              fontSize: 11,
                              letterSpacing: 1.2,
                              fontWeight: FontWeight.w600)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Campo de texto reutilizable ───────────────────────────────────────────────

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
            color: AppColors.textSecondary,
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
          style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(
                color: AppColors.textSecondary, fontSize: 13),
            filled: true,
            fillColor: AppColors.background,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppColors.line),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppColors.line),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide:
                  const BorderSide(color: AppColors.button, width: 1.5),
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

// ── Chip de ubicación ─────────────────────────────────────────────────────────

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
          color: selected ? AppColors.button : AppColors.background,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: selected ? AppColors.button : AppColors.line,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? AppColors.background : AppColors.textSecondary,
            fontSize: 11,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}


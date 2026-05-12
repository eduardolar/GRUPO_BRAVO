import 'dart:async';
import 'dart:convert';
import 'dart:math' show cos, sin;
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart' hide Path;
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import 'package:frontend/core/colors_style.dart';
import 'package:frontend/providers/auth_provider.dart';
import 'package:frontend/services/api_service.dart';
import 'package:frontend/services/location_service.dart';

class ConfirmarPedidoDomicilio extends StatefulWidget {
  final List<Map<String, dynamic>> items;
  final double total;

  const ConfirmarPedidoDomicilio({
    super.key,
    required this.items,
    required this.total,
  });

  @override
  State<ConfirmarPedidoDomicilio> createState() =>
      _ConfirmarPedidoDomicilioState();
}

class _ConfirmarPedidoDomicilioState extends State<ConfirmarPedidoDomicilio> {
  // ─── Mapa ──────────────────────────────────────────────────────────────────
  final MapController _mapController = MapController();
  LatLng _punto = const LatLng(41.6488, -0.8891); // Zaragoza por defecto
  String _direccionTexto = 'Cargando...';
  Timer? _debounce;

  // ─── Formulario ────────────────────────────────────────────────────────────
  final TextEditingController _nombreController = TextEditingController();
  final TextEditingController _pisoPuertaController = TextEditingController();
  final TextEditingController _direccionController = TextEditingController();
  Timer? _debounceDir;

  String _metodoPago = 'efectivo'; // 'efectivo' | 'tarjeta'
  bool _enviando = false;
  bool _animando = false;

  @override
  void dispose() {
    _debounce?.cancel();
    _debounceDir?.cancel();
    _nombreController.dispose();
    _pisoPuertaController.dispose();
    _direccionController.dispose();
    super.dispose();
  }

  // ─── Geocodificación inversa ───────────────────────────────────────────────
  Future<void> _geocodificarInverso(LatLng coords) async {
    final url = Uri.parse(
      'https://nominatim.openstreetmap.org/reverse?format=json'
      '&lat=${coords.latitude}&lon=${coords.longitude}',
    );
    try {
      final res = await http.get(url, headers: {'User-Agent': 'BravoApp'});
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        final addr = data['address'];
        if (addr != null) {
          final calle = addr['road'] ?? addr['pedestrian'] ?? addr['path'] ?? 'Calle sin nombre';
          final numero = addr['house_number'] ?? 's/n';
          final ciudad = addr['city'] ?? addr['town'] ?? addr['village'] ?? '';
          final cp = addr['postcode'] ?? '';
          if (mounted) {
            final dir = '$calle $numero, $cp $ciudad'.trim();
            setState(() => _direccionTexto = dir);
            _direccionController.text = dir;
          }
        }
      }
    } catch (_) {
      if (mounted) setState(() => _direccionTexto = 'Ubicación no disponible');
    }
  }

  void _moverMapa(LatLng destino) {
    _mapController.move(destino, 17);
    setState(() => _punto = destino);
    _geocodificarInverso(destino);
  }

  /// Geocodificación directa: texto → coordenadas → mueve el mapa
  Future<void> _geocodificarDireccion(String texto) async {
    if (texto.length < 4) return;
    final url = Uri.parse(
      'https://nominatim.openstreetmap.org/search?format=json&q=${Uri.encodeComponent(texto)}&limit=1',
    );
    try {
      final res = await http.get(url, headers: {'User-Agent': 'BravoApp'});
      if (res.statusCode == 200) {
        final lista = json.decode(res.body) as List<dynamic>;
        if (lista.isNotEmpty) {
          final item = lista.first as Map<String, dynamic>;
          final lat = double.tryParse(item['lat'].toString());
          final lon = double.tryParse(item['lon'].toString());
          if (lat != null && lon != null) {
            final coords = LatLng(lat, lon);
            _mapController.move(coords, 17);
            if (mounted) setState(() => _punto = coords);
          }
        }
      }
    } catch (_) {}
  }

  Future<void> _usarGPS() async {
    try {
      final pos = await LocationService().obtenerUbicacionActual();
      if (pos != null) _moverMapa(LatLng(pos.latitude, pos.longitude));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error GPS: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  // ─── Envío del pedido ──────────────────────────────────────────────────────
  Future<void> _confirmarPedido() async {
    final nombre = _nombreController.text.trim();
    if (nombre.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Introduce un nombre para el pedido'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }
    final dirActual = _direccionController.text.trim().isNotEmpty
        ? _direccionController.text.trim()
        : _direccionTexto;
    if (dirActual == 'Cargando...' || dirActual.contains('no disponible') || dirActual.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selecciona una dirección de entrega válida'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    setState(() => _enviando = true);
    try {
      final auth = context.read<AuthProvider>();
      final extra = _pisoPuertaController.text.trim();
      final dirBase = _direccionController.text.trim().isNotEmpty
          ? _direccionController.text.trim()
          : _direccionTexto;
      final direccionFinal = extra.isNotEmpty ? '$dirBase, $extra' : dirBase;

      await ApiService.crearPedido(
        userId: 'TRABAJADOR',
        items: widget.items,
        tipoEntrega: 'domicilio',
        metodoPago: _metodoPago,
        total: widget.total,
        direccionEntrega: direccionFinal,
        mesaId: null,
        numeroMesa: null,
        notas: nombre,
        referenciaPago: '',
        estadoPago: 'pendiente',
        restauranteId: auth.usuarioActual?.restauranteId,
        idempotencyKey: const Uuid().v4(),
        prioritario: false,
      );

      if (!mounted) return;
      _showMotoAnimacion();
    } catch (e) {
      if (!mounted) return;
      final detalle = e.toString().replaceFirst(RegExp(r'^Exception:\s*'), '');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            detalle.isEmpty ? 'Error al enviar pedido' : 'Error: $detalle',
          ),
          backgroundColor: Colors.red.shade800,
        ),
      );
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  // ─── Animación moto ────────────────────────────────────────────────────────
  void _showMotoAnimacion() {
    setState(() => _animando = true);
  }

  void _animacionCompletada() {
    setState(() => _animando = false);
    int count = 0;
    Navigator.of(context).popUntil((_) => count++ >= 2);
  }

  // ─── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: SafeArea(
        child: Column(
          children: [
            // ── AppBar manual ────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 10, 16, 0),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 18),
                  ),
                  const SizedBox(width: 4),
                  const Expanded(
                    child: Text(
                      'CONFIRMAR DOMICILIO',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 2.0,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Resumen del pedido ───────────────────────────────────
                    _SectionLabel(label: 'RESUMEN DEL PEDIDO'),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: Column(
                        children: [
                          ...widget.items.map(
                            (item) => Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Row(
                                children: [
                                  Text(
                                    '× ${item['cantidad']}',
                                    style: TextStyle(
                                      color: AppColors.button,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      item['nombre']?.toString() ?? '',
                                      style: const TextStyle(
                                        color: Colors.white70,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    '${((item['precio'] as num) * (item['cantidad'] as num)).toStringAsFixed(2).replaceAll('.', ',')} €',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const Divider(color: Colors.white12, height: 20),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'TOTAL',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.5,
                                ),
                              ),
                              Text(
                                '${widget.total.toStringAsFixed(2).replaceAll('.', ',')} €',
                                style: TextStyle(
                                  color: AppColors.button,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // ── Nombre del pedido ────────────────────────────────────
                    Row(
                      children: [
                        const _SectionLabel(label: 'NOMBRE DEL PEDIDO'),
                        const SizedBox(width: 4),
                        const Text(
                          '*',
                          style: TextStyle(
                            color: Colors.redAccent,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _nombreController,
                      style: const TextStyle(color: Colors.white),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                          RegExp(r'[a-zA-ZáéíóúÁÉÍÓÚüÜñÑ\s]'),
                        ),
                      ],
                      decoration: InputDecoration(
                        hintText: 'Introduzca su nombre(obligatorio)',
                        hintStyle: const TextStyle(color: Colors.white38),
                        prefixIcon: const Icon(Icons.person_outline, color: Colors.white38),
                        filled: true,
                        fillColor: Colors.white.withValues(alpha: 0.07),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: Colors.white12),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: Colors.white12),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: AppColors.button),
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // ── Método de pago ───────────────────────────────────────
                    const _SectionLabel(label: 'MÉTODO DE PAGO'),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: _PayMethodButton(
                            label: 'Efectivo',
                            icon: Icons.payments_outlined,
                            selected: _metodoPago == 'efectivo',
                            onTap: () => setState(() => _metodoPago = 'efectivo'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _PayMethodButton(
                            label: 'Tarjeta',
                            icon: Icons.credit_card,
                            selected: _metodoPago == 'tarjeta',
                            onTap: () => setState(() => _metodoPago = 'tarjeta'),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // ── Dirección de entrega ─────────────────────────────────
                    Row(
                      children: [
                        const _SectionLabel(label: 'DIRECCIÓN DE ENTREGA'),
                        const SizedBox(width: 4),
                        const Text(
                          '*',
                          style: TextStyle(
                            color: Colors.redAccent,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Mapa
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: SizedBox(
                        height: 480,
                        child: Stack(
                          children: [
                            FlutterMap(
                              mapController: _mapController,
                              options: MapOptions(
                                initialCenter: _punto,
                                initialZoom: 17,
                                onPositionChanged: (pos, hasGesture) {
                                  setState(() => _punto = pos.center);
                                  // Siempre actualizar: tanto arrastre manual
                                  // como movimiento programático actualizan
                                  // el campo de dirección
                                  _debounceDir?.cancel();
                                  _debounce?.cancel();
                                  _debounce = Timer(
                                    const Duration(milliseconds: 600),
                                    () => _geocodificarInverso(pos.center),
                                  );
                                },
                              ),
                              children: [
                                TileLayer(
                                  urlTemplate:
                                      'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                ),
                                MarkerLayer(
                                  markers: [
                                    Marker(
                                      point: _punto,
                                      width: 50,
                                      height: 50,
                                      child: const Icon(
                                        Icons.location_on,
                                        color: Colors.red,
                                        size: 45,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            // Botón GPS
                            Positioned(
                              bottom: 8,
                              right: 8,
                              child: FloatingActionButton.small(
                                heroTag: 'gps_domicilio',
                                backgroundColor: Colors.white,
                                onPressed: _usarGPS,
                                child: const Icon(
                                  Icons.my_location,
                                  color: Colors.black87,
                                  size: 18,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 10),

                    // Dirección detectada / editable
                    TextField(
                      controller: _direccionController,
                      style: const TextStyle(color: Colors.white70, fontSize: 13),
                      onChanged: (valor) {
                        _debounceDir?.cancel();
                        _debounceDir = Timer(
                          const Duration(milliseconds: 800),
                          () => _geocodificarDireccion(valor),
                        );
                      },
                      decoration: InputDecoration(
                        hintText: 'Escribe la dirección manualmente o ajusta el pin en el mapa (obligatorio)',
                        hintStyle: const TextStyle(color: Colors.white24, fontSize: 12),
                        prefixIcon: const Icon(Icons.map_outlined, color: Colors.white38),
                        filled: true,
                        fillColor: Colors.white.withValues(alpha: 0.05),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: Colors.white12),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: Colors.white12),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: AppColors.button),
                        ),
                      ),
                    ),

                    const SizedBox(height: 10),

                    // Piso / Puerta
                    TextField(
                      controller: _pisoPuertaController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Piso, Puerta, Bloque... (opcional)',
                        hintStyle: const TextStyle(color: Colors.white38),
                        prefixIcon: const Icon(Icons.apartment, color: Colors.white38),
                        filled: true,
                        fillColor: Colors.white.withValues(alpha: 0.07),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: Colors.white12),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: Colors.white12),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: AppColors.button),
                        ),
                      ),
                    ),

                    const SizedBox(height: 28),

                    // ── Botón confirmar ──────────────────────────────────────
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton.icon(
                        onPressed: _enviando ? null : _confirmarPedido,
                        icon: _enviando
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.delivery_dining, size: 20),
                        label: Text(
                          _enviando ? 'ENVIANDO...' : 'CONFIRMAR Y ENVIAR A COCINA',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.5,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.button,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
        ),
        if (_animando)
          Positioned.fill(
            child: _MotoOverlay(onComplete: _animacionCompletada),
          ),
      ],
    );
  }
}

// ─── Overlay animación moto ───────────────────────────────────────────────────
class _MotoOverlay extends StatefulWidget {
  final VoidCallback onComplete;
  const _MotoOverlay({required this.onComplete});

  @override
  State<_MotoOverlay> createState() => _MotoOverlayState();
}

class _MotoOverlayState extends State<_MotoOverlay>
    with TickerProviderStateMixin {
  late final AnimationController _entryCtrl;
  late final AnimationController _wheelCtrl;
  late final AnimationController _textCtrl;
  late final AnimationController _exitCtrl;
  late final Animation<double> _textOpacity;
  late final Animation<double> _textScale;

  @override
  void initState() {
    super.initState();
    _entryCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 850),
    );
    _wheelCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    )..repeat();
    _textCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );
    _exitCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 550),
    );
    _textOpacity = CurvedAnimation(parent: _textCtrl, curve: Curves.easeOut);
    _textScale = Tween<double>(begin: 0.75, end: 1.0)
        .animate(CurvedAnimation(parent: _textCtrl, curve: Curves.elasticOut));

    // Secuencia: entrada → texto → pausa → salida → callback
    _entryCtrl.addStatusListener((s) {
      if (s == AnimationStatus.completed && mounted) _textCtrl.forward();
    });
    _textCtrl.addStatusListener((s) async {
      if (s == AnimationStatus.completed && mounted) {
        await Future.delayed(const Duration(milliseconds: 750));
        if (mounted) _exitCtrl.forward();
      }
    });
    _exitCtrl.addStatusListener((s) {
      if (s == AnimationStatus.completed) widget.onComplete();
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _entryCtrl.forward();
    });
  }

  @override
  void dispose() {
    _entryCtrl.dispose();
    _wheelCtrl.dispose();
    _textCtrl.dispose();
    _exitCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.93),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedBuilder(
              animation:
                  Listenable.merge([_entryCtrl, _wheelCtrl, _exitCtrl]),
              builder: (ctx, _) {
                final sw = MediaQuery.of(ctx).size.width;
                final double x;
                if (_exitCtrl.value > 0) {
                  x = Tween<double>(begin: 0, end: sw + 120)
                      .chain(CurveTween(curve: Curves.easeInCubic))
                      .evaluate(AlwaysStoppedAnimation(_exitCtrl.value));
                } else {
                  x = Tween<double>(begin: -sw - 120, end: 0)
                      .chain(CurveTween(curve: Curves.easeOutBack))
                      .evaluate(AlwaysStoppedAnimation(_entryCtrl.value));
                }
                return Transform.translate(
                  offset: Offset(x, 0),
                  child: SizedBox(
                    width: 170,
                    height: 95,
                    child: CustomPaint(
                      painter: _MotoPainter(
                          wheelAngle: _wheelCtrl.value * 2 * pi),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 36),
            FadeTransition(
              opacity: _textOpacity,
              child: ScaleTransition(
                scale: _textScale,
                child: const Column(
                  children: [
                    Text(
                      '¡PEDIDO EN MARCHA!',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 2.0,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Enviado a cocina correctamente',
                      style: TextStyle(color: Colors.white54, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Pintor de la moto ────────────────────────────────────────────────────────
class _MotoPainter extends CustomPainter {
  final double wheelAngle;
  const _MotoPainter({required this.wheelAngle});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    const wr = 19.0;

    final rw = Offset(w * 0.22, h * 0.76);
    final fw = Offset(w * 0.78, h * 0.76);

    // Humo de escape (detrás de la moto)
    for (int i = 0; i < 4; i++) {
      canvas.drawCircle(
        Offset(rw.dx - 22 - i * 14, rw.dy - 10 - i * 6),
        (4.0 - i).clamp(1, 4),
        Paint()
          ..color =
              Colors.grey.withValues(alpha: (0.45 - i * 0.10).clamp(0, 1)),
      );
    }

    // Ruedas
    for (final center in [rw, fw]) {
      // neumático
      canvas.drawCircle(center, wr, Paint()..color = const Color(0xFF1A1A1A));
      // llanta
      canvas.drawCircle(
        center,
        wr,
        Paint()
          ..color = Colors.grey.shade600
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5,
      );
      // buje
      canvas.drawCircle(
          center, wr * 0.28, Paint()..color = Colors.grey.shade700);
      // radios
      final spoke = Paint()
        ..color = Colors.grey.shade500
        ..strokeWidth = 1.2
        ..style = PaintingStyle.stroke;
      for (int i = 0; i < 6; i++) {
        final a = wheelAngle + i * pi / 3;
        canvas.drawLine(
          center + Offset(cos(a) * wr * 0.28, sin(a) * wr * 0.28),
          center + Offset(cos(a) * wr * 0.88, sin(a) * wr * 0.88),
          spoke,
        );
      }
    }

    // Carrocería principal
    final body = Path()
      ..moveTo(w * 0.24, h * 0.60)
      ..lineTo(w * 0.36, h * 0.34)
      ..lineTo(w * 0.62, h * 0.27)
      ..lineTo(w * 0.76, h * 0.45)
      ..lineTo(w * 0.72, h * 0.60)
      ..lineTo(w * 0.28, h * 0.60)
      ..close();
    canvas.drawPath(body, Paint()..color = const Color(0xFF800020));

    // Asiento
    final seat = Path()
      ..moveTo(w * 0.37, h * 0.32)
      ..lineTo(w * 0.60, h * 0.25)
      ..lineTo(w * 0.62, h * 0.33)
      ..lineTo(w * 0.39, h * 0.39)
      ..close();
    canvas.drawPath(seat, Paint()..color = const Color(0xFF1A1A1A));

    // Bloque motor
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.37, h * 0.50, w * 0.23, h * 0.15),
        const Radius.circular(3),
      ),
      Paint()..color = const Color(0xFF2A2A2A),
    );

    // Horquilla delantera
    canvas.drawLine(
      Offset(w * 0.73, h * 0.46),
      Offset(fw.dx, fw.dy - wr),
      Paint()
        ..color = Colors.grey.shade400
        ..strokeWidth = 3
        ..style = PaintingStyle.stroke,
    );

    // Manillar
    final handle = Paint()
      ..color = Colors.grey.shade500
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
        Offset(w * 0.73, h * 0.37), Offset(w * 0.83, h * 0.27), handle);
    canvas.drawLine(
        Offset(w * 0.83, h * 0.27), Offset(w * 0.85, h * 0.40), handle);

    // Tubo de escape
    final ex = Paint()
      ..color = Colors.grey.shade600
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
        Offset(w * 0.28, h * 0.56), Offset(w * 0.12, h * 0.64), ex);
    canvas.drawLine(
        Offset(w * 0.12, h * 0.64), Offset(w * 0.04, h * 0.62), ex);

    // Faro (glow + punto)
    canvas.drawCircle(
      Offset(w * 0.82, h * 0.46),
      11,
      Paint()
        ..color = Colors.yellow.withValues(alpha: 0.18)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );
    canvas.drawCircle(
        Offset(w * 0.82, h * 0.46), 6, Paint()..color = Colors.yellow.shade100);
  }

  @override
  bool shouldRepaint(_MotoPainter old) => old.wheelAngle != wheelAngle;
}

// ─── Etiqueta de sección ──────────────────────────────────────────────────────
class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        color: Colors.white54,
        fontSize: 10,
        fontWeight: FontWeight.w700,
        letterSpacing: 2.0,
      ),
    );
  }
}

// ─── Botón de método de pago ──────────────────────────────────────────────────
class _PayMethodButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _PayMethodButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.button.withValues(alpha: 0.18)
              : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? AppColors.button : Colors.white12,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: selected ? AppColors.button : Colors.white38,
              size: 18,
            ),
            const SizedBox(width: 8),
            Text(
              label.toUpperCase(),
              style: TextStyle(
                color: selected ? Colors.white : Colors.white54,
                fontSize: 12,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

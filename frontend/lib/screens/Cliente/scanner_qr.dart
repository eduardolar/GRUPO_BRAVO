import 'package:flutter/material.dart';
import 'package:frontend/core/colors_style.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class QRScanner extends StatefulWidget {
  const QRScanner({super.key});

  @override
  State<QRScanner> createState() => _QRScannerState();
}

class _QRScannerState extends State<QRScanner> {
  bool _yaDetectado = false;

  void _procesarCodigo(String code) {
    if (_yaDetectado) return;
    setState(() => _yaDetectado = true);
    // Devuelve el código al llamador (codigo_qr.dart) para que valide con la API
    Navigator.pop(context, code);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          'ESCANEAR MESA',
          style: GoogleFonts.playfairDisplay(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.5,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            height: 1,
            color: Colors.white12,
          ),
        ),
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Cámara a pantalla completa
          MobileScanner(
            onDetect: (capture) {
              final code = capture.barcodes.first.rawValue;
              if (code != null) _procesarCodigo(code);
            },
          ),

          // Overlay oscuro en los bordes
          _ScanOverlay(),

          // Marco centrado en pantalla
          Center(
            child: Container(
              width: 240,
              height: 240,
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.button, width: 2),
              ),
              child: Stack(children: _corners()),
            ),
          ),

          // Texto e instrucción — debajo del marco
          Align(
            alignment: const Alignment(0, 0.55),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Apunta al código QR de tu mesa',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.80),
                    fontSize: 13,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 20),
                GestureDetector(
                  onTap: _introducirCodigoManual,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.white24),
                      color: Colors.black45,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.keyboard,
                            color: Colors.white54, size: 16),
                        const SizedBox(width: 8),
                        Text(
                          'INTRODUCIR CÓDIGO MANUAL',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.70),
                            fontSize: 11,
                            letterSpacing: 1.2,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _corners() {
    const size = 22.0;
    const stroke = 3.0;
    const color = Colors.white;

    return [
      // Top-left
      Positioned(
        top: 0, left: 0,
        child: _Corner(size: size, stroke: stroke, color: color,
            top: true, left: true),
      ),
      // Top-right
      Positioned(
        top: 0, right: 0,
        child: _Corner(size: size, stroke: stroke, color: color,
            top: true, left: false),
      ),
      // Bottom-left
      Positioned(
        bottom: 0, left: 0,
        child: _Corner(size: size, stroke: stroke, color: color,
            top: false, left: true),
      ),
      // Bottom-right
      Positioned(
        bottom: 0, right: 0,
        child: _Corner(size: size, stroke: stroke, color: color,
            top: false, left: false),
      ),
    ];
  }

  void _introducirCodigoManual() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (ctx) => Dialog(
        backgroundColor: AppColors.panel,
        shape: const RoundedRectangleBorder(),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'CÓDIGO DE MESA',
                style: GoogleFonts.playfairDisplay(
                  color: AppColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
              ),
              Container(
                  height: 1, color: AppColors.line,
                  margin: const EdgeInsets.symmetric(vertical: 14)),
              TextField(
                controller: controller,
                autofocus: true,
                style: const TextStyle(
                    color: AppColors.textPrimary, fontSize: 14),
                decoration: const InputDecoration(
                  hintText: 'Ej: Mesa-001',
                  hintStyle: TextStyle(color: AppColors.textSecondary),
                  border: OutlineInputBorder(borderRadius: BorderRadius.zero),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.zero,
                    borderSide: BorderSide(color: AppColors.button),
                  ),
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => Navigator.pop(ctx),
                      child: Container(
                        height: 44,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          border: Border.all(color: AppColors.line),
                        ),
                        child: const Text(
                          'CANCELAR',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 11,
                            letterSpacing: 1.2,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        final value = controller.text.trim();
                        if (value.isNotEmpty) {
                          Navigator.pop(ctx);
                          _procesarCodigo(value);
                        }
                      },
                      child: Container(
                        height: 44,
                        alignment: Alignment.center,
                        color: AppColors.button,
                        child: const Text(
                          'ACEPTAR',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            letterSpacing: 1.2,
                            fontWeight: FontWeight.w600,
                          ),
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
    );
  }
}

// ── Overlay oscuro alrededor del marco ──────────────────────────────────────

class _ScanOverlay extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _OverlayPainter(),
      child: const SizedBox.expand(),
    );
  }
}

class _OverlayPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black.withValues(alpha: 0.60);
    const frameSize = 240.0;
    // Centro geométrico de la pantalla completa — coincide con Center()
    final cx = size.width / 2;
    final cy = size.height / 2;
    final left = cx - frameSize / 2;
    final top = cy - frameSize / 2;
    final frame = Rect.fromLTWH(left, top, frameSize, frameSize);

    final full = Rect.fromLTWH(0, 0, size.width, size.height);
    final path = Path()
      ..addRect(full)
      ..addRect(frame)
      ..fillType = PathFillType.evenOdd;
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_) => false;
}

// ── Esquina decorativa ───────────────────────────────────────────────────────

class _Corner extends StatelessWidget {
  final double size;
  final double stroke;
  final Color color;
  final bool top;
  final bool left;

  const _Corner({
    required this.size,
    required this.stroke,
    required this.color,
    required this.top,
    required this.left,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _CornerPainter(
            stroke: stroke, color: color, top: top, left: left),
      ),
    );
  }
}

class _CornerPainter extends CustomPainter {
  final double stroke;
  final Color color;
  final bool top;
  final bool left;

  _CornerPainter(
      {required this.stroke,
      required this.color,
      required this.top,
      required this.left});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = stroke
      ..style = PaintingStyle.stroke;

    final path = Path();
    final w = size.width;
    final h = size.height;

    if (top && left) {
      path.moveTo(0, h);
      path.lineTo(0, 0);
      path.lineTo(w, 0);
    } else if (top && !left) {
      path.moveTo(0, 0);
      path.lineTo(w, 0);
      path.lineTo(w, h);
    } else if (!top && left) {
      path.moveTo(0, 0);
      path.lineTo(0, h);
      path.lineTo(w, h);
    } else {
      path.moveTo(0, h);
      path.lineTo(w, h);
      path.lineTo(w, 0);
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_) => false;
}

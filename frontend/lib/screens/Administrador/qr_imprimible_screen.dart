import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/app_snackbar.dart';
import '../../core/printing_helper.dart';
import '../../models/mesa_model.dart';

/// Pantalla diseñada para imprimirse: fondo blanco, QR grande y los datos de
/// la mesa. En **web** el botón "Imprimir" abre el diálogo del navegador
/// (Ctrl+P equivalente). En móvil/desktop se sugiere capturar pantalla y
/// usar la opción nativa del sistema.
class QrImprimibleScreen extends StatelessWidget {
  final Mesa mesa;
  final String? nombreRestaurante;

  const QrImprimibleScreen({
    super.key,
    required this.mesa,
    this.nombreRestaurante,
  });

  void _imprimir(BuildContext context) {
    if (puedeImprimirNativo) {
      printDocument();
    } else {
      showAppInfo(
        context,
        'En móvil: usa Compartir → Imprimir desde el menú del sistema.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      // AppBar fina y oscura, OCULTA al imprimir mediante el media-query
      // del navegador (queda fuera del area de impresión por estar arriba).
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'Imprimir QR · Mesa ${mesa.numero}',
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        actions: [
          IconButton(
            tooltip: 'Imprimir',
            icon: const Icon(Icons.print_rounded),
            onPressed: () => _imprimir(context),
          ),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: _Cartel(
              mesa: mesa,
              nombreRestaurante: nombreRestaurante,
            ),
          ),
        ),
      ),
      // FAB para que el botón de imprimir sea descubrible también con el
      // pulgar — útil sobre todo en escritorio cuando trabajas con ratón.
      floatingActionButton: puedeImprimirNativo
          ? FloatingActionButton.extended(
              onPressed: () => _imprimir(context),
              icon: const Icon(Icons.print_rounded),
              label: const Text('Imprimir'),
            )
          : null,
    );
  }
}

/// Tarjeta lista para impresión: borde fino, marca arriba, QR enorme y los
/// datos de la mesa abajo. Pensada para 1 mesa por hoja A4.
class _Cartel extends StatelessWidget {
  final Mesa mesa;
  final String? nombreRestaurante;
  const _Cartel({required this.mesa, this.nombreRestaurante});

  String get _ubicacion => switch (mesa.ubicacion) {
    'interior' => 'Interior',
    'terraza' => 'Terraza',
    _ => mesa.ubicacion,
  };

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.black, width: 1.2),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              (nombreRestaurante ?? 'RESTAURANTE BRAVO').toUpperCase(),
              textAlign: TextAlign.center,
              style: GoogleFonts.playfairDisplay(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                letterSpacing: 4,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 6),
            Container(width: 50, height: 1, color: Colors.black54),
            const SizedBox(height: 24),
            Text(
              'MESA ${mesa.numero.toString().padLeft(2, '0')}',
              style: GoogleFonts.playfairDisplay(
                fontSize: 56,
                fontWeight: FontWeight.w800,
                color: Colors.black,
                height: 1,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '$_ubicacion · ${mesa.capacidad} personas',
              style: const TextStyle(
                fontSize: 13,
                color: Colors.black54,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 28),
            // QR cuadrado de 280px: tamaño cómodo para escanear desde 30-40 cm.
            DecoratedBox(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.black12, width: 1),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: QrImageView(
                  data: mesa.codigoQr,
                  size: 280,
                  version: QrVersions.auto,
                  backgroundColor: Colors.white,
                  errorCorrectionLevel: QrErrorCorrectLevel.M,
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'Escanea para hacer tu pedido',
              style: GoogleFonts.playfairDisplay(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 4,
              ),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.black26),
              ),
              child: Text(
                mesa.codigoQr,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 11,
                  letterSpacing: 1.0,
                  color: Colors.black87,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

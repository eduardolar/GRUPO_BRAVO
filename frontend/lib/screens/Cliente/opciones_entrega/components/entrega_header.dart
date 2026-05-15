import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class EntregaHeader extends StatelessWidget {
  final String titulo;
  final VoidCallback onBack;

  const EntregaHeader({
    super.key,
    required this.titulo,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 6, 16, 0),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Volver',
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: onBack,
          ),
          Text(
            titulo,
            style: GoogleFonts.playfairDisplay(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

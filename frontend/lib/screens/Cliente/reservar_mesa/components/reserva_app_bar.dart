import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/colors_style.dart';
import '../../perfil_screen.dart';

/// Cabecera de la pantalla de reservar mesa:
/// flecha de retroceso · eyebrow · título Playfair · icono de perfil.
class ReservaAppBar extends StatelessWidget {
  const ReservaAppBar({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
          child: Row(
            children: [
              IconButton(
                tooltip: 'Volver',
                icon: const Icon(
                  Icons.arrow_back_ios_new,
                  color: Colors.white,
                  size: 20,
                ),
                onPressed: () => Navigator.pop(context),
              ),
              const Spacer(),
              IconButton(
                tooltip: 'Mi perfil',
                icon: const Icon(
                  Icons.person_outline,
                  color: Colors.white,
                  size: 24,
                ),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const PerfilScreen()),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 6),
          child: Column(
            children: [
              Text(
                'RESTAURANTE BRAVO',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.55),
                  fontSize: 10,
                  letterSpacing: 4,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Reservar mesa',
                style: GoogleFonts.playfairDisplay(
                  color: Colors.white,
                  fontSize: 30,
                  fontWeight: FontWeight.w700,
                  height: 1.05,
                ),
              ),
              const SizedBox(height: 8),
              Container(width: 28, height: 2, color: AppColors.button),
            ],
          ),
        ),
      ],
    );
  }
}

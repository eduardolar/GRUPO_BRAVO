import 'package:flutter/material.dart';
import 'package:frontend/core/colors_style.dart';
import 'package:frontend/screens/cliente/login_screen.dart';
import 'package:frontend/models/destino_login.dart';

class ReservarMesa extends StatefulWidget {
  const ReservarMesa({super.key});

  @override
  State<ReservarMesa> createState() => _ReservarMesaState();
}

class _ReservarMesaState extends State<ReservarMesa> {
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) =>
                const LoginScreen(destino: DestinoLogin.reservar),
          ),
        );
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.primary,
          border: Border.all(color: AppColors.primaryAccent),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Línea dorada izquierda — acento 10%
            Container(
              width: 3,
              height: 56,
              decoration: BoxDecoration(
                color: AppColors.bottomSheetBg,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const SizedBox(width: 16),
            // Icono
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: AppColors.primaryHover,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.primaryAccent),
              ),
              child: const Icon(
                Icons.table_bar_rounded,
                color: Colors.white,
                size: 28,
              ),
            ),
            const SizedBox(width: 16),
            // Textos
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    "Reservar mesa",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.2,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    "Reserva ya tu mesa",
                    style: TextStyle(
                      color: AppColors.textCream,
                      fontSize: 12,
                      fontWeight: FontWeight.w300,
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
            ),
            // Flecha dorada
            Icon(
              Icons.chevron_right,
              color: Colors.white.withValues(alpha: 0.7),
              size: 22,
            ),
          ],
        ),
      ),
    );
  }
}

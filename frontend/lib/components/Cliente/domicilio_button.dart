import 'package:flutter/material.dart';
import 'package:frontend/core/colors_style.dart';
import 'package:frontend/screens/cliente/login_screen.dart';

class DomicilioButton extends StatefulWidget {
  const DomicilioButton({super.key});

  @override
  State<DomicilioButton> createState() => _DomicilioButtonState();
}

class _DomicilioButtonState extends State<DomicilioButton> {
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => LoginScreen()),
        );
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.button,
          border: Border.all(color: const Color(0xFFA6405A)),
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
                color: AppColors.gold,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const SizedBox(width: 16),
            // Icono
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: AppColors.sombra,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFA6405A)),
              ),
              child: const Icon(
                Icons.motorcycle,
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
                    "Hacer pedido",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.2,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    "Pedir a domicilio",
                    style: TextStyle(
                      color: Color(0xFFEFEBE9),
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

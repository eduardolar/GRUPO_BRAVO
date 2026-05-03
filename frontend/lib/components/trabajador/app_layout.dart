import 'package:flutter/material.dart';
import 'package:frontend/core/colors_style.dart';

/// Componente AppBar mejorado para mantener consistencia
class TrabajadorAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final VoidCallback? onBackPressed;
  final List<Widget> actions;

  const TrabajadorAppBar({
    super.key,
    required this.title,
    this.onBackPressed,
    this.actions = const [],
  });

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.white),
        onPressed: onBackPressed ?? () => Navigator.pop(context),
      ),
      centerTitle: true,
      title: Text(
        title.toUpperCase(),
        style: const TextStyle(
          fontFamily: 'Playfair Display',
          color: Color(0xFFFFF8E1),
          fontSize: 16,
          fontWeight: FontWeight.w700,
          letterSpacing: 2.0,
        ),
      ),
      actions: actions,
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}

/// Layout compartido para todas las pantallas del trabajador
class TrabajadorAppLayout extends StatelessWidget {
  final String title;
  final List<Widget> actions;
  final Widget content;
  final VoidCallback? onBackPressed;

  const TrabajadorAppLayout({
    super.key,
    required this.title,
    required this.content,
    this.actions = const [],
    this.onBackPressed,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final isWeb = screenWidth > 600;

    return Scaffold(
      backgroundColor: AppColors.background,
      extendBodyBehindAppBar: true,
      appBar: TrabajadorAppBar(
        title: title,
        onBackPressed: onBackPressed,
        actions: actions,
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          children: [
            // ── HERO SECTION ──
            Stack(
              alignment: Alignment.bottomCenter,
              children: [
                SizedBox(
                  width: screenWidth,
                  height: isWeb ? screenHeight * 0.45 : screenHeight * 0.35,
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
                        stops: const [0.0, 0.5, 1.0],
                        colors: [
                          Colors.black.withValues(alpha: 0.3),
                          Colors.black.withValues(alpha: 0.6),
                          AppColors.background,
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            // ── CONTENIDO ──
            content,
          ],
        ),
      ),
    );
  }
}

/// Botón modular para menús
class MenuButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? subtitle;
  final VoidCallback onPressed;
  final bool isPrimary;

  const MenuButton({
    super.key,
    required this.icon,
    required this.label,
    this.subtitle,
    required this.onPressed,
    this.isPrimary = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Material(
        color: isPrimary ? AppColors.button : Colors.black.withValues(alpha:0.55),
        child: InkWell(
          onTap: onPressed,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 24),
            decoration: BoxDecoration(
              border: isPrimary ? null : Border.all(color: Colors.white24),
            ),
            child: Row(
              children: [
                Icon(icon, color: Colors.white, size: 24),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label.toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          letterSpacing: 1.0,
                        ),
                      ),
                      if (subtitle != null)
                        Text(
                          subtitle!,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 11,
                          ),
                        ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: Colors.white54, size: 18),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

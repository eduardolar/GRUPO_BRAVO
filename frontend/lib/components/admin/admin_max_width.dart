import 'package:flutter/material.dart';

/// Ancho máximo del contenido en las pantallas del panel admin.
///
/// En tablet/desktop el contenido se centra y se limita a este ancho para
/// no quedar pegado a los bordes (antes la lista de Usuarios se veía como
/// una columna estrecha aunque el viewport fuera 1400 px). En móvil
/// (<700 px) no aplica restricción y se aprovecha todo el ancho disponible.
const double kAdminMaxContentWidth = 1100;

/// Envuelve [child] en un [ConstrainedBox] centrado con ancho máximo
/// [kAdminMaxContentWidth]. Pensado para apilar bajo el `AppBar` en pantallas
/// del rol Administrador (Usuarios, Reservas, Cupones, Inventario, Cierre,
/// Contabilidad...) donde el contenido principal es una lista o formulario.
///
/// Uso típico:
/// ```dart
/// SafeArea(
///   child: AdminMaxWidth(child: _buildContenido()),
/// )
/// ```
class AdminMaxWidth extends StatelessWidget {
  final Widget child;
  final double maxWidth;
  final EdgeInsetsGeometry padding;

  const AdminMaxWidth({
    super.key,
    required this.child,
    this.maxWidth = kAdminMaxContentWidth,
    this.padding = EdgeInsets.zero,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

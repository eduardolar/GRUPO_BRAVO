import 'package:flutter/material.dart';
import 'package:frontend/screens/cliente/confirmar_pedido_screen.dart';
import 'package:frontend/screens/cliente/menu_screen.dart';
import 'package:frontend/screens/admin/home_screen_admin.dart';
import 'package:frontend/screens/home_screen_trabajador.dart';
import 'package:frontend/screens/super_admin/home_screen_super_admin.dart';
import 'package:frontend/screens/trabajador/login_trabajador.dart';
import 'package:frontend/screens/trabajador/Reservas/reserva_mesa_trabajador.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'screens/cliente/home_screen.dart';
import 'providers/auth_provider.dart';
import 'providers/cart_provider.dart';
import 'providers/pedido_provider.dart';

void main() {
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => CartProvider()),
        ChangeNotifierProvider(create: (_) => PedidoProvider()),
      ],
      child: MaterialApp(
        theme: ThemeData(textTheme: GoogleFonts.frederickaTheGreatTextTheme()),
        home: const HomeTrabajador(),
      ),
    );
  }
}

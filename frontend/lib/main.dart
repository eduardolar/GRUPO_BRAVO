import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:frontend/core/colors_style.dart';
import 'package:frontend/screens/Cliente/home_screen.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:frontend/providers/auth_provider.dart';
import 'package:frontend/providers/cart_provider.dart';
import 'package:frontend/screens/home_screen.dart';

void main() {
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(
        textTheme: GoogleFonts.frederickaTheGreatTextTheme(),
      ),
      home: Scaffold(
        backgroundColor: AppColors.background,
        body: HomeScreen(),
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => CartProvider()),
      ],
      child: MaterialApp(
        home: Scaffold(
          backgroundColor: AppColors.background,
          body: const HomeScreen(),
        ),
      ),
    );
  }
}

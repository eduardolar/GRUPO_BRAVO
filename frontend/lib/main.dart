import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'screens/cliente/home_screen.dart';
import 'providers/auth_provider.dart';
import 'providers/cart_provider.dart';
import 'providers/pedido_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // flutter_stripe solo funciona en Android/iOS, no en Web
  if (!kIsWeb) {
    Stripe.publishableKey = 'pk_test_51TOw8VAyHSG5POXsDtUQMKCwyJ5SUdFWc7eyNMsrIq4NsxbhX6kaZLSOZb3B1K0mncosU5pg3bWLqPP4XDFzuB4u00p4DnMegH';
    await Stripe.instance.applySettings();
  }

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
        debugShowCheckedModeBanner: false,
        locale: const Locale('es'),
        supportedLocales: const [Locale('es')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        theme: ThemeData(textTheme: GoogleFonts.frederickaTheGreatTextTheme()),
        home: const HomeScreen(),
      ),
    );
  }
}

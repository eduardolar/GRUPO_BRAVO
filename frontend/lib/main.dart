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
import 'providers/restaurante_provider.dart';
import 'providers/usuario_provider.dart';
import 'services/api_config.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final authProvider = AuthProvider();
  await authProvider.cargarSesion();

  // flutter_stripe solo funciona en Android/iOS, no en Web.
  // La clave se lee de api_config.dart y puede sobreescribirse con
  // --dart-define=STRIPE_PK=pk_live_... al compilar para producción.
  if (!kIsWeb) {
    Stripe.publishableKey = stripePublishableKey;
    await Stripe.instance.applySettings();
  }

  runApp(MainApp(authProvider: authProvider));
}

class MainApp extends StatelessWidget {
  final AuthProvider authProvider;
  const MainApp({super.key, required this.authProvider});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: authProvider),
        ChangeNotifierProvider(create: (_) => CartProvider()),
        ChangeNotifierProvider(create: (_) => PedidoProvider()),
        ChangeNotifierProvider(create: (_) => RestauranteProvider()),
        ChangeNotifierProvider(create: (_) => UsuarioProvider()),
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

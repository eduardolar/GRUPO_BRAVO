import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:provider/provider.dart';

import 'core/app_theme.dart';
import 'models/usuario_model.dart';
import 'providers/auth_provider.dart';
import 'providers/cart_provider.dart';
import 'providers/pedido_provider.dart';
import 'providers/restaurante_provider.dart';
import 'providers/usuario_provider.dart';
import 'screens/cliente/inicio_screen.dart';
import 'services/api_config.dart';
import 'services/notificaciones_service.dart';
import 'services/pedido_listo_watcher.dart';

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

  // Notificaciones locales (no FCM): se inicializan una vez al arrancar y
  // se usan después para avisar al cliente cuando su pedido está listo.
  await NotificacionesService.instance.inicializar();

  runApp(MainApp(authProvider: authProvider));
}

class MainApp extends StatefulWidget {
  final AuthProvider authProvider;
  const MainApp({super.key, required this.authProvider});

  @override
  State<MainApp> createState() => _MainAppState();
}

class _MainAppState extends State<MainApp> {
  @override
  void initState() {
    super.initState();
    widget.authProvider.addListener(_onAuthCambio);
    _onAuthCambio();
  }

  @override
  void dispose() {
    widget.authProvider.removeListener(_onAuthCambio);
    PedidoListoWatcher.instance.detener();
    super.dispose();
  }

  /// Arranca el watcher de "pedido listo" para clientes logueados; lo detiene
  /// si la sesión cambia o se cierra.
  void _onAuthCambio() {
    final usuario = widget.authProvider.usuarioActual;
    if (usuario != null && usuario.rol == RolUsuario.cliente) {
      PedidoListoWatcher.instance.iniciar(usuario.id);
    } else {
      PedidoListoWatcher.instance.detener();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: widget.authProvider),
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
        theme: AppTheme.light,
        home: const InicioScreen(),
      ),
    );
  }
}

// ============================================================================
// frontend/lib/main.dart
// ----------------------------------------------------------------------------
// Punto de entrada de la app Flutter de Grupo Bravo.
//
// Aquí ocurren cuatro cosas clave:
//   1) Se inicializa Flutter y se cargan las dependencias síncronas (Stripe,
//      notificaciones locales, sesión persistida en disco).
//   2) Se configura el árbol de Providers (estado global compartido entre
//      pantallas: sesión, carrito, pedido activo, etc.).
//   3) Se elige la pantalla inicial en función del rol del usuario logueado
//      (cliente, trabajador, cocinero, administrador, superadministrador).
//   4) Se conectan side-effects globales: cierre de sesión automático en 401,
//      watcher de "pedido listo" para clientes, contexto de auditoría.
//
// El árbol resultante en runtime es aproximadamente:
//
//     MultiProvider
//      └── MaterialApp (locale es, AppTheme.light)
//           └── _HomePorRol  ──>  pantalla según RolUsuario
// ============================================================================

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:provider/provider.dart';

import 'core/app_theme.dart';
import 'models/usuario_model.dart';
import 'providers/auth_provider.dart';
import 'providers/cart_provider.dart';
import 'providers/pedido_activo_provider.dart';
import 'providers/pedido_provider.dart';
import 'providers/restaurante_provider.dart';
import 'providers/usuario_provider.dart';
import 'screens/Administrador/admin_home_screen.dart';
import 'screens/cliente/inicio_screen.dart';
import 'screens/cocinero/home_screen_cocinero.dart';
import 'screens/home_screen_trabajador.dart';
import 'screens/super_admin/home_screen_super_admin.dart';
import 'services/actor_context.dart';
import 'services/api_config.dart';
import 'services/auth_session.dart';
import 'services/notificaciones_service.dart';
import 'services/pedido_listo_watcher.dart';

/// Función `main` de Flutter: se ejecuta antes de pintar nada en pantalla.
///
/// Es `async` porque necesitamos esperar a:
///   - cargar la sesión guardada en SharedPreferences,
///   - inicializar Stripe (sólo móvil),
///   - inicializar el plugin de notificaciones locales.
void main() async {
  // `ensureInitialized` enlaza el motor de Flutter con el código Dart.
  // Es obligatorio cuando usamos `await` antes de runApp() o cuando usamos
  // plugins de canal nativo (Stripe, notifications, path_provider...).
  WidgetsFlutterBinding.ensureInitialized();

  // AuthProvider mantiene el usuario logueado en memoria + persistencia.
  // `cargarSesion()` lee el token y el perfil de SharedPreferences (si los
  // hay) para que la app abra ya autenticada al refrescar.
  final authProvider = AuthProvider();
  await authProvider.cargarSesion();

  // Cierre de sesión automático cuando el backend devuelve 401 con sesión
  // activa. El callback solo se dispara si AuthSession.autenticado era true
  // antes de la petición, por lo que un 401 en login (sin token previo) no
  // lo activa. Así evitamos un bucle "fallo login → cerrarSesion → fallo".
  AuthSession.onUnauthorized = () => authProvider.cerrarSesion();

  // flutter_stripe solo funciona en Android/iOS, no en Web (Web usa el
  // Stripe Checkout hosted, abriendo la URL en una pestaña).
  // La clave publishable se lee de api_config.dart y puede sobreescribirse
  // con --dart-define=STRIPE_PK=pk_live_... al compilar para producción.
  if (!kIsWeb) {
    Stripe.publishableKey = stripePublishableKey;
    await Stripe.instance.applySettings();
  }

  // Notificaciones locales (no FCM): se inicializan una vez al arrancar y
  // se usan después para avisar al cliente cuando su pedido está listo.
  // Las push reales (FCM) son una mejora pendiente (ver project_push_pendiente).
  await NotificacionesService.instance.inicializar();

  runApp(MainApp(authProvider: authProvider));
}

/// Widget raíz de la aplicación. Recibe el `AuthProvider` ya cargado para
/// poder decidir la pantalla inicial sin un parpadeo de "login → home".
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
    // Nos suscribimos a cambios de sesión para sincronizar dependencias
    // (ver _onAuthCambio). Llamamos una vez manualmente para que el estado
    // inicial (usuario ya cargado de disco) también dispare la lógica.
    widget.authProvider.addListener(_onAuthCambio);
    _onAuthCambio();
  }

  @override
  void dispose() {
    // Liberar el listener evita fugas de memoria si MainApp se reconstruye.
    widget.authProvider.removeListener(_onAuthCambio);
    // El watcher del pedido tiene un Timer interno: hay que pararlo
    // explícitamente para que no siga corriendo tras cerrar la app en hot
    // restart o tras logout.
    PedidoListoWatcher.instance.detener();
    super.dispose();
  }

  /// Sincroniza estado dependiente de la sesión cuando cambia el AuthProvider:
  /// - ActorContext (para auditoría con `X-Actor` en cada petición HTTP).
  /// - Watcher de "pedido listo" (solo para clientes: hace polling al backend
  ///   y dispara una notificación local cuando su pedido pasa a "listo").
  void _onAuthCambio() {
    final usuario = widget.authProvider.usuarioActual;
    ActorContext.instance.set(usuario?.email);
    if (usuario != null && usuario.rol == RolUsuario.cliente) {
      PedidoListoWatcher.instance.iniciar(usuario.id);
    } else {
      // Trabajadores/admins no reciben notificaciones de "pedido listo".
      PedidoListoWatcher.instance.detener();
    }
  }

  @override
  Widget build(BuildContext context) {
    // MultiProvider expone los ChangeNotifier al árbol de widgets. Cualquier
    // pantalla puede leerlos con context.watch<X>() o context.read<X>().
    return MultiProvider(
      providers: [
        // .value reutiliza la instancia ya creada en main(); evita perder
        // la sesión cargada al construir el widget.
        ChangeNotifierProvider.value(value: widget.authProvider),
        // El resto se crean perezosamente la primera vez que se leen.
        ChangeNotifierProvider(create: (_) => CartProvider()),
        ChangeNotifierProvider(create: (_) => PedidoProvider()),
        ChangeNotifierProvider(create: (_) => RestauranteProvider()),
        ChangeNotifierProvider(create: (_) => UsuarioProvider()),
        // PedidoActivoProvider depende de AuthProvider para saber cuándo
        // iniciar/detener el polling. ChangeNotifierProxyProvider lo
        // reconstruye cada vez que AuthProvider notifica, lo que garantiza
        // que iniciar() / detener() se llamen en el momento correcto.
        ChangeNotifierProxyProvider<AuthProvider, PedidoActivoProvider>(
          create: (ctx) =>
              PedidoActivoProvider(ctx.read<AuthProvider>()),
          update: (_, auth, previous) =>
              previous ?? PedidoActivoProvider(auth),
        ),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        // Forzamos español en toda la app (microcopy, formatos de fecha,
        // teclado numérico con coma decimal, etc.).
        locale: const Locale('es'),
        supportedLocales: const [Locale('es')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        theme: AppTheme.light,
        home: const _HomePorRol(),
      ),
    );
  }
}

/// Decide la pantalla inicial según la sesión persistida en AuthProvider.
/// Al refrescar la app, los empleados (trabajador, cocinero, administrador,
/// superadministrador) caen directamente en su home; cliente y visitantes
/// sin sesión van a InicioScreen, que ya maneja login y redirect de Stripe.
///
/// Es un StatelessWidget porque toda la lógica se deriva de AuthProvider:
/// `context.watch` re-construye este widget cuando cambia el usuario, así
/// que un login o logout reenruta la app automáticamente sin Navigator.
class _HomePorRol extends StatelessWidget {
  const _HomePorRol();

  @override
  Widget build(BuildContext context) {
    final usuario = context.watch<AuthProvider>().usuarioActual;
    if (usuario == null) return const InicioScreen();
    switch (usuario.rol) {
      case RolUsuario.trabajador:
        return const HomeTrabajador();
      case RolUsuario.cocinero:
        return const HomeCocinero();
      case RolUsuario.administrador:
        return const MenuAdministrador();
      case RolUsuario.superadministrador:
        return const HomeScreenSuperAdmin();
      case RolUsuario.cliente:
        return const InicioScreen();
    }
  }
}

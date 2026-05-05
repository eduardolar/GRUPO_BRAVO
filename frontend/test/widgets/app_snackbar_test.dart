import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/app_snackbar.dart';
import 'package:frontend/services/http_client.dart';

/// Pequeño wrapper que captura el contexto del Scaffold para invocar los
/// helpers de snackbar tras el primer frame.
class _SnackbarHost extends StatefulWidget {
  const _SnackbarHost({required this.onContext});
  final void Function(BuildContext) onContext;

  @override
  State<_SnackbarHost> createState() => _SnackbarHostState();
}

class _SnackbarHostState extends State<_SnackbarHost> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Builder(
        builder: (ctx) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            widget.onContext(ctx);
          });
          return const SizedBox.shrink();
        },
      ),
    );
  }
}

Future<void> _pumpHostAndCall(
  WidgetTester tester,
  void Function(BuildContext) call,
) async {
  await tester.pumpWidget(MaterialApp(home: _SnackbarHost(onContext: call)));
  await tester.pump(); // dispara postFrameCallback
  await tester.pump(const Duration(milliseconds: 50)); // anima el snackbar
}

void main() {
  testWidgets('showAppError muestra el mensaje en un SnackBar', (tester) async {
    await _pumpHostAndCall(tester, (ctx) {
      showAppError(ctx, 'Algo salió mal');
    });
    expect(find.text('Algo salió mal'), findsOneWidget);
    expect(find.byType(SnackBar), findsOneWidget);
  });

  testWidgets('showAppSuccess muestra el mensaje con éxito', (tester) async {
    await _pumpHostAndCall(tester, (ctx) {
      showAppSuccess(ctx, 'Listo');
    });
    expect(find.text('Listo'), findsOneWidget);
  });

  testWidgets('handleApiError mapea ApiException a su mensaje', (tester) async {
    await _pumpHostAndCall(tester, (ctx) {
      handleApiError(ctx, const ApiException(404, 'Pedido no encontrado'));
    });
    expect(find.text('Pedido no encontrado'), findsOneWidget);
  });

  testWidgets('handleApiError con SocketException muestra "Sin conexión"', (
    tester,
  ) async {
    await _pumpHostAndCall(tester, (ctx) {
      handleApiError(ctx, Exception('SocketException: failed'));
    });
    expect(find.textContaining('Sin conexión'), findsOneWidget);
  });

  testWidgets('handleApiError añade prefijo cuando se especifica', (
    tester,
  ) async {
    await _pumpHostAndCall(tester, (ctx) {
      handleApiError(ctx, const ApiException(500, 'Caída'), prefix: 'Pedidos');
    });
    expect(find.text('Pedidos: Caída'), findsOneWidget);
  });

  testWidgets('errores genéricos caen en mensaje "inesperado"', (tester) async {
    await _pumpHostAndCall(tester, (ctx) {
      handleApiError(ctx, Object());
    });
    expect(find.textContaining('inesperado'), findsOneWidget);
  });
}

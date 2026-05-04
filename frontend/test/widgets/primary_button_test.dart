import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/components/Cliente/primary_button.dart';

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  group('PrimaryButton', () {
    testWidgets('muestra el label cuando no está en loading', (tester) async {
      await tester.pumpWidget(_wrap(const PrimaryButton(label: 'ENTRAR')));
      expect(find.text('ENTRAR'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('muestra spinner y oculta label cuando isLoading=true', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(const PrimaryButton(label: 'ENTRAR', isLoading: true)),
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('ENTRAR'), findsNothing);
    });

    testWidgets('invoca onPressed al pulsar', (tester) async {
      var clicks = 0;
      await tester.pumpWidget(
        _wrap(PrimaryButton(label: 'OK', onPressed: () => clicks++)),
      );
      await tester.tap(find.byType(ElevatedButton));
      expect(clicks, 1);
    });

    testWidgets('no invoca onPressed cuando isLoading=true', (tester) async {
      var clicks = 0;
      await tester.pumpWidget(
        _wrap(
          PrimaryButton(
            label: 'OK',
            isLoading: true,
            onPressed: () => clicks++,
          ),
        ),
      );
      await tester.tap(find.byType(ElevatedButton));
      expect(clicks, 0);
    });

    testWidgets('respeta height personalizado', (tester) async {
      await tester.pumpWidget(
        _wrap(const PrimaryButton(label: 'X', height: 80)),
      );
      final size = tester.getSize(find.byType(SizedBox).first);
      expect(size.height, 80);
    });
  });
}

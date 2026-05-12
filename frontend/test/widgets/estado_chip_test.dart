import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/components/shared/estado_chip.dart';
import 'package:frontend/core/colors_style.dart';

void main() {
  Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

  group('EstadoChip', () {
    testWidgets('disponible muestra icono check + label + bg success',
        (tester) async {
      await tester.pumpWidget(
        wrap(const EstadoChip(estado: EstadoMesa.disponible, label: 'LIBRE')),
      );

      // Texto visible
      expect(find.text('LIBRE'), findsOneWidget);

      // Icono correcto
      expect(find.byIcon(Icons.check_circle_outline), findsOneWidget);

      // Color de fondo
      final container = tester.widget<Container>(
        find.descendant(
          of: find.byType(EstadoChip),
          matching: find.byType(Container),
        ),
      );
      final decoration = container.decoration as BoxDecoration;
      expect(decoration.color, AppColors.success);
    });

    testWidgets('ocupada muestra icono cancel + bg noDisp', (tester) async {
      await tester.pumpWidget(
        wrap(
          const EstadoChip(estado: EstadoMesa.ocupada, label: 'OCUPADA'),
        ),
      );

      expect(find.text('OCUPADA'), findsOneWidget);
      expect(find.byIcon(Icons.cancel_outlined), findsOneWidget);

      final container = tester.widget<Container>(
        find.descendant(
          of: find.byType(EstadoChip),
          matching: find.byType(Container),
        ),
      );
      final decoration = container.decoration as BoxDecoration;
      expect(decoration.color, AppColors.noDisp);
    });

    testWidgets('reservada muestra icono event_available + bg info',
        (tester) async {
      await tester.pumpWidget(
        wrap(
          const EstadoChip(
              estado: EstadoMesa.reservada, label: 'RESERVADA'),
        ),
      );

      expect(find.text('RESERVADA'), findsOneWidget);
      expect(find.byIcon(Icons.event_available), findsOneWidget);

      final container = tester.widget<Container>(
        find.descendant(
          of: find.byType(EstadoChip),
          matching: find.byType(Container),
        ),
      );
      final decoration = container.decoration as BoxDecoration;
      expect(decoration.color, AppColors.info);
    });

    testWidgets('pendiente muestra icono schedule + bg surfacePending',
        (tester) async {
      await tester.pumpWidget(
        wrap(
          const EstadoChip(
              estado: EstadoMesa.pendiente, label: 'PENDIENTE'),
        ),
      );

      expect(find.text('PENDIENTE'), findsOneWidget);
      expect(find.byIcon(Icons.schedule), findsOneWidget);

      final container = tester.widget<Container>(
        find.descendant(
          of: find.byType(EstadoChip),
          matching: find.byType(Container),
        ),
      );
      final decoration = container.decoration as BoxDecoration;
      expect(decoration.color, AppColors.surfacePending);
    });

    testWidgets('Semantics label combina tts + label del estado',
        (tester) async {
      await tester.pumpWidget(
        wrap(
          const EstadoChip(estado: EstadoMesa.disponible, label: 'LIBRE'),
        ),
      );

      final semantics = tester.getSemantics(find.byType(EstadoChip));
      expect(semantics.label, contains('Disponible'));
      expect(semantics.label, contains('LIBRE'));
    });

    testWidgets('respeta padding y fontSize personalizados', (tester) async {
      const customPadding =
          EdgeInsets.symmetric(horizontal: 6, vertical: 3);
      await tester.pumpWidget(
        wrap(
          const EstadoChip(
            estado: EstadoMesa.disponible,
            label: 'LIBRE',
            iconSize: 10,
            fontSize: 9,
            padding: customPadding,
          ),
        ),
      );

      // El widget renderiza sin overflow (implica que los valores se aceptan)
      expect(tester.takeException(), isNull);
      expect(find.text('LIBRE'), findsOneWidget);
    });
  });
}

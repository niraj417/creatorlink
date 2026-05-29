import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:creatorlink/shared/widgets/glowy_card.dart';

void main() {
  group('GlowyCard Widget Tests', () {
    testWidgets('GlowyCard renders child widget correctly', (WidgetTester tester) async {
      const childText = 'Test Inner Content';

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: GlowyCard(
              child: Text(childText),
            ),
          ),
        ),
      );

      // Verify that the child text is rendered inside the card
      expect(find.text(childText), findsOneWidget);
    });

    testWidgets('GlowyCard triggers onTap callback when clicked', (WidgetTester tester) async {
      bool tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GlowyCard(
              onTap: () {
                tapped = true;
              },
              child: const Text('Tap Me'),
            ),
          ),
        ),
      );

      // Tap the card
      await tester.tap(find.text('Tap Me'));
      await tester.pump();

      // Verify the callback was triggered
      expect(tapped, isTrue);
    });
  });
}

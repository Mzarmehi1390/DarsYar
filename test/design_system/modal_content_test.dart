import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dars_yar/design_system/modal_content.dart';

void main() {
  group('DarsYarModalSheetContent', () {
    testWidgets('reserves presenter system inset below fixed sheet actions',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(
              viewPadding: EdgeInsets.only(bottom: 28),
              systemGestureInsets: EdgeInsets.only(bottom: 24),
              padding: EdgeInsets.only(bottom: 28),
            ),
            child: const Scaffold(
              body: DarsYarModalSheetContent(
                bottomInset: 28,
                child: Column(
                  children: [
                    Expanded(child: Text('scrollable content')),
                    Text('fixed actions'),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

      final padding = tester.widget<Padding>(
        find.ancestor(
          of: find.text('fixed actions'),
          matching: find.byType(Padding),
        ).first,
      );
      expect(padding.padding, const EdgeInsets.only(bottom: 68));
      expect(find.text('fixed actions'), findsOneWidget);
    });

    testWidgets('preserves large Android navigation insets without capping',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: DarsYarModalSheetContent(
            bottomInset: 80,
            bottomRadiusCompensation: 28,
            child: Text('fixed actions'),
          ),
        ),
      );

      final padding = tester.widget<Padding>(
        find.ancestor(
          of: find.text('fixed actions'),
          matching: find.byType(Padding),
        ).first,
      );
      expect(padding.padding, const EdgeInsets.only(bottom: 120));
    });

    testWidgets('keeps minimum clearance when system inset is unavailable',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: DarsYarModalSheetContent(
            child: Text('actions'),
          ),
        ),
      );

      final padding = tester.widget<Padding>(
        find.ancestor(
          of: find.text('actions'),
          matching: find.byType(Padding),
        ).first,
      );
      expect(padding.padding, const EdgeInsets.only(bottom: 24));
    });
  });
}

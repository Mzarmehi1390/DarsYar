import 'package:dars_yar/design_system/glass_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shared glass choice chip preserves label and tap behavior',
      (tester) async {
    var taps = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: DarsYarGlassChoiceChip(
              label: 'شنبه',
              semanticLabel: 'انتخاب شنبه',
              selected: true,
              selectedColor: Colors.blue.withValues(alpha: 0.16),
              labelStyle: const TextStyle(fontWeight: FontWeight.w700),
              onTap: () => taps++,
            ),
          ),
        ),
      ),
    );

    expect(find.text('شنبه'), findsOneWidget);
    expect(find.bySemanticsLabel('انتخاب شنبه'), findsOneWidget);
    await tester.tap(find.text('شنبه'));
    expect(taps, 1);
    expect(tester.takeException(), isNull);
  });
  testWidgets('shared circular choice preserves selection semantics and tap',
      (tester) async {
    var taps = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: DarsYarGlassCircularChoice(
              label: 'ش',
              semanticLabel: 'شنبه',
              selected: true,
              onTap: () => taps++,
            ),
          ),
        ),
      ),
    );

    expect(find.text('ش'), findsOneWidget);
    expect(find.bySemanticsLabel('شنبه'), findsOneWidget);
    await tester.tap(find.text('ش'));
    expect(taps, 1);
    expect(tester.takeException(), isNull);
  });

}

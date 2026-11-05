import 'package:dars_yar/design_system/input_focus_behavior.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('selects untouched initial value when input receives focus',
      (tester) async {
    final controller = TextEditingController(text: '0');
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DarsYarInputFocusBehavior(
            controller: controller,
            child: TextField(controller: controller),
          ),
        ),
      ),
    );

    await tester.tap(find.byType(TextField));
    await tester.pump();

    expect(controller.selection, const TextSelection(baseOffset: 0, extentOffset: 1));
  });

  testWidgets('does not select a value that the user has already changed',
      (tester) async {
    final controller = TextEditingController(text: '25');
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DarsYarInputFocusBehavior(
            controller: controller,
            child: TextField(controller: controller),
          ),
        ),
      ),
    );

    await tester.tap(find.byType(TextField));
    await tester.pump();

    expect(controller.selection, isNot(const TextSelection(baseOffset: 0, extentOffset: 2)));
  });
}

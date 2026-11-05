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

    expect(
      controller.selection,
      const TextSelection(baseOffset: 0, extentOffset: 1),
    );

    await tester.enterText(find.byType(TextField), '7');
    expect(controller.text, '7');
  });

  testWidgets('does not select a non-zero initial value', (tester) async {
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

    expect(
      controller.selection,
      isNot(const TextSelection(baseOffset: 0, extentOffset: 2)),
    );
  });

  testWidgets('does not reselect zero after the user changes it back',
      (tester) async {
    final controller = TextEditingController(text: '0');
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              DarsYarInputFocusBehavior(
                controller: controller,
                child: TextField(controller: controller),
              ),
              const Text('outside'),
            ],
          ),
        ),
      ),
    );

    await tester.tap(find.byType(TextField));
    await tester.pump();
    expect(
      controller.selection,
      const TextSelection(baseOffset: 0, extentOffset: 1),
    );

    await tester.enterText(find.byType(TextField), '7');
    controller.text = '0';
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump();

    await tester.tap(find.byType(TextField));
    await tester.pump();

    expect(
      controller.selection,
      isNot(const TextSelection(baseOffset: 0, extentOffset: 1)),
    );
  });
}

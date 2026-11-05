import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dars_yar/design_system/glass_button.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

void main() {
  testWidgets('shared glass button forwards tap and visual hierarchy',
      (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: DarsYarGlassButton(
              width: 160,
              height: 48,
              radius: 16,
              style: GlassButtonStyle.prominent,
              onTap: () => taps++,
              child: const Text('ادامه'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('ادامه'));
    expect(taps, 1);
    expect(tester.takeException(), isNull);
  });
}

  testWidgets('shared glass icon button forwards tap and semantics',
      (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: DarsYarGlassIconButton(
              icon: const Icon(Icons.edit),
              onPressed: () => taps++,
              semanticLabel: 'ویرایش',
            ),
          ),
        ),
      ),
    );

    expect(find.bySemanticsLabel('ویرایش'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('ویرایش'));
    expect(taps, 1);
    expect(tester.takeException(), isNull);
  });
}

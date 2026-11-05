import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import 'package:dars_yar/design_system/glass_dialog.dart';

void main() {
  testWidgets('glass dialog animates above the keyboard inset',
      (tester) async {
    var keyboardVisible = false;
    late StateSetter updateMedia;

    await tester.pumpWidget(
      StatefulBuilder(
        builder: (context, setState) {
          updateMedia = setState;
          return MediaQuery(
            data: MediaQueryData(
              size: const Size(400, 800),
              viewInsets: EdgeInsets.only(
                bottom: keyboardVisible ? 260 : 0,
              ),
            ),
            child: MaterialApp(
              home: Scaffold(
                body: Center(
                  child: ElevatedButton(
                    onPressed: () => showDarsYarGlassDialog<void>(
                      context: context,
                      title: 'آزمایش',
                      actions: [
                        GlassDialogAction(
                          label: 'بستن',
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ],
                    ),
                    child: const Text('باز کردن'),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );

    await tester.tap(find.text('باز کردن'));
    await tester.pumpAndSettle();

    AnimatedPadding dialogPadding() => tester.widget<AnimatedPadding>(
          find.descendant(
            of: find.byType(GlassDialog),
            matching: find.byType(AnimatedPadding),
          ).first,
        );

    expect(dialogPadding().padding, EdgeInsets.zero);

    updateMedia(() => keyboardVisible = true);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(
      dialogPadding().padding,
      const EdgeInsets.only(bottom: 260),
    );
    expect(tester.takeException(), isNull);
  });
}

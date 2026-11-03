import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dars_yar/design_system/darsyar_theme.dart';
import 'package:dars_yar/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'exam question navigator keeps the final question above the glass dock',
    (tester) async {
      SharedPreferences.setMockInitialValues({
        'darsyar.exams': jsonEncode([
          {
            'id': 'long-exam',
            'name': 'آزمون طولانی',
            'questionCount': 40,
            'durationSeconds': 3600,
            'answers': <String, int>{},
            'answerKey': <String, int>{},
            'marked': <int>[],
          },
        ]),
        'darsyar.activeExamId': 'long-exam',
      });

      tester.view.physicalSize = const Size(390, 780);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(const DarsYarApp(initialTab: 2));
      await tester.pumpAndSettle();
      await tester.tap(find.text('آزمون‌های من'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('شروع آزمون'));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.format_list_numbered_rounded));
      await tester.pumpAndSettle();
      expect(
        tester.takeException(),
        isNull,
        reason: 'The split exam layout must not overflow when the navigator opens.',
      );

      final navigatorFinder = find.byKey(
        const PageStorageKey<String>('exam-question-navigator'),
      );
      final navigator = tester.widget<ListView>(navigatorFinder);
      expect(
        navigator.padding,
        const EdgeInsets.fromLTRB(
          8,
          8,
          8,
          DarsYarTokens.pageBottomClearance,
        ),
      );

      final lastQuestionFinder = find.text('سؤال 40');
      await tester.scrollUntilVisible(
        lastQuestionFinder,
        240,
        scrollable: find.descendant(
          of: navigatorFinder,
          matching: find.byType(Scrollable),
        ),
      );
      await tester.ensureVisible(lastQuestionFinder);
      await tester.pumpAndSettle();

      final lastQuestionRect = tester.getRect(lastQuestionFinder);
      final navigatorRect = tester.getRect(navigatorFinder);
      expect(lastQuestionRect.bottom, lessThanOrEqualTo(navigatorRect.bottom));
      expect(
        tester.takeException(),
        isNull,
        reason: 'The final question must remain reachable without layout overflow.',
      );
    },
  );
}

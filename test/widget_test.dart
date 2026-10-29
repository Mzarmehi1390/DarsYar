import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dars_yar/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('DarsYar dashboard opens', (WidgetTester tester) async {
    await tester.pumpWidget(const DarsYarApp());
    await tester.pumpAndSettle();

    expect(find.text('درس‌یار'), findsOneWidget);
    expect(find.text('برنامه‌ریزی'), findsOneWidget);
    expect(find.text('پاسخ‌برگ'), findsOneWidget);

    await tester.tap(find.text('برنامه‌ریزی').last);
    await tester.pumpAndSettle();
    expect(find.text('نمای کلی هفته'), findsOneWidget);
    expect(find.text('جلسه جدید'), findsOneWidget);
  });
  testWidgets('study tasks can be created and edited', (WidgetTester tester) async {
    await tester.pumpWidget(const DarsYarApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('برنامه‌ریزی').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('وظیفه').last);
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextField, 'عنوان وظیفه'), 'مرور ریاضی');
    await tester.enterText(find.widgetWithText(TextField, 'درس'), 'ریاضی');
    await tester.tap(find.text('افزودن').last);
    await tester.pumpAndSettle();

    expect(find.text('مرور ریاضی'), findsOneWidget);
    await tester.tap(find.byTooltip('ویرایش وظیفه').first);
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextField, 'عنوان وظیفه'), 'تمرین ریاضی');
    await tester.tap(find.text('ذخیره').last);
    await tester.pumpAndSettle();

    expect(find.text('تمرین ریاضی'), findsOneWidget);
    expect(find.text('مرور ریاضی'), findsNothing);
  });

}
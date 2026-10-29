import 'dart:convert';
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
    await tester.pumpWidget(const DarsYarApp(initialTab: 1));
    await tester.pumpAndSettle();
    expect(find.text('نمای کلی هفته'), findsOneWidget);

    final plannerList = find.byType(ListView).first;

    // ListView builds children lazily, so scroll until the target has been
    // built before trying to locate/tap it.
    Future<void> revealByScrolling(Finder target) async {
      for (var attempt = 0; attempt < 8 && target.evaluate().isEmpty; attempt++) {
        await tester.drag(plannerList, const Offset(0, -420));
        await tester.pumpAndSettle();
      }
      expect(target, findsWidgets);
      await tester.ensureVisible(target.last);
      await tester.pumpAndSettle();
    }

    final addTaskButton = find.text('وظیفه');
    await revealByScrolling(addTaskButton);
    await tester.tap(addTaskButton.last);
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextField, 'عنوان وظیفه'), 'مرور ریاضی');
    await tester.enterText(find.widgetWithText(TextField, 'درس'), 'ریاضی');
    await tester.tap(find.text('افزودن').last);
    await tester.pumpAndSettle();

    final createdTask = find.text('مرور ریاضی');
    await revealByScrolling(createdTask);
    expect(createdTask, findsOneWidget);
    await tester.tap(find.byTooltip('ویرایش وظیفه').first);
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextField, 'عنوان وظیفه'), 'تمرین ریاضی');
    await tester.tap(find.text('ذخیره').last);
    await tester.pumpAndSettle();

    expect(find.text('تمرین ریاضی'), findsOneWidget);
    expect(find.text('مرور ریاضی'), findsNothing);
  });
  testWidgets('corrupt task storage does not block saved exam sheets', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({
      'darsyar.tasks': '{broken json',
      'darsyar.exams': jsonEncode([
        {
          'id': 'saved-exam',
          'name': 'آزمون ذخیره‌شده',
          'questionCount': 10,
          'answers': {'1': 2},
          'answerKey': {'1': 2},
          'marked': [3],
        },
      ]),
      'darsyar.activeExamId': 'saved-exam',
    });

    await tester.pumpWidget(const DarsYarApp(initialTab: 2));
    await tester.pumpAndSettle();

    expect(find.text('آزمون ذخیره‌شده'), findsWidgets);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('theme selection is saved and restored', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({
      'darsyar.themeMode': 'dark',
    });

    await tester.pumpWidget(const DarsYarApp(initialTab: 4));
    await tester.pumpAndSettle();

    final initialApp = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(initialApp.themeMode, ThemeMode.dark);

    await tester.tap(find.text('روشن'));
    await tester.pumpAndSettle();

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('darsyar.themeMode'), 'light');
    final updatedApp = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(updatedApp.themeMode, ThemeMode.light);
  });

  testWidgets('cancelling task deletion keeps the task', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({
      'darsyar.tasks': jsonEncode([
        {'id': 'task-1', 'title': 'مرور علوم', 'subject': 'علوم', 'done': false},
      ]),
    });

    await tester.pumpWidget(const DarsYarApp(initialTab: 0));
    await tester.pumpAndSettle();

    final taskTitle = find.text('مرور علوم');
    expect(taskTitle, findsOneWidget);
    await tester.tap(find.byTooltip('حذف').first);
    await tester.pumpAndSettle();

    expect(find.text('حذف وظیفه'), findsOneWidget);
    await tester.tap(find.text('انصراف').last);
    await tester.pumpAndSettle();

    expect(find.text('مرور علوم'), findsOneWidget);
    final prefs = await SharedPreferences.getInstance();
    final savedTasks = jsonDecode(prefs.getString('darsyar.tasks')!) as List;
    expect(savedTasks, hasLength(1));
    expect(savedTasks.single['title'], 'مرور علوم');
  });


}

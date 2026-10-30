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
    await tester.scrollUntilVisible(find.text('جلسه جدید'), 250, scrollable: find.byType(Scrollable).first);
    expect(find.text('جلسه جدید'), findsOneWidget);
  });

  testWidgets('new exam setup starts a one-question-at-a-time answer flow', (WidgetTester tester) async {
    await tester.pumpWidget(const DarsYarApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('پاسخ‌برگ'));
    await tester.pumpAndSettle();

    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'آزمون آزمایشی');
    await tester.enterText(fields.at(1), '3');
    await tester.drag(find.byType(ListView).first, const Offset(0, -320));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('ساخت پاسخ‌برگ و شروع آزمون'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ساخت پاسخ‌برگ و شروع آزمون'));
    await tester.pump();

    expect(find.text('آزمون آزمایشی'), findsOneWidget);
    expect(find.text('سؤال 1 از 3'), findsOneWidget);
    await tester.tap(find.text('گزینه 2'));
    await tester.pump();
    expect(find.text('سؤال 2 از 3'), findsOneWidget);
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

    final addTaskButton = find.text('ثبت وظیفه');
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

    await tester.tap(find.text('آزمون‌های من'));
    await tester.pumpAndSettle();
    expect(find.text('آزمون ذخیره‌شده'), findsWidgets);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });


  testWidgets('corrupt current exam storage does not restore stale legacy answers', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({
      'darsyar.exams': '{broken json',
      'darsyar.count': 3,
      'darsyar.answers': jsonEncode({'1': 2}),
      'darsyar.answerKey': jsonEncode({'1': 2}),
    });

    await tester.pumpWidget(const DarsYarApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('پاسخ‌برگ'));
    await tester.pumpAndSettle();

    // A malformed current-format key must fall back to a clean default sheet,
    // not resurrect answers from the retired single-sheet storage keys.
    expect(find.text('پاسخ‌برگ آزمون'), findsOneWidget);
    await tester.tap(find.text('آزمون‌های من'));
    await tester.pumpAndSettle();
    expect(find.text('آزمون اول'), findsWidgets);
    expect(find.text('20 سؤال • 30:00 • 0 پاسخ'), findsOneWidget);
  });

  testWidgets('theme selection is saved and restored', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({
      'darsyar.themeMode': 'dark',
    });

    await tester.pumpWidget(const DarsYarApp(initialTab: 3));
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


  testWidgets('deleting an exam also removes its linked results', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({
      'darsyar.exams': jsonEncode([
        {
          'id': 'default',
          'name': 'آزمون باقی‌مانده',
          'questionCount': 20,
          'durationSeconds': 1800,
          'answers': {},
          'answerKey': {},
          'marked': [],
        },
        {
          'id': 'exam-to-delete',
          'name': 'آزمون حذف‌شدنی',
          'questionCount': 3,
          'durationSeconds': 1800,
          'isCompleted': true,
          'answers': {'1': 0},
          'answerKey': {'1': 0},
          'marked': [],
        },
      ]),
      'darsyar.activeExamId': 'default',
      'darsyar.results': jsonEncode([
        {
          'id': 'result-to-delete',
          'examId': 'exam-to-delete',
          'examName': 'آزمون حذف‌شدنی',
          'completedAt': '2026-10-30T10:00:00.000Z',
          'questionCount': 3,
          'correct': 1,
          'wrong': 0,
          'unanswered': 2,
          'keyedQuestions': 1,
          'percentage': 100.0,
          'negativeMarking': false,
          'answers': {'1': 0},
          'answerKey': {'1': 0},
        },
      ]),
    });

    await tester.pumpWidget(const DarsYarApp(initialTab: 2));
    await tester.pumpAndSettle();
    await tester.tap(find.text('آزمون‌های من'));
    await tester.pumpAndSettle();

    final examCard = find.ancestor(
      of: find.text('آزمون حذف‌شدنی').first,
      matching: find.byType(Card),
    ).first;
    await tester.tap(find.descendant(
      of: examCard,
      matching: find.byType(PopupMenuButton<String>),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('حذف آزمون'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('حذف').last);
    await tester.pumpAndSettle();

    final prefs = await SharedPreferences.getInstance();
    final savedExams = jsonDecode(prefs.getString('darsyar.exams')!) as List;
    final savedResults = jsonDecode(prefs.getString('darsyar.results')!) as List;
    expect(savedExams.map((item) => item['id']), ['default']);
    expect(savedResults, isEmpty);
    expect(find.text('آزمون حذف‌شدنی'), findsNothing);
  });


  testWidgets('planner initially selects and reveals the current weekday', (WidgetTester tester) async {
    await tester.pumpWidget(const DarsYarApp(initialTab: 1));
    await tester.pumpAndSettle();

    const weekDays = ['یکشنبه', 'دوشنبه', 'سه‌شنبه', 'چهارشنبه', 'پنجشنبه', 'جمعه', 'شنبه'];
    final today = DateTime.now().weekday % 7;
    final todayChip = find.widgetWithText(ChoiceChip, weekDays[today]);

    expect(todayChip, findsOneWidget);
    expect(tester.widget<ChoiceChip>(todayChip).selected, isTrue);
    expect(find.text(weekDays[today]), findsWidgets);
  });



}

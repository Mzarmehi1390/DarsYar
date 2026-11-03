import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:dars_yar/backup_codec.dart';
import 'package:dars_yar/design_system/darsyar_theme.dart';
import 'package:dars_yar/design_system/glass_surface.dart';
import 'package:dars_yar/design_system/modal_content.dart';

import 'package:dars_yar/main.dart';
import 'package:dars_yar/models/study_task.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('glass overlay themes leave the native glass surface unobstructed', () {
    for (final theme in [DarsYarTheme.light, DarsYarTheme.dark]) {
      expect(theme.dialogTheme.backgroundColor, Colors.transparent);
      expect(theme.bottomSheetTheme.backgroundColor, Colors.transparent);
      expect(theme.bottomSheetTheme.modalBackgroundColor, Colors.transparent);
      expect(theme.bottomSheetTheme.surfaceTintColor, Colors.transparent);
    }
  });

  testWidgets('modal content restores Persian RTL and removes inherited underline decoration', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: DarsYarTheme.light,
        home: const DarsYarModalContent(
          child: Text('جلسه مطالعه'),
        ),
      ),
    );

    final directionality = tester.widget<Directionality>(
      find.descendant(
        of: find.byType(DarsYarModalContent),
        matching: find.byType(Directionality),
      ),
    );
    final textStyle = DefaultTextStyle.of(tester.element(find.text('جلسه مطالعه'))).style;

    expect(directionality.textDirection, TextDirection.rtl);
    expect(textStyle.decoration, TextDecoration.none);
    expect(tester.takeException(), isNull);
  });

  test('study task model round-trips without changing persisted fields', () {
    final task = StudyTask('task-1', 'مرور فصل دوم', 'ریاضی', done: true);
    final restored = StudyTask.fromJson(task.toJson());

    expect(restored.id, 'task-1');
    expect(restored.title, 'مرور فصل دوم');
    expect(restored.subject, 'ریاضی');
    expect(restored.done, isTrue);
    expect(task.toJson().keys, containsAll(['id', 'title', 'subject', 'done']));
  });

  testWidgets('DarsYar dashboard opens', (WidgetTester tester) async {
    await tester.pumpWidget(const DarsYarApp());
    await tester.pumpAndSettle();

    expect(find.text('درس‌یار'), findsOneWidget);
    expect(find.widgetWithText(GlassButton, 'برنامه‌ریزی درسی'), findsOneWidget);
    expect(find.widgetWithText(GlassButton, 'پاسخ‌برگ آزمون'), findsOneWidget);

    await tester.tap(find.text('برنامه‌ریزی').last);
    await tester.pumpAndSettle();
    expect(find.text('نمای کلی هفته'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('جلسه جدید'), 250, scrollable: find.byType(Scrollable).first);
    expect(find.text('جلسه جدید'), findsOneWidget);
  });

  testWidgets('app shell uses iOS 27 shader glass navigation and focal surfaces', (WidgetTester tester) async {
    await tester.pumpWidget(const DarsYarApp());
    await tester.pumpAndSettle();

    expect(find.byType(GlassScaffold), findsOneWidget);
    expect(find.byType(GlassTabBar), findsOneWidget);
    expect(find.byType(GlassContainer), findsWidgets);
    expect(find.byType(LinearProgressIndicator), findsWidgets);
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.byType(FilledButton), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('dashboard glass quick actions fit a compact phone width', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const DarsYarApp());
    await tester.pumpAndSettle();

    expect(find.text('برنامه‌ریزی'), findsOneWidget);
    expect(find.text('پاسخ‌برگ'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('planner keeps its final controls clear of the floating glass dock', (WidgetTester tester) async {
    await tester.pumpWidget(const DarsYarApp(initialTab: 1));
    await tester.pumpAndSettle();

    final planner = tester.widget<ListView>(
      find.byKey(const PageStorageKey<String>('planner-scroll')),
    );
    expect(
      planner.padding,
      EdgeInsets.fromLTRB(20, 22, 20, DarsYarTokens.pageBottomClearance),
    );
    expect(DarsYarTokens.pageBottomClearance, 152);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shared content surfaces use a unified layered fill', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: DarsYarTheme.light,
        home: const Scaffold(
          body: DarsYarContentSurface(child: Text('خوانایی محتوا')),
        ),
      ),
    );

    final surface = tester.widget<Container>(
      find.descendant(
        of: find.byType(DarsYarContentSurface),
        matching: find.byType(Container),
      ).first,
    );
    expect(surface.decoration, isA<BoxDecoration>());
    expect((surface.decoration! as BoxDecoration).gradient, isA<LinearGradient>());
    expect(find.text('خوانایی محتوا'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('primary destinations use the shared Persian page header', (WidgetTester tester) async {
    for (final destination in const [
      (tab: 0, title: 'درس‌یار'),
      (tab: 1, title: 'برنامه‌ریزی درسی'),
      (tab: 2, title: 'پاسخ‌برگ آزمون'),
      (tab: 3, title: 'تنظیمات'),
    ]) {
      await tester.pumpWidget(DarsYarApp(initialTab: destination.tab));
      await tester.pumpAndSettle();
      expect(find.text(destination.title), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('tap feedback is disabled and card elevation stays fixed', (WidgetTester tester) async {
    await tester.pumpWidget(const DarsYarApp());
    await tester.pumpAndSettle();

    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    for (final theme in [app.theme!, app.darkTheme!]) {
      expect(theme.splashFactory, NoSplash.splashFactory);
      expect(theme.splashColor, Colors.transparent);
      expect(theme.highlightColor, Colors.transparent);
      expect(theme.hoverColor, Colors.transparent);
      expect(theme.cardTheme.elevation, 0);
    }
  });

  testWidgets('exam setup answer-key editor adapts to a compact screen', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(320, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const DarsYarApp(initialTab: 2));
    await tester.pumpAndSettle();

    final keyButton = find.text('ورود کلید');
    await tester.ensureVisible(keyButton);
    await tester.pumpAndSettle();
    await tester.tap(keyButton);
    await tester.pumpAndSettle();

    expect(find.text('کلید پاسخ آزمون'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test('both themes provide consistent Liquid Glass modal surfaces', () {
    for (final theme in [DarsYarTheme.light, DarsYarTheme.dark]) {
      expect(theme.dialogTheme.backgroundColor, isNotNull);
      expect(theme.dialogTheme.surfaceTintColor, Colors.transparent);
      expect(theme.dialogTheme.elevation, greaterThan(0));
      expect(theme.dialogTheme.shape, isA<RoundedRectangleBorder>());
      expect(theme.popupMenuTheme.shape, isA<RoundedRectangleBorder>());
      expect(theme.bottomSheetTheme.showDragHandle, isTrue);
      expect(theme.timePickerTheme.dialHandColor, theme.colorScheme.primary);
      expect(theme.datePickerTheme.surfaceTintColor, Colors.transparent);
    }
  });

  testWidgets('bottom navigation exposes selected destination semantics', (WidgetTester tester) async {
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(const DarsYarApp());
    await tester.pumpAndSettle();

    final home = find.bySemanticsLabel('خانه');
    expect(home, findsOneWidget);
    expect(
      tester.getSemantics(home),
      isSemantics(
        label: 'خانه',
        isButton: true,
        hasSelectedState: true,
        isSelected: true,
        hasTapAction: true,
      ),
    );

    await tester.tap(find.text('برنامه‌ریزی').last);
    await tester.pumpAndSettle();

    expect(
      tester.getSemantics(home),
      isSemantics(hasSelectedState: true, isSelected: false),
    );
    final planner = find.bySemanticsLabel('برنامه‌ریزی');
    expect(planner, findsOneWidget);
    expect(
      tester.getSemantics(planner),
      isSemantics(
        label: 'برنامه‌ریزی',
        isButton: true,
        hasSelectedState: true,
        isSelected: true,
        hasTapAction: true,
      ),
    );
    semantics.dispose();
  });

  testWidgets('page and bottom navigation transitions stay lightweight', (WidgetTester tester) async {
    await tester.pumpWidget(const DarsYarApp());
    await tester.pumpAndSettle();
    expect(find.byType(AnimatedSwitcher), findsWidgets);
    await tester.tap(find.text('برنامه‌ریزی').last);
    await tester.pump(const Duration(milliseconds: 80));
    expect(find.byType(AnimatedSwitcher), findsWidgets);
    await tester.pumpAndSettle();
    expect(find.text('نمای کلی هفته'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('exam duration uses a compact editor instead of a wheel picker', (WidgetTester tester) async {
    await tester.pumpWidget(const DarsYarApp(initialTab: 2));
    await tester.pumpAndSettle();

    expect(find.text('زمان دلخواه آزمون'), findsOneWidget);
    expect(find.text('00:30:00'), findsOneWidget);
    expect(find.byWidgetPredicate((widget) => widget.runtimeType.toString() == 'CupertinoTimerPicker'), findsNothing);

    await tester.tap(find.text('تغییر زمان'));
    await tester.pumpAndSettle();
    expect(find.text('تنظیم زمان آزمون'), findsOneWidget);
    expect(find.text('90 دقیقه'), findsOneWidget);

    await tester.enterText(find.byType(GlassTextField).at(3), '45');
    final saveDurationButton = find.text('ذخیره زمان');
    await tester.ensureVisible(saveDurationButton);
    await tester.pumpAndSettle();
    await tester.tap(saveDurationButton);
    await tester.pumpAndSettle();

    expect(find.text('00:45:00'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('exam duration dialog fits a compact phone viewport', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const DarsYarApp(initialTab: 2));
    await tester.pumpAndSettle();
    final changeDurationButton = find.text('تغییر زمان');
    await tester.ensureVisible(changeDurationButton);
    await tester.pumpAndSettle();
    await tester.tap(changeDurationButton);
    await tester.pumpAndSettle();

    expect(find.text('تنظیم زمان آزمون'), findsOneWidget);
    expect(find.byType(GlassTextField), findsNWidgets(5));
    expect(tester.takeException(), isNull);
  });

  testWidgets('new exam setup starts a one-question-at-a-time answer flow', (WidgetTester tester) async {
    await tester.pumpWidget(const DarsYarApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('پاسخ‌برگ'));
    await tester.pumpAndSettle();

    final fields = find.byType(GlassTextField);
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
    expect(
      tester.widget<GlassIconButton>(find.widgetWithIcon(GlassIconButton, Icons.arrow_forward)).semanticLabel,
      'بازگشت به پاسخ‌برگ',
    );
    expect(
      tester.widget<GlassIconButton>(find.widgetWithIcon(GlassIconButton, Icons.pause)).semanticLabel,
      'توقف زمان‌سنج',
    );
    final questionNavigatorButton = find.widgetWithIcon(
      GlassIconButton,
      Icons.format_list_numbered_rounded,
    );
    await tester.tap(questionNavigatorButton);
    await tester.pumpAndSettle();

    final questionNavigator = tester.widget<ListView>(
      find.byKey(const PageStorageKey<String>('exam-question-navigator')),
    );
    expect(
      questionNavigator.padding,
      EdgeInsets.fromLTRB(8, 8, 8, DarsYarTokens.pageBottomClearance),
    );
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('گزینه 2'));
    await tester.pump();
    expect(find.text('سؤال 2 از 3'), findsOneWidget);
  });

  testWidgets('study tasks can be created and edited', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({'darsyar.tasks': 42});
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

    await tester.enterText(find.byType(GlassTextField).at(0), 'مرور ریاضی');
    await tester.enterText(find.byType(GlassTextField).at(1), 'ریاضی');
    await tester.tap(find.text('افزودن').last);
    await tester.pumpAndSettle();

    final prefsAfterCreate = await SharedPreferences.getInstance();
    final savedTasksAfterCreate = jsonDecode(prefsAfterCreate.getString('darsyar.tasks')!) as List;
    expect(savedTasksAfterCreate.single['title'], 'مرور ریاضی');

    final createdTask = find.text('مرور ریاضی');
    await revealByScrolling(createdTask);
    expect(createdTask, findsOneWidget);
    await tester.tap(find.bySemanticsLabel('ویرایش وظیفه').first);
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(GlassTextField).at(0), 'تمرین ریاضی');
    await tester.tap(find.text('ذخیره').last);
    await tester.pumpAndSettle();

    expect(find.text('تمرین ریاضی'), findsOneWidget);
    expect(find.text('مرور ریاضی'), findsNothing);
    final prefsAfterEdit = await SharedPreferences.getInstance();
    final savedTasksAfterEdit = jsonDecode(prefsAfterEdit.getString('darsyar.tasks')!) as List;
    expect(savedTasksAfterEdit.single['title'], 'تمرین ریاضی');
  });
  testWidgets('task editor remains usable on a compact phone viewport', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const DarsYarApp(initialTab: 1));
    await tester.pumpAndSettle();

    final addTask = find.text('ثبت وظیفه');
    await tester.scrollUntilVisible(
      addTask,
      220,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(addTask);
    await tester.pumpAndSettle();

    expect(find.text('وظیفه جدید'), findsOneWidget);
    expect(find.byType(GlassTextField), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('saving a task leaves unrelated exam storage untouched', (WidgetTester tester) async {
    final storedExam = jsonEncode([
      {
        'id': 'future-exam',
        'name': 'آزمون آینده',
        'questionCount': 10,
        'answers': <String, int>{},
        'answerKey': <String, int>{},
        'marked': <int>[],
        'futureMetadata': {'version': 2},
      },
    ]);
    SharedPreferences.setMockInitialValues({
      'darsyar.exams': storedExam,
      'darsyar.activeExamId': 'future-exam',
    });

    await tester.pumpWidget(const DarsYarApp(initialTab: 1));
    await tester.pumpAndSettle();

    final plannerList = find.byType(ListView).first;
    final addTaskButton = find.text('ثبت وظیفه');
    for (var attempt = 0; attempt < 8 && addTaskButton.evaluate().isEmpty; attempt++) {
      await tester.drag(plannerList, const Offset(0, -420));
      await tester.pumpAndSettle();
    }
    await tester.ensureVisible(addTaskButton.last);
    await tester.pumpAndSettle();
    await tester.tap(addTaskButton.last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(GlassTextField).at(0), 'ذخیره مستقل');
    await tester.enterText(find.byType(GlassTextField).at(1), 'علوم');
    await tester.tap(find.text('افزودن').last);
    await tester.pumpAndSettle();

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('darsyar.exams'), storedExam);
    expect(tester.takeException(), isNull);
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
    expect(find.textContaining('20 سؤال'), findsOneWidget);
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
      matching: find.byType(GlassPullDownButton),
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


  testWidgets('planner day glass chips expose one selected day', (WidgetTester tester) async {
    await tester.pumpWidget(const DarsYarApp(initialTab: 1));
    await tester.pumpAndSettle();

    final chips = tester.widgetList<GlassChip>(find.byType(GlassChip)).toList();
    expect(chips, hasLength(7));
    expect(chips.where((chip) => chip.selected), hasLength(1));
    expect(chips.every((chip) => chip.onTap != null), isTrue);
  });

  testWidgets('my exams results are laid out in the same scrollable page', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({
      'darsyar.exams': jsonEncode([
        {
          'id': 'layout-exam',
          'name': 'آزمون چیدمان',
          'questionCount': 10,
          'durationSeconds': 1800,
          'answers': {'1': 0},
          'answerKey': {'1': 0},
          'marked': [],
        },
      ]),
      'darsyar.activeExamId': 'layout-exam',
      'darsyar.results': jsonEncode([
        {
          'id': 'layout-result',
          'examId': 'layout-exam',
          'examName': 'نتیجه قابل مشاهده',
          'completedAt': '2026-10-30T10:00:00.000Z',
          'questionCount': 10,
          'correct': 8,
          'wrong': 1,
          'unanswered': 1,
          'keyedQuestions': 10,
          'percentage': 75.0,
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

    expect(find.text('آزمون چیدمان'), findsOneWidget);
    expect(find.text('نتیجه قابل مشاهده'), findsOneWidget);
    expect(find.text('75%'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('planner week selection uses a subtle indicator instead of a checkmark', (WidgetTester tester) async {
    await tester.pumpWidget(const DarsYarApp(initialTab: 1));
    await tester.pumpAndSettle();

    final selectedIndicator = find.byKey(
      const ValueKey<String>('planner-week-selected-indicator'),
    );
    expect(selectedIndicator, findsOneWidget);
    await tester.ensureVisible(selectedIndicator);
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byKey(const ValueKey<String>('planner-week-selected-indicator')),
        matching: find.byIcon(Icons.check_circle_rounded),
      ),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('planner initially selects and reveals the current weekday', (WidgetTester tester) async {
    await tester.pumpWidget(const DarsYarApp(initialTab: 1));
    await tester.pumpAndSettle();

    const weekDays = ['یکشنبه', 'دوشنبه', 'سه‌شنبه', 'چهارشنبه', 'پنجشنبه', 'جمعه', 'شنبه'];
    final today = DateTime.now().weekday % 7;
    final todayChip = find.widgetWithText(GlassChip, weekDays[today]);

    expect(todayChip, findsOneWidget);
    expect(tester.widget<GlassChip>(todayChip).selected, isTrue);
    expect(find.text(weekDays[today]), findsWidgets);
  });


  testWidgets('changing an exam answer key recalculates all linked results', (WidgetTester tester) async {
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
          'id': 'linked-exam',
          'name': 'آزمون کلید',
          'questionCount': 1,
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
          'id': 'linked-result',
          'examId': 'linked-exam',
          'examName': 'آزمون کلید',
          'completedAt': '2026-10-30T10:00:00.000Z',
          'questionCount': 1,
          'correct': 1,
          'wrong': 0,
          'unanswered': 0,
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
      of: find.text('آزمون کلید').first,
      matching: find.byType(Card),
    ).first;
    await tester.tap(find.descendant(
      of: examCard,
      matching: find.byType(GlassPullDownButton),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ویرایش کلید پاسخ'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ب').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('ذخیره کلید').last);
    await tester.pumpAndSettle();

    final prefs = await SharedPreferences.getInstance();
    final savedExams = jsonDecode(prefs.getString('darsyar.exams')!) as List;
    final savedResults = jsonDecode(prefs.getString('darsyar.results')!) as List;
    final exam = savedExams.firstWhere((item) => item['id'] == 'linked-exam');
    final result = savedResults.single;
    expect(exam['answerKey'], {'1': 1});
    expect(result['answerKey'], {'1': 1});
    expect(result['correct'], 0);
    expect(result['wrong'], 1);
    expect(result['percentage'], 0.0);
  });




  testWidgets('starting an exam persists the active exam selection', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({
      'darsyar.exams': jsonEncode([
        {
          'id': 'default',
          'name': 'آزمون پیش‌فرض',
          'questionCount': 2,
          'durationSeconds': 1800,
          'answers': <String, int>{},
          'answerKey': <String, int>{},
          'marked': <int>[],
        },
        {
          'id': 'selected-exam',
          'name': 'آزمون انتخاب‌شده',
          'questionCount': 2,
          'durationSeconds': 1800,
          'answers': <String, int>{},
          'answerKey': <String, int>{},
          'marked': <int>[],
        },
      ]),
      'darsyar.activeExamId': 7,
    });

    await tester.pumpWidget(const DarsYarApp(initialTab: 2));
    await tester.pumpAndSettle();
    await tester.tap(find.text('آزمون‌های من'));
    await tester.pumpAndSettle();

    final examCard = find.ancestor(
      of: find.text('آزمون انتخاب‌شده').first,
      matching: find.byType(Card),
    ).first;
    await tester.tap(find.descendant(
      of: examCard,
      matching: find.text('شروع آزمون'),
    ));
    await tester.pumpAndSettle();

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('darsyar.activeExamId'), 'selected-exam');
    expect(tester.takeException(), isNull);
  });

  testWidgets('active exam answer selection persists and remains visible when revisiting a question', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({
      'darsyar.exams': jsonEncode([
        {
          'id': 'answer-selection-exam',
          'name': 'آزمون انتخاب پاسخ',
          'questionCount': 3,
          'durationSeconds': 1800,
          'answers': <String, int>{},
          'answerKey': <String, int>{},
          'marked': <int>[],
        },
      ]),
      'darsyar.activeExamId': 'answer-selection-exam',
    });

    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const DarsYarApp(initialTab: 2));
    await tester.pumpAndSettle();
    await tester.tap(find.text('آزمون‌های من'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('شروع آزمون'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('گزینه 3'));
    await tester.pumpAndSettle();

    final prefs = await SharedPreferences.getInstance();
    var savedExams = jsonDecode(prefs.getString('darsyar.exams')!) as List;
    expect((savedExams.single['answers'] as Map)['1'], 2);
    expect(find.text('سؤال 2'), findsWidgets);

    await tester.tap(find.text('قبلی'));
    await tester.pumpAndSettle();
    final selectedOption = tester.widget<GlassChip>(
      find.widgetWithText(GlassChip, 'گزینه 3'),
    );
    expect(selectedOption.selected, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('finishing an exam persists completion and its result together', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({
      'darsyar.exams': jsonEncode([
        {
          'id': 'exam-to-finish',
          'name': 'آزمون پایان‌یافته',
          'questionCount': 1,
          'durationSeconds': 1800,
          'isCompleted': false,
          'answers': <String, int>{},
          'answerKey': {'1': 0},
          'marked': <int>[],
        },
      ]),
      'darsyar.activeExamId': 'exam-to-finish',
    });

    await tester.pumpWidget(const DarsYarApp(initialTab: 2));
    await tester.pumpAndSettle();
    await tester.tap(find.text('آزمون‌های من'));
    await tester.pumpAndSettle();

    final examCard = find.ancestor(
      of: find.text('آزمون پایان‌یافته').first,
      matching: find.byType(Card),
    ).first;
    await tester.tap(find.descendant(
      of: examCard,
      matching: find.text('شروع آزمون'),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('گزینه 1'));
    await tester.pumpAndSettle();
    final finishButton = find.text('پایان آزمون').last;
    await tester.ensureVisible(finishButton);
    await tester.pumpAndSettle();
    await tester.tap(finishButton);
    await tester.pumpAndSettle();
    await tester.tap(find.text('پایان').last);
    await tester.pumpAndSettle();

    final prefs = await SharedPreferences.getInstance();
    final savedExams = jsonDecode(prefs.getString('darsyar.exams')!) as List;
    final savedResults = jsonDecode(prefs.getString('darsyar.results')!) as List;
    expect(savedExams.single['isCompleted'], isTrue);
    expect(savedResults, hasLength(1));
    expect(savedResults.single['examId'], 'exam-to-finish');
    expect(tester.takeException(), isNull);
  });


  testWidgets('wrong preference value types do not block valid app startup', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({
      'darsyar.tasks': 42,
      'darsyar.studySessions': true,
      'darsyar.results': <String>['invalid'],
      'darsyar.exams': false,
      'darsyar.activeExamId': 7,
      // Stale legacy values must not be restored when a current-format key
      // exists but contains a value of the wrong type.
      'darsyar.answers': jsonEncode({'1': 2}),
      'darsyar.answerKey': jsonEncode({'1': 2}),
      'darsyar.count': '3',
    });

    await tester.pumpWidget(const DarsYarApp(initialTab: 2));
    await tester.pumpAndSettle();

    expect(find.byType(CircularProgressIndicator), findsNothing);
    await tester.tap(find.text('آزمون‌های من'));
    await tester.pumpAndSettle();
    expect(find.text('آزمون اول'), findsWidgets);
    expect(find.textContaining('20 سؤال'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });


  testWidgets('restoring a backup persists every data section and active exam', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({
      'darsyar.tasks': jsonEncode([
        {'id': 'old-task', 'title': 'وظیفه قبلی', 'subject': 'فارسی', 'done': false},
      ]),
    });

    final backup = DarsYarBackupCodec.encode(
      DarsYarBackupCodec.createPayload(
        exportedAt: '2026-10-30T16:00:00.000Z',
        activeExamId: 'restored-exam',
        tasks: [
          {'id': 'restored-task', 'title': 'وظیفه بازیابی‌شده', 'subject': 'ریاضی', 'done': true},
        ],
        studySessions: [
          {
            'id': 'restored-session',
            'title': 'جلسه بازیابی‌شده',
            'subject': 'علوم',
            'weekday': 6,
            'startMinutes': 600,
            'durationMinutes': 45,
            'completed': true,
          },
        ],
        exams: [
          {
            'id': 'restored-exam',
            'name': 'آزمون بازیابی‌شده',
            'questionCount': 2,
            'durationSeconds': 1800,
            'negativeMarking': true,
            'isCompleted': false,
            'answers': {'1': 0},
            'answerKey': {'1': 0},
            'marked': [2],
          },
        ],
        results: [
          {
            'id': 'restored-result',
            'examId': 'restored-exam',
            'examName': 'آزمون بازیابی‌شده',
            'completedAt': '2026-10-30T15:00:00.000Z',
            'questionCount': 2,
            'correct': 1,
            'wrong': 0,
            'unanswered': 1,
            'keyedQuestions': 1,
            'percentage': 100.0,
            'negativeMarking': true,
            'answers': {'1': 0},
            'answerKey': {'1': 0},
          },
        ],
      ),
    );

    await tester.pumpWidget(const DarsYarApp(initialTab: 3));
    await tester.pumpAndSettle();
    final restoreButton = find.text('بازیابی فایل پشتیبان');
    await tester.ensureVisible(restoreButton);
    await tester.pumpAndSettle();
    await tester.tap(restoreButton);
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(GlassTextField).last, backup);
    final reviewButton = find.text('بررسی نسخه');
    await tester.ensureVisible(reviewButton);
    await tester.pumpAndSettle();
    await tester.tap(reviewButton);
    await tester.pumpAndSettle();
    final confirmRestore = find.text('بازیابی').last;
    await tester.ensureVisible(confirmRestore);
    await tester.pumpAndSettle();
    await tester.tap(confirmRestore);
    await tester.pumpAndSettle();

    final prefs = await SharedPreferences.getInstance();
    final savedTasks = jsonDecode(prefs.getString('darsyar.tasks')!) as List;
    final savedSessions = jsonDecode(prefs.getString('darsyar.studySessions')!) as List;
    final savedExams = jsonDecode(prefs.getString('darsyar.exams')!) as List;
    final savedResults = jsonDecode(prefs.getString('darsyar.results')!) as List;

    expect(savedTasks.single['id'], 'restored-task');
    expect(savedTasks.single['done'], isTrue);
    expect(savedSessions.single['id'], 'restored-session');
    expect(savedExams.single['id'], 'restored-exam');
    expect(savedExams.single['marked'], [2]);
    expect(savedResults.single['id'], 'restored-result');
    expect(prefs.getString('darsyar.activeExamId'), 'restored-exam');
    expect(tester.takeException(), isNull);
  });


  testWidgets('dashboard quick actions adapt to compact widths without overflow', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(const DarsYarApp());
    await tester.pumpAndSettle();

    expect(find.text('برنامه‌ریزی درسی'), findsOneWidget);
    expect(find.text('پاسخ‌برگ آزمون'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('برنامه‌ریزی درسی'));
    await tester.pumpAndSettle();
    expect(find.text('انتخاب روز'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });


  testWidgets('planner summary metrics and weekly overview render without layout errors', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(const DarsYarApp(initialTab: 1));
    await tester.pumpAndSettle();

    expect(find.text('جلسه‌ها'), findsOneWidget);
    expect(find.text('انجام‌شده'), findsOneWidget);
    expect(find.text('دقیقه امروز'), findsOneWidget);
    expect(find.text('نمای کلی هفته'), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('planner-week-selected-indicator')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });


  testWidgets('planner session and task cards keep clear hierarchy on compact screens', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({
      'darsyar.studySessions': jsonEncode([
        {
          'id': 'compact-session',
          'title': 'مرور فصل‌های مهم زیست‌شناسی',
          'subject': 'زیست‌شناسی',
          // Keep this fixture independent of the runner's local date.
          'weekday': 3,
          'startMinutes': 600,
          'durationMinutes': 50,
          'completed': false,
        },
      ]),
      'darsyar.tasks': jsonEncode([
        {
          'id': 'compact-task',
          'title': 'حل تمرین‌های تکمیلی ریاضی',
          'subject': 'ریاضی',
          'done': false,
        },
      ]),
    });

    await tester.pumpWidget(const DarsYarApp(initialTab: 1));
    await tester.pumpAndSettle();

    final sessionTitle = find.text('مرور فصل‌های مهم زیست‌شناسی');
    // Select the fixture's fixed weekday through its stable chip identity.
    await tester.tap(find.byKey(const ValueKey<String>('planner-day-3')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(sessionTitle);
    await tester.pumpAndSettle();
    expect(sessionTitle, findsOneWidget);
    expect(find.text('زیست‌شناسی'), findsWidgets);
    expect(find.text('۱۰:۰۰'), findsOneWidget);
    expect(find.text('۵۰ دقیقه'), findsOneWidget);

    final completeSession = find.bySemanticsLabel('علامت‌گذاری جلسه به‌عنوان انجام‌شده');
    expect(completeSession, findsOneWidget);
    await tester.tap(completeSession);
    await tester.pumpAndSettle();

    final prefs = await SharedPreferences.getInstance();
    final savedSessions = jsonDecode(prefs.getString('darsyar.studySessions')!) as List;
    expect(savedSessions.single['completed'], isTrue);

    final taskTitle = find.text('حل تمرین‌های تکمیلی ریاضی');
    await tester.ensureVisible(taskTitle);
    await tester.pumpAndSettle();
    expect(taskTitle, findsOneWidget);
    expect(find.text('ریاضی'), findsWidgets);
    expect(find.bySemanticsLabel('ویرایش وظیفه'), findsOneWidget);
    expect(find.bySemanticsLabel('حذف وظیفه'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });


  testWidgets('exam result history cards remain readable on compact screens', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({
      'darsyar.results': jsonEncode([
        {
          'id': 'compact-result',
          'examId': 'compact-exam',
          'examName': 'آزمون جامع پایان فصل زیست‌شناسی',
          'completedAt': '2026-10-30T10:00:00.000Z',
          'questionCount': 30,
          'correct': 24,
          'wrong': 3,
          'unanswered': 3,
          'keyedQuestions': 30,
          'percentage': 80.0,
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

    final resultTitle = find.text('آزمون جامع پایان فصل زیست‌شناسی');
    await tester.ensureVisible(resultTitle);
    expect(resultTitle, findsOneWidget);
    expect(find.text('80%'), findsOneWidget);
    expect(find.text('30 سؤال'), findsOneWidget);
    expect(find.text('درست: 24'), findsOneWidget);
    expect(find.text('غلط: 3'), findsOneWidget);
    expect(find.text('بی‌پاسخ: 3'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

}

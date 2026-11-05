import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dars_yar/features/exams/domain/models/exam_sheet.dart';
import 'package:dars_yar/features/exams/presentation/saved_exams_view.dart';

void main() {
  testWidgets('saved exams view renders the empty state and result history',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SavedExamsView(
            exams: const [],
            savedExamCardBuilder: (exam) => Text(exam.name),
            emptyStateBuilder: (_, title, _) => Text(title),
            resultsHistoryBuilder: () => const Text('تاریخچه نتایج'),
          ),
        ),
      ),
    );

    expect(find.text('پاسخ‌برگ‌های ذخیره‌شده'), findsOneWidget);
    expect(find.text('هنوز آزمونی نساخته‌ای'), findsOneWidget);
    expect(find.text('تاریخچه نتایج'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('saved exams view reverses exams and keeps result history',
      (tester) async {
    final exams = [
      ExamSheet(id: 'first', name: 'آزمون اول'),
      ExamSheet(id: 'second', name: 'آزمون دوم'),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SavedExamsView(
            exams: exams,
            savedExamCardBuilder: (exam) => Text(exam.name),
            emptyStateBuilder: (_, title, _) => Text(title),
            resultsHistoryBuilder: () => const Text('تاریخچه نتایج'),
          ),
        ),
      ),
    );

    expect(find.text('آزمون دوم'), findsOneWidget);
    expect(find.text('آزمون اول'), findsOneWidget);
    expect(find.text('هنوز آزمونی نساخته‌ای'), findsNothing);
    expect(find.text('تاریخچه نتایج'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

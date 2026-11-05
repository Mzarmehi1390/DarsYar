import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dars_yar/features/exams/domain/models/exam_sheet.dart';
import 'package:dars_yar/features/exams/presentation/exam_question_navigator.dart';

void main() {
  testWidgets('question navigator distinguishes current, answered and marked',
      (tester) async {
    final exam = ExamSheet(
      id: 'exam',
      name: 'آزمون',
      questionCount: 3,
      answers: {2: 1},
      marked: {3},
    );
    int? selectedQuestion;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: ExamQuestionNavigator(
              exam: exam,
              currentQuestion: 1,
              onQuestionSelected: (question) => selectedQuestion = question,
            ),
          ),
        ),
      ),
    );

    expect(find.text('سؤال 1'), findsOneWidget);
    expect(find.text('سؤال 2'), findsOneWidget);
    expect(find.text('سؤال 3'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
    expect(find.byIcon(Icons.flag_rounded), findsOneWidget);

    await tester.tap(find.text('سؤال 2'));
    expect(selectedQuestion, 2);
    expect(tester.takeException(), isNull);
  });
}

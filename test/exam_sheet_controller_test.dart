import 'package:flutter_test/flutter_test.dart';
import 'package:dars_yar/features/exams/application/exam_sheet_controller.dart';
import 'package:dars_yar/features/exams/domain/models/exam_result.dart';
import 'package:dars_yar/features/exams/domain/models/exam_sheet.dart';

void main() {
  const controller = ExamSheetController();

  test('renaming a sheet updates linked and legacy name-only results', () {
    final exam = ExamSheet(id: 'exam-1', name: 'قدیمی');
    final linked = ExamResult(
      id: 'r1',
      examId: 'exam-1',
      examName: 'قدیمی',
      completedAt: '2026-11-01T00:00:00Z',
      questionCount: 1,
      correct: 1,
      wrong: 0,
      unanswered: 0,
      keyedQuestions: 1,
      percentage: 100,
      negativeMarking: false,
    );
    final legacy = ExamResult(
      id: 'r2',
      examName: 'قدیمی',
      completedAt: '2026-11-02T00:00:00Z',
      questionCount: 1,
      correct: 0,
      wrong: 0,
      unanswered: 1,
      keyedQuestions: 0,
      percentage: null,
      negativeMarking: false,
    );
    final results = [linked, legacy];

    controller.rename(exam: exam, results: results, name: 'جدید');

    expect(exam.name, 'جدید');
    expect(results.map((result) => result.examName), ['جدید', 'جدید']);
  });

  test('deleting a sheet removes its results and selects previous sheet', () {
    final first = ExamSheet(id: 'first', name: 'اول');
    final second = ExamSheet(id: 'second', name: 'دوم');
    final third = ExamSheet(id: 'third', name: 'سوم');
    final results = [
      ExamResult(
        id: 'linked',
        examId: 'second',
        examName: 'دوم',
        completedAt: '2026-11-01T00:00:00Z',
        questionCount: 1,
        correct: 0,
        wrong: 0,
        unanswered: 1,
        keyedQuestions: 0,
        percentage: null,
        negativeMarking: false,
      ),
    ];
    final exams = [first, second, third];

    final active = controller.delete(
      exams: exams,
      results: results,
      activeExamId: 'second',
    );

    expect(active, 'first');
    expect(exams, [first, third]);
    expect(results, isEmpty);
  });

  test('the last sheet cannot be deleted', () {
    expect(
      () => controller.delete(
        exams: [ExamSheet(id: 'only', name: 'تنها')],
        results: [],
        activeExamId: 'only',
      ),
      throwsStateError,
    );
  });

  test('resizing removes answers, key entries and marks beyond new count', () {
    final exam = ExamSheet(
      id: 'exam',
      name: 'آزمون',
      questionCount: 5,
      answers: {1: 0, 5: 2},
      answerKey: {2: 1, 5: 3},
      marked: {3, 5},
    );

    controller.resize(exam, 3);

    expect(exam.questionCount, 3);
    expect(exam.answers, {1: 0});
    expect(exam.answerKey, {2: 1});
    expect(exam.marked, {3});
  });

  test('answering clears review mark while clearing can preserve it', () {
    final exam = ExamSheet(id: 'exam', name: 'آزمون', marked: {2});
    controller.setAnswer(exam: exam, question: 2, answer: 1, marked: true);
    expect(exam.answers[2], 1);
    expect(exam.marked, isEmpty);

    controller.setAnswer(exam: exam, question: 2, answer: null, marked: true);
    expect(exam.answers, isEmpty);
    expect(exam.marked, {2});
  });
}

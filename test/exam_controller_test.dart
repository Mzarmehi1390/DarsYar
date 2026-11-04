import 'package:flutter_test/flutter_test.dart';
import 'package:dars_yar/exam_result.dart';
import 'package:dars_yar/exam_sheet.dart';
import 'package:dars_yar/features/exams/application/exam_controller.dart';

void main() {
  const controller = ExamController();

  ExamResult result({
    String id = 'result-1',
    String? examId = 'exam-1',
    String examName = 'آزمون',
    Map<int, int> answers = const {1: 0, 2: 1, 3: 2},
    Map<int, int> answerKey = const {1: 0, 2: 2, 3: 1},
    bool negativeMarking = false,
  }) {
    return ExamResult(
      id: id,
      examId: examId,
      examName: examName,
      completedAt: '2026-11-04T10:00:00Z',
      questionCount: 3,
      correct: 0,
      wrong: 0,
      unanswered: 0,
      keyedQuestions: 3,
      percentage: 0,
      negativeMarking: negativeMarking,
      answers: answers,
      answerKey: answerKey,
    );
  }

  test('recalculates score and stores the revised answer key', () {
    final updated = controller.recalculateResult(
      result(negativeMarking: true),
      {1: 0, 2: 1, 3: 2},
    );

    expect(updated.correct, 3);
    expect(updated.wrong, 0);
    expect(updated.unanswered, 0);
    expect(updated.percentage, 100);
    expect(updated.answerKey, {1: 0, 2: 1, 3: 2});
  });

  test('clears percentage when the revised key is empty', () {
    final updated = controller.recalculateResult(result(), {});
    expect(updated.keyedQuestions, 0);
    expect(updated.percentage, isNull);
  });

  test('syncs results linked by exam id and leaves unrelated results intact', () {
    final linked = result();
    final unrelated = result(
      id: 'result-2',
      examId: 'other-exam',
      examName: 'آزمون دیگر',
    );
    final results = [linked, unrelated];
    final exam = ExamSheet(
      id: 'exam-1',
      name: 'آزمون',
      questionCount: 3,
      answerKey: {1: 0, 2: 1, 3: 2},
    );

    controller.syncResults(results: results, exam: exam);

    expect(results.first.correct, 3);
    expect(results.first.percentage, 100);
    expect(results.last, same(unrelated));
  });

  test('syncs legacy results by name when no exam id was stored', () {
    final legacy = result(examId: null);
    final results = [legacy];
    final exam = ExamSheet(
      id: 'exam-new',
      name: 'آزمون',
      questionCount: 3,
      answerKey: {1: 0, 2: 1, 3: 2},
    );

    controller.syncResults(results: results, exam: exam);

    expect(results.single.correct, 3);
    expect(results.single.percentage, 100);
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:dars_yar/exam_result.dart';

void main() {
  group('ExamResult', () {
    test('serializes and restores a saved result', () {
      const result = ExamResult(
        id: 'result-1',
        examName: 'آزمون ریاضی',
        completedAt: '2026-10-29T10:30:00.000Z',
        questionCount: 20,
        correct: 15,
        wrong: 3,
        unanswered: 2,
        keyedQuestions: 18,
        percentage: 83.333333,
      );

      final restored = ExamResult.fromJson(result.toJson());

      expect(restored.id, result.id);
      expect(restored.examName, result.examName);
      expect(restored.completedAt, result.completedAt);
      expect(restored.questionCount, 20);
      expect(restored.correct, 15);
      expect(restored.wrong, 3);
      expect(restored.unanswered, 2);
      expect(restored.keyedQuestions, 18);
      expect(restored.percentage, result.percentage);
    });

    test('uses safe defaults for optional legacy fields', () {
      final result = ExamResult.fromJson({'id': 'legacy'});

      expect(result.examName, 'آزمون');
      expect(result.questionCount, 0);
      expect(result.percentage, 0);
    });
  });
}

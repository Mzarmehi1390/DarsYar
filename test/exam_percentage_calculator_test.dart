import 'package:flutter_test/flutter_test.dart';
import 'package:dars_yar/exam_percentage_calculator.dart';

void main() {
  test('calculates regular, negative and skipped-wrong percentages', () {
    final result = calculateExamPercentages(
      correct: 15,
      wrong: 3,
      unanswered: 2,
    );

    expect(result.withoutPenalty, 75);
    expect(result.withPenalty, closeTo(70, 0.0001));
    expect(result.ifWrongWereSkipped, 75);
  });

  test('negative percentage is clamped at zero', () {
    final result = calculateExamPercentages(
      correct: 1,
      wrong: 12,
      unanswered: 0,
    );

    expect(result.withPenalty, 0);
  });

  test('rejects empty and out-of-range counts', () {
    expect(
      calculateExamPercentages(correct: 0, wrong: 0, unanswered: 0).withoutPenalty,
      isNull,
    );
    expect(
      calculateExamPercentages(correct: 201, wrong: 0, unanswered: 0).withoutPenalty,
      isNull,
    );
  });
}

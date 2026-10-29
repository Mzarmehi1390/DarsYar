import 'package:flutter_test/flutter_test.dart';
import 'package:dars_yar/answer_scoring.dart';

void main() {
  group('calculateAnswerScore', () {
    test('counts correct, wrong and unanswered questions', () {
      final score = calculateAnswerScore(
        answers: {1: 0, 2: 1, 4: 2},
        answerKey: {1: 0, 2: 2, 3: 1, 4: 2},
        questionCount: 5,
      );

      expect(score.correct, 2);
      expect(score.wrong, 1);
      expect(score.unanswered, 2);
      expect(score.keyedQuestions, 4);
      expect(score.percentage, 50);
    });

    test('does not mark answers without a key as wrong', () {
      final score = calculateAnswerScore(
        answers: {1: 3, 2: 1},
        answerKey: {2: 1},
        questionCount: 3,
      );

      expect(score.correct, 1);
      expect(score.wrong, 0);
      expect(score.unanswered, 1);
      expect(score.percentage, 100);
    });

    test('returns zero percent when no answer key exists', () {
      final score = calculateAnswerScore(
        answers: {1: 2},
        answerKey: {},
        questionCount: 2,
      );

      expect(score.correct, 0);
      expect(score.wrong, 0);
      expect(score.unanswered, 1);
      expect(score.keyedQuestions, 0);
      expect(score.percentage, 0);
    });

    test('ignores key entries outside the question range', () {
      final score = calculateAnswerScore(
        answers: {1: 0, 9: 2},
        answerKey: {1: 0, 9: 1},
        questionCount: 2,
      );

      expect(score.correct, 1);
      expect(score.wrong, 0);
      expect(score.unanswered, 1);
      expect(score.keyedQuestions, 1);
    });
    test('ignores invalid option values and out-of-range answers', () {
      final score = calculateAnswerScore(
        answers: {1: 0, 2: 8, 3: 2, 7: 1},
        answerKey: {1: 0, 2: 1, 3: -1, 4: 2, 7: 1},
        questionCount: 4,
      );

      expect(score.correct, 1);
      expect(score.wrong, 0);
      expect(score.keyedQuestions, 2);
      expect(score.unanswered, 2);
      expect(score.percentage, 50);
    });

    test('handles a negative question count safely', () {
      final score = calculateAnswerScore(
        answers: {1: 0},
        answerKey: {1: 0},
        questionCount: -2,
      );

      expect(score.keyedQuestions, 0);
      expect(score.unanswered, 0);
      expect(score.percentage, 0);
    });

  });
}

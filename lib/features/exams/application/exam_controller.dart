import '../../../answer_scoring.dart';
import '../../../exam_result.dart';
import '../../../exam_sheet.dart';

/// Owns exam-result scoring and keeps saved results synchronized with
/// the answer key on their originating exam sheet.
class ExamController {
  const ExamController();

  ExamResult recalculateResult(ExamResult result, Map<int, int> key) {
    final score = calculateAnswerScore(
      answers: result.answers,
      answerKey: key,
      questionCount: result.questionCount,
      negativeMarking: result.negativeMarking,
    );
    return result.copyWith(
      correct: score.correct,
      wrong: score.wrong,
      unanswered: score.unanswered,
      keyedQuestions: score.keyedQuestions,
      percentage: score.percentage,
      clearPercentage: score.percentage == null,
      answerKey: Map<int, int>.from(key),
    );
  }

  void syncResults({
    required List<ExamResult> results,
    required ExamSheet exam,
  }) {
    for (var i = 0; i < results.length; i++) {
      final result = results[i];
      if (result.examId == exam.id ||
          (result.examId == null && result.examName == exam.name)) {
        results[i] = recalculateResult(result, exam.answerKey);
      }
    }
  }
}

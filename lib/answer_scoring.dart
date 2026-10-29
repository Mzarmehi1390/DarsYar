class AnswerScore {
  const AnswerScore({
    required this.correct,
    required this.wrong,
    required this.unanswered,
    required this.keyedQuestions,
    required this.percentage,
  });

  final int correct;
  final int wrong;
  final int unanswered;
  final int keyedQuestions;
  final double percentage;
}

/// Scores only questions that have a correct option in [answerKey].
/// Unkeyed questions are not incorrectly treated as wrong answers.
AnswerScore calculateAnswerScore({
  required Map<int, int> answers,
  required Map<int, int> answerKey,
  required int questionCount,
}) {
  var correct = 0;
  var wrong = 0;

  for (final entry in answerKey.entries) {
    if (entry.key < 1 || entry.key > questionCount) continue;
    final selected = answers[entry.key];
    if (selected == null) continue;
    if (selected == entry.value) {
      correct++;
    } else {
      wrong++;
    }
  }

  final keyedQuestions = answerKey.keys.where((n) => n >= 1 && n <= questionCount).length;
  final unanswered = questionCount - answers.keys.where((n) => n >= 1 && n <= questionCount).length;
  final percentage = keyedQuestions == 0 ? 0.0 : correct * 100 / keyedQuestions;

  return AnswerScore(
    correct: correct,
    wrong: wrong,
    unanswered: unanswered < 0 ? 0 : unanswered,
    keyedQuestions: keyedQuestions,
    percentage: percentage,
  );
}

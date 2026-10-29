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
  final safeQuestionCount = questionCount < 0 ? 0 : questionCount;
  var correct = 0;
  var wrong = 0;

  // Only valid question numbers and options (0..3) can contribute to a score.
  final validKey = <int, int>{
    for (final entry in answerKey.entries)
      if (entry.key >= 1 &&
          entry.key <= safeQuestionCount &&
          entry.value >= 0 &&
          entry.value <= 3)
        entry.key: entry.value,
  };
  final validAnswers = <int, int>{
    for (final entry in answers.entries)
      if (entry.key >= 1 &&
          entry.key <= safeQuestionCount &&
          entry.value >= 0 &&
          entry.value <= 3)
        entry.key: entry.value,
  };

  for (final entry in validKey.entries) {
    final selected = validAnswers[entry.key];
    if (selected == null) continue;
    if (selected == entry.value) {
      correct++;
    } else {
      wrong++;
    }
  }

  final keyedQuestions = validKey.length;
  final unanswered = safeQuestionCount - validAnswers.length;
  final percentage = keyedQuestions == 0 ? 0.0 : correct * 100 / keyedQuestions;

  return AnswerScore(
    correct: correct,
    wrong: wrong,
    unanswered: unanswered,
    keyedQuestions: keyedQuestions,
    percentage: percentage,
  );
}

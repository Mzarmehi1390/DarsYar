class AnswerScore {
  const AnswerScore({
    required this.correct,
    required this.wrong,
    required this.unanswered,
    required this.keyedQuestions,
    required this.percentage,
    required this.rawScore,
  });

  final int correct;
  final int wrong;
  final int unanswered;
  final int keyedQuestions;
  final double? percentage;
  final double rawScore;
}

/// Unkeyed questions are excluded. With negative marking enabled, each
/// incorrect answer deducts one third of a correct answer (three wrong = one
/// correct), and the final percentage is never shown below zero.
AnswerScore calculateAnswerScore({
  required Map<int, int> answers,
  required Map<int, int> answerKey,
  required int questionCount,
  bool negativeMarking = false,
}) {
  final safeQuestionCount = questionCount < 0 ? 0 : questionCount;
  var correct = 0;
  var wrong = 0;

  final validKey = <int, int>{
    for (final entry in answerKey.entries)
      if (entry.key >= 1 && entry.key <= safeQuestionCount &&
          entry.value >= 0 && entry.value <= 3)
        entry.key: entry.value,
  };
  final validAnswers = <int, int>{
    for (final entry in answers.entries)
      if (entry.key >= 1 && entry.key <= safeQuestionCount &&
          entry.value >= 0 && entry.value <= 3)
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
  final rawScore = correct - (negativeMarking ? wrong / 3 : 0);
  final percentage = keyedQuestions == 0
      ? null
      : (rawScore * 100 / keyedQuestions).clamp(0.0, 100.0).toDouble();

  return AnswerScore(
    correct: correct,
    wrong: wrong,
    unanswered: unanswered,
    keyedQuestions: keyedQuestions,
    percentage: percentage,
    rawScore: rawScore,
  );
}

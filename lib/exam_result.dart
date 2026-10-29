class ExamResult {
  const ExamResult({
    required this.id,
    required this.examName,
    required this.completedAt,
    required this.questionCount,
    required this.correct,
    required this.wrong,
    required this.unanswered,
    required this.keyedQuestions,
    required this.percentage,
  });

  final String id;
  final String examName;
  final String completedAt;
  final int questionCount;
  final int correct;
  final int wrong;
  final int unanswered;
  final int keyedQuestions;
  final double percentage;

  // Invalid legacy timestamps sort to the beginning of history instead of
  // appearing to be a brand-new result every time the app is opened.
  DateTime get dateTime =>
      DateTime.tryParse(completedAt)?.toLocal() ??
      DateTime.fromMillisecondsSinceEpoch(0);

  Map<String, dynamic> toJson() => {
        'id': id,
        'examName': examName,
        'completedAt': completedAt,
        'questionCount': questionCount,
        'correct': correct,
        'wrong': wrong,
        'unanswered': unanswered,
        'keyedQuestions': keyedQuestions,
        'percentage': percentage,
      };

  factory ExamResult.fromJson(Map<String, dynamic> json) {
    int readInt(String key, {int fallback = 0}) {
      final value = json[key];
      return value is num ? value.toInt() : fallback;
    }

    final questionCount = readInt('questionCount').clamp(0, 200).toInt();
    final keyedQuestions =
        readInt('keyedQuestions').clamp(0, questionCount).toInt();
    final correct = readInt('correct').clamp(0, keyedQuestions).toInt();
    final wrong =
        readInt('wrong').clamp(0, keyedQuestions - correct).toInt();
    final unanswered = readInt('unanswered').clamp(0, questionCount).toInt();
    final rawId = json['id'];
    final rawName = json['examName'];
    final rawCompletedAt = json['completedAt'];
    final calculatedPercentage =
        keyedQuestions == 0 ? 0.0 : correct * 100 / keyedQuestions;

    return ExamResult(
      id: rawId is String && rawId.isNotEmpty ? rawId : 'legacy-result',
      examName: rawName is String && rawName.trim().isNotEmpty
          ? rawName
          : 'آزمون',
      completedAt: rawCompletedAt is String ? rawCompletedAt : '',
      questionCount: questionCount,
      correct: correct,
      wrong: wrong,
      unanswered: unanswered,
      keyedQuestions: keyedQuestions,
      percentage: calculatedPercentage,
    );
  }
}

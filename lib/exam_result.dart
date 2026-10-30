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
    this.negativeMarking = false,
    this.answers = const <int, int>{},
    this.answerKey = const <int, int>{},
  });

  final String id;
  final String examName;
  final String completedAt;
  final int questionCount;
  final int correct;
  final int wrong;
  final int unanswered;
  final int keyedQuestions;
  final double? percentage;
  final bool negativeMarking;
  final Map<int, int> answers;
  final Map<int, int> answerKey;

  DateTime get dateTime =>
      DateTime.tryParse(completedAt)?.toLocal() ??
      DateTime.fromMillisecondsSinceEpoch(0);

  ExamResult copyWith({
    int? correct,
    int? wrong,
    int? unanswered,
    int? keyedQuestions,
    double? percentage,
    Map<int, int>? answerKey,
  }) => ExamResult(
    id: id,
    examName: examName,
    completedAt: completedAt,
    questionCount: questionCount,
    correct: correct ?? this.correct,
    wrong: wrong ?? this.wrong,
    unanswered: unanswered ?? this.unanswered,
    keyedQuestions: keyedQuestions ?? this.keyedQuestions,
    percentage: percentage ?? this.percentage,
    negativeMarking: negativeMarking,
    answers: answers,
    answerKey: answerKey ?? this.answerKey,
  );

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
    'negativeMarking': negativeMarking,
    'answers': answers.map((k, v) => MapEntry(k.toString(), v)),
    'answerKey': answerKey.map((k, v) => MapEntry(k.toString(), v)),
  };

  factory ExamResult.fromJson(Map<String, dynamic> json) {
    int readInt(String key, {int fallback = 0}) {
      final value = json[key];
      return value is num ? value.toInt() : fallback;
    }
    Map<int, int> readAnswers(String key) {
      final raw = json[key];
      if (raw is! Map) return <int, int>{};
      final parsed = <int, int>{};
      for (final entry in raw.entries) {
        final question = int.tryParse(entry.key.toString());
        final answer = entry.value is num ? (entry.value as num).toInt() : -1;
        if (question != null && question >= 1 && question <= 200 &&
            answer >= 0 && answer <= 3) {
          parsed[question] = answer;
        }
      }
      return parsed;
    }

    final questionCount = readInt('questionCount').clamp(0, 200).toInt();
    final keyedQuestions = readInt('keyedQuestions').clamp(0, questionCount).toInt();
    final correct = readInt('correct').clamp(0, keyedQuestions).toInt();
    final wrong = readInt('wrong').clamp(0, keyedQuestions - correct).toInt();
    final unanswered = readInt('unanswered').clamp(0, questionCount).toInt();
    final rawId = json['id'];
    final rawName = json['examName'];
    final rawCompletedAt = json['completedAt'];
    final rawPercentage = json['percentage'];
    final parsedPercentage = rawPercentage is num
        ? rawPercentage.toDouble().clamp(0.0, 100.0).toDouble()
        : (keyedQuestions == 0 ? null : correct * 100 / keyedQuestions);

    return ExamResult(
      id: rawId is String && rawId.isNotEmpty ? rawId : 'legacy-result',
      examName: rawName is String && rawName.trim().isNotEmpty ? rawName : 'آزمون',
      completedAt: rawCompletedAt is String ? rawCompletedAt : '',
      questionCount: questionCount,
      correct: correct,
      wrong: wrong,
      unanswered: unanswered,
      keyedQuestions: keyedQuestions,
      percentage: parsedPercentage,
      negativeMarking: json['negativeMarking'] == true,
      answers: readAnswers('answers'),
      answerKey: readAnswers('answerKey'),
    );
  }
}

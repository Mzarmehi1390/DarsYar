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

  DateTime get dateTime => DateTime.tryParse(completedAt)?.toLocal() ?? DateTime.now();

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

  factory ExamResult.fromJson(Map<String, dynamic> json) => ExamResult(
        id: json['id'] as String,
        examName: json['examName'] as String? ?? 'آزمون',
        completedAt: json['completedAt'] as String? ?? '',
        questionCount: (json['questionCount'] as num?)?.toInt() ?? 0,
        correct: (json['correct'] as num?)?.toInt() ?? 0,
        wrong: (json['wrong'] as num?)?.toInt() ?? 0,
        unanswered: (json['unanswered'] as num?)?.toInt() ?? 0,
        keyedQuestions: (json['keyedQuestions'] as num?)?.toInt() ?? 0,
        percentage: (json['percentage'] as num?)?.toDouble() ?? 0,
      );
}

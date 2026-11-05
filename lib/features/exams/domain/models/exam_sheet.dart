class ExamSheet {
  ExamSheet({
    required this.id,
    required this.name,
    this.questionCount = 20,
    this.durationSeconds = 30 * 60,
    this.negativeMarking = false,
    this.isCompleted = false,
    Map<int, int>? answers,
    Map<int, int>? answerKey,
    Set<int>? marked,
  })  : answers = answers ?? <int, int>{},
        answerKey = answerKey ?? <int, int>{},
        marked = marked ?? <int>{};

  final String id;
  String name;
  int questionCount;
  int durationSeconds;
  bool negativeMarking;
  bool isCompleted;
  final Map<int, int> answers;
  final Map<int, int> answerKey;
  final Set<int> marked;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'questionCount': questionCount,
        'durationSeconds': durationSeconds,
        'negativeMarking': negativeMarking,
        'isCompleted': isCompleted,
        'answers': answers.map((k, v) => MapEntry(k.toString(), v)),
        'answerKey': answerKey.map((k, v) => MapEntry(k.toString(), v)),
        'marked': marked.toList(),
      };

  factory ExamSheet.fromJson(Map<String, dynamic> json) {
    final count = ((json['questionCount'] as num?)?.toInt() ?? 20)
        .clamp(1, 200)
        .toInt();

    Map<int, int> parseAnswers(Object? value) {
      if (value is! Map) return <int, int>{};
      final parsed = <int, int>{};
      for (final entry in value.entries) {
        final question = int.tryParse(entry.key.toString());
        final answer = entry.value is num ? (entry.value as num).toInt() : -1;
        if (question == null || question < 1 || question > count) continue;
        if (answer < 0 || answer > 3) continue;
        parsed[question] = answer;
      }
      return parsed;
    }

    Set<int> parseMarked(Object? value) {
      if (value is! List) return <int>{};
      return value.whereType<num>().map((item) => item.toInt())
          .where((question) => question >= 1 && question <= count).toSet();
    }

    final rawDuration = json['durationSeconds'];
    return ExamSheet(
      id: json['id'] as String? ?? 'default',
      name: json['name'] as String? ?? 'آزمون',
      questionCount: count,
      durationSeconds: rawDuration is num
          ? rawDuration.toInt().clamp(1, 24 * 60 * 60).toInt()
          : 30 * 60,
      negativeMarking: json['negativeMarking'] == true,
      isCompleted: json['isCompleted'] == true,
      answers: parseAnswers(json['answers']),
      answerKey: parseAnswers(json['answerKey']),
      marked: parseMarked(json['marked']),
    );
  }
}

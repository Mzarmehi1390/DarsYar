class ExamSheet {
  ExamSheet({
    required this.id,
    required this.name,
    this.questionCount = 20,
    Map<int, int>? answers,
    Map<int, int>? answerKey,
    Set<int>? marked,
  })  : answers = answers ?? <int, int>{},
        answerKey = answerKey ?? <int, int>{},
        marked = marked ?? <int>{};

  final String id;
  String name;
  int questionCount;
  final Map<int, int> answers;
  final Map<int, int> answerKey;
  final Set<int> marked;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'questionCount': questionCount,
        'answers': answers.map((k, v) => MapEntry(k.toString(), v)),
        'answerKey': answerKey.map((k, v) => MapEntry(k.toString(), v)),
        'marked': marked.toList(),
      };

  factory ExamSheet.fromJson(Map<String, dynamic> json) {
    Map<int, int> parseAnswers(Object? value) {
      if (value is! Map) return <int, int>{};
      return value.map((key, answer) => MapEntry(
            int.parse(key.toString()),
            (answer as num).toInt(),
          ));
    }

    Set<int> parseMarked(Object? value) {
      if (value is! List) return <int>{};
      return value.map((item) => (item as num).toInt()).toSet();
    }

    final count = (json['questionCount'] as num?)?.toInt() ?? 20;
    return ExamSheet(
      id: json['id'] as String,
      name: json['name'] as String? ?? 'آزمون',
      questionCount: count.clamp(1, 200),
      answers: parseAnswers(json['answers']),
      answerKey: parseAnswers(json['answerKey']),
      marked: parseMarked(json['marked')),
    );
  }
}

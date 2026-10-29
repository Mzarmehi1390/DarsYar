class StudySession {
  const StudySession({
    required this.id,
    required this.title,
    required this.subject,
    required this.weekday,
    required this.startMinutes,
    required this.durationMinutes,
    this.completed = false,
  })  : assert(weekday >= 0 && weekday <= 6),
        assert(startMinutes >= 0 && startMinutes < 1440),
        assert(durationMinutes > 0);

  final String id;
  final String title;
  final String subject;
  /// Sunday = 0, Monday = 1, ... Saturday = 6.
  final int weekday;
  final int startMinutes;
  final int durationMinutes;
  final bool completed;

  StudySession copyWith({
    String? title,
    String? subject,
    int? weekday,
    int? startMinutes,
    int? durationMinutes,
    bool? completed,
  }) => StudySession(
        id: id,
        title: title ?? this.title,
        subject: subject ?? this.subject,
        weekday: weekday ?? this.weekday,
        startMinutes: startMinutes ?? this.startMinutes,
        durationMinutes: durationMinutes ?? this.durationMinutes,
        completed: completed ?? this.completed,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'subject': subject,
        'weekday': weekday,
        'startMinutes': startMinutes,
        'durationMinutes': durationMinutes,
        'completed': completed,
      };

  factory StudySession.fromJson(Map<String, dynamic> json) {
    final weekday = ((json['weekday'] as num?)?.toInt() ?? 0)
        .clamp(0, 6)
        .toInt();
    final startMinutes = ((json['startMinutes'] as num?)?.toInt() ?? 960)
        .clamp(0, 1439)
        .toInt();
    final maxDuration = 1440 - startMinutes;
    final durationMinutes = ((json['durationMinutes'] as num?)?.toInt() ?? 55)
        .clamp(1, maxDuration)
        .toInt();

    return StudySession(
      id: json['id'] as String,
      title: json['title'] as String,
      subject: json['subject'] as String? ?? 'عمومی',
      weekday: weekday,
      startMinutes: startMinutes,
      durationMinutes: durationMinutes,
      completed: json['completed'] as bool? ?? false,
    );
  }
}

/// Returns true when two study sessions overlap on the same weekday.
bool studySessionsOverlap(StudySession first, StudySession second) =>
    first.weekday == second.weekday &&
    first.startMinutes < second.startMinutes + second.durationMinutes &&
    second.startMinutes < first.startMinutes + first.durationMinutes;

class StudySession {
  const StudySession({
    required this.id,
    required this.title,
    required this.subject,
    required this.weekday,
    required this.startMinutes,
    required this.durationMinutes,
    this.completed = false,
    this.scheduledDate,
  })  : assert(weekday >= 0 && weekday <= 6),
        assert(startMinutes >= 0 && startMinutes < 1440),
        assert(durationMinutes > 0);

  final String id;
  final String title;
  final String subject;
  /// Sunday = 0, Monday = 1, ... Saturday = 6. Retained for legacy backups.
  final int weekday;
  final int startMinutes;
  final int durationMinutes;
  final bool completed;
  /// Local calendar date for this occurrence. Null only for legacy records.
  final DateTime? scheduledDate;

  static DateTime dateOnly(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  static int weekdayFor(DateTime date) => date.weekday % 7;

  StudySession copyWith({
    String? title,
    String? subject,
    int? weekday,
    int? startMinutes,
    int? durationMinutes,
    bool? completed,
    DateTime? scheduledDate,
  }) => StudySession(
        id: id,
        title: title ?? this.title,
        subject: subject ?? this.subject,
        weekday: weekday ?? (scheduledDate == null ? this.weekday : weekdayFor(scheduledDate)),
        startMinutes: startMinutes ?? this.startMinutes,
        durationMinutes: durationMinutes ?? this.durationMinutes,
        completed: completed ?? this.completed,
        scheduledDate: scheduledDate == null
            ? this.scheduledDate
            : dateOnly(scheduledDate),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'subject': subject,
        'weekday': weekday,
        'startMinutes': startMinutes,
        'durationMinutes': durationMinutes,
        'completed': completed,
        if (scheduledDate != null)
          'scheduledDate': _dateKey(scheduledDate!),
      };

  factory StudySession.fromJson(Map<String, dynamic> json) {
    final rawDate = json['scheduledDate'];
    final parsedDate = rawDate is String ? DateTime.tryParse(rawDate) : null;
    final date = parsedDate == null ? null : dateOnly(parsedDate);
    final weekday = date == null
        ? ((json['weekday'] as num?)?.toInt() ?? 0).clamp(0, 6).toInt()
        : weekdayFor(date);
    final startMinutes = ((json['startMinutes'] as num?)?.toInt() ?? 960)
        .clamp(0, 1439).toInt();
    final durationMinutes = ((json['durationMinutes'] as num?)?.toInt() ?? 55)
        .clamp(1, 1440 - startMinutes).toInt();

    return StudySession(
      id: json['id'] as String,
      title: json['title'] as String,
      subject: json['subject'] as String? ?? 'عمومی',
      weekday: weekday,
      startMinutes: startMinutes,
      durationMinutes: durationMinutes,
      completed: json['completed'] as bool? ?? false,
      scheduledDate: date,
    );
  }
}

String _dateKey(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

/// Returns true when two study sessions overlap on the same calendar date.
bool studySessionsOverlap(StudySession first, StudySession second) {
  final sameDay = first.scheduledDate != null && second.scheduledDate != null
      ? StudySession.dateOnly(first.scheduledDate!) ==
          StudySession.dateOnly(second.scheduledDate!)
      : first.weekday == second.weekday;
  return sameDay &&
      first.startMinutes < second.startMinutes + second.durationMinutes &&
      second.startMinutes < first.startMinutes + first.durationMinutes;
}

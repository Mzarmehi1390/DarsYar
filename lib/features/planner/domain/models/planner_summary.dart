import 'study_session.dart';

/// Immutable aggregate calculations shared by the study planner UI.
class PlannerSummary {
  PlannerSummary._({
    required this.totalSessionCount,
    required this.completedSessionCount,
    required this.plannedMinutes,
    required this.completedMinutes,
    required Map<int, List<StudySession>> sessionsByDay,
    required Map<int, int> minutesByDay,
  })  : _sessionsByDay = Map<int, List<StudySession>>.unmodifiable(
          sessionsByDay.map(
            (day, items) => MapEntry(
              day,
              List<StudySession>.unmodifiable(items),
            ),
          ),
        ),
        _minutesByDay = Map<int, int>.unmodifiable(minutesByDay);

  factory PlannerSummary.fromSessions(Iterable<StudySession> sessions) {
    var totalCount = 0;
    final sessionsByDay = <int, List<StudySession>>{};
    final minutesByDay = <int, int>{};
    var completedCount = 0;
    var planned = 0;
    var completed = 0;

    // Aggregate the complete planner in one pass. The UI can then reuse
    // immutable day buckets instead of filtering the full list on every build.
    for (final session in sessions) {
      totalCount++;
      planned += session.durationMinutes;
      if (session.completed) {
        completedCount++;
        completed += session.durationMinutes;
      }

      final day = session.scheduledDate == null
          ? session.weekday
          : StudySession.weekdayFor(session.scheduledDate!);
      (sessionsByDay[day] ??= <StudySession>[]).add(session);
      minutesByDay.update(
        day,
        (minutes) => minutes + session.durationMinutes,
        ifAbsent: () => session.durationMinutes,
      );
    }

    for (final daySessions in sessionsByDay.values) {
      daySessions.sort(
        (a, b) => a.startMinutes.compareTo(b.startMinutes),
      );
    }

    return PlannerSummary._(
      totalSessionCount: totalCount,
      completedSessionCount: completedCount,
      plannedMinutes: planned,
      completedMinutes: completed,
      sessionsByDay: sessionsByDay,
      minutesByDay: minutesByDay,
    );
  }

  final int totalSessionCount;
  final Map<int, List<StudySession>> _sessionsByDay;
  final Map<int, int> _minutesByDay;
  final int completedSessionCount;
  final int plannedMinutes;
  final int completedMinutes;

  double get completion =>
      plannedMinutes == 0 ? 0 : completedMinutes / plannedMinutes;

  List<StudySession> sessionsForDay(int weekday) =>
      _sessionsByDay[weekday] ?? const <StudySession>[];

  int minutesForDay(int weekday) => _minutesByDay[weekday] ?? 0;
}

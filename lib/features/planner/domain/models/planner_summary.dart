import 'study_session.dart';

/// Immutable aggregate calculations shared by the study planner UI.
class PlannerSummary {
  PlannerSummary._(List<StudySession> sessions)
      : _sessions = List<StudySession>.unmodifiable(sessions),
        completedSessionCount =
            sessions.where((session) => session.completed).length,
        plannedMinutes = sessions.fold<int>(
          0,
          (total, session) => total + session.durationMinutes,
        ),
        completedMinutes = sessions
            .where((session) => session.completed)
            .fold<int>(
              0,
              (total, session) => total + session.durationMinutes,
            );

  factory PlannerSummary.fromSessions(Iterable<StudySession> sessions) =>
      PlannerSummary._(sessions.toList(growable: false));

  final List<StudySession> _sessions;
  final int completedSessionCount;
  final int plannedMinutes;
  final int completedMinutes;

  double get completion =>
      plannedMinutes == 0 ? 0 : completedMinutes / plannedMinutes;

  List<StudySession> sessionsForDay(int weekday) {
    final result = _sessions
        .where((session) => session.weekday == weekday)
        .toList(growable: false)
      ..sort((a, b) => a.startMinutes.compareTo(b.startMinutes));
    return List<StudySession>.unmodifiable(result);
  }

  int minutesForDay(int weekday) => _sessions
      .where((session) => session.weekday == weekday)
      .fold<int>(0, (total, session) => total + session.durationMinutes);
}

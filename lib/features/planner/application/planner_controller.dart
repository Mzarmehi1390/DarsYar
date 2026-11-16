import '../../../study_session.dart';
import '../domain/planner_calendar.dart';

/// Encapsulates planner scheduling rules independently from Flutter widgets.
class PlannerController {
  const PlannerController();

  void toggleCompletion(List<StudySession> sessions, String id) {
    final index = sessions.indexWhere((session) => session.id == id);
    if (index < 0) return;
    final session = sessions[index];
    sessions[index] = session.copyWith(completed: !session.completed);
  }

  void upsert(List<StudySession> sessions, StudySession session) {
    final index = sessions.indexWhere((item) => item.id == session.id);
    if (index < 0) {
      sessions.add(session);
    } else {
      sessions[index] = session;
    }
  }

  void removeById(List<StudySession> sessions, String id) {
    sessions.removeWhere((session) => session.id == id);
  }

  List<StudySession> migrateLegacySessions(
    Iterable<StudySession> sessions, {
    required DateTime referenceDate,
  }) {
    final weekStart = PlannerCalendar.startOfWeek(referenceDate);
    return sessions.map((session) {
      if (session.scheduledDate != null) return session;
      return session.copyWith(
        scheduledDate: PlannerCalendar.migrateLegacyDate(
          session.weekday,
          weekStart,
        ),
      );
    }).toList();
  }

  List<StudySession> sessionsForDate(
    Iterable<StudySession> sessions,
    DateTime date,
  ) {
    final target = PlannerCalendar.dateOnly(date);
    final result = sessions.where((session) {
      final scheduled = session.scheduledDate;
      return scheduled != null && PlannerCalendar.dateOnly(scheduled) == target;
    }).toList()
      ..sort((a, b) => a.startMinutes.compareTo(b.startMinutes));
    return result;
  }

  /// Filters against one precomputed week range rather than normalizing the
  /// week start for every session. This also makes the occurrence date, not
  /// the legacy weekday field, the source of truth.
  List<StudySession> sessionsForWeek(
    Iterable<StudySession> sessions,
    DateTime weekStart,
  ) {
    final start = PlannerCalendar.startOfWeek(weekStart);
    final end = start.add(const Duration(days: 7));
    return sessions.where((session) {
      final scheduled = session.scheduledDate;
      if (scheduled == null) return false;
      final date = PlannerCalendar.dateOnly(scheduled);
      return !date.isBefore(start) && date.isBefore(end);
    }).toList();
  }

  List<StudySession> sessionsForDay(
    Iterable<StudySession> sessions,
    int weekday,
  ) {
    final result = sessions
        .where((session) => session.weekday == weekday)
        .toList()
      ..sort((a, b) => a.startMinutes.compareTo(b.startMinutes));
    return result;
  }

  bool hasOverlap(
    Iterable<StudySession> sessions,
    StudySession candidate, {
    String? excludingId,
  }) {
    return sessions.any((session) {
      if (session.id == excludingId) return false;

      final candidateDate = candidate.scheduledDate;
      final sessionDate = session.scheduledDate;
      if (candidateDate != null && sessionDate != null) {
        if (PlannerCalendar.dateOnly(candidateDate) !=
            PlannerCalendar.dateOnly(sessionDate)) {
          return false;
        }
      } else if (session.weekday != candidate.weekday) {
        return false;
      }

      return studySessionsOverlap(candidate, session);
    });
  }

  List<StudySession> copyDay({
    required Iterable<StudySession> sessions,
    required int sourceDay,
    required int targetDay,
    required String Function(StudySession source) createId,
    DateTime? targetDate,
  }) {
    return sessionsForDay(sessions, sourceDay)
        .map(
          (session) => StudySession(
            id: createId(session),
            title: session.title,
            subject: session.subject,
            weekday: targetDate == null
                ? targetDay
                : StudySession.weekdayFor(targetDate),
            startMinutes: session.startMinutes,
            durationMinutes: session.durationMinutes,
            scheduledDate: targetDate,
          ),
        )
        .toList();
  }
}

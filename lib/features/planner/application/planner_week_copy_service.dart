import '../domain/planner_calendar.dart';
import '../domain/models/study_session.dart';
import '../domain/models/study_task.dart';

/// Builds a pure, immutable plan for duplicating one planner week into the next.
///
/// This service does not mutate live app collections or decide whether
/// existing destination data should be replaced; those are UI orchestration
/// concerns and must be confirmed by the user.
class PlannerWeekCopyService {
  const PlannerWeekCopyService();

  PlannerWeekCopyPlan createNextWeekPlan({
    required Iterable<StudySession> sessions,
    required Iterable<StudyTask> tasks,
    required DateTime sourceWeekStart,
    required String Function(StudySession source) createSessionId,
    required String Function(StudyTask source) createTaskId,
  }) {
    final sourceStart = PlannerCalendar.startOfWeek(sourceWeekStart);
    final targetStart = sourceStart.add(const Duration(days: 7));
    final sourceSessions = sessions.where((session) =>
      session.scheduledDate != null &&
      PlannerCalendar.isInWeek(session.scheduledDate!, sourceStart)
    ).toList(growable: false);
    final sourceTasks = tasks.where((task) =>
      task.dueDate != null &&
      PlannerCalendar.isInWeek(task.dueDate!, sourceStart)
    ).toList(growable: false);

    final copiedSessions = sourceSessions.map((session) {
      final sourceDate = session.scheduledDate!;
      return StudySession(
        id: createSessionId(session),
        title: session.title,
        subject: session.subject,
        weekday: session.weekday,
        startMinutes: session.startMinutes,
        durationMinutes: session.durationMinutes,
        scheduledDate: sourceDate.add(const Duration(days: 7)),
      );
    }).toList(growable: false);
    final copiedTasks = sourceTasks.map((task) => StudyTask(
      createTaskId(task),
      task.title,
      task.subject,
      dueDate: task.dueDate!.add(const Duration(days: 7)),
    )).toList(growable: false);

    return PlannerWeekCopyPlan(
      sourceWeekStart: sourceStart,
      targetWeekStart: targetStart,
      sourceSessions: sourceSessions,
      sourceTasks: sourceTasks,
      copiedSessions: copiedSessions,
      copiedTasks: copiedTasks,
    );
  }
}

class PlannerWeekCopyPlan {
  PlannerWeekCopyPlan({
    required this.sourceWeekStart,
    required this.targetWeekStart,
    required List<StudySession> sourceSessions,
    required List<StudyTask> sourceTasks,
    required List<StudySession> copiedSessions,
    required List<StudyTask> copiedTasks,
  })  : sourceSessions = List.unmodifiable(sourceSessions),
        sourceTasks = List.unmodifiable(sourceTasks),
        copiedSessions = List.unmodifiable(copiedSessions),
        copiedTasks = List.unmodifiable(copiedTasks);

  final DateTime sourceWeekStart;
  final DateTime targetWeekStart;
  final List<StudySession> sourceSessions;
  final List<StudyTask> sourceTasks;
  final List<StudySession> copiedSessions;
  final List<StudyTask> copiedTasks;
}

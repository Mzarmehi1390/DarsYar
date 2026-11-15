import 'package:flutter_test/flutter_test.dart';
import 'package:dars_yar/features/planner/application/planner_week_copy_service.dart';
import 'package:dars_yar/features/planner/domain/models/study_session.dart';
import 'package:dars_yar/features/planner/domain/models/study_task.dart';

void main() {
  const service = PlannerWeekCopyService();

  test('copies only dated items from source week and resets completion', () {
    final monday = DateTime(2026, 11, 16);
    final nextMonday = DateTime(2026, 11, 23);
    final sourceSession = StudySession(
      id: 'session-source',
      title: 'مطالعه',
      subject: 'ریاضی',
      weekday: 1,
      startMinutes: 600,
      durationMinutes: 45,
      scheduledDate: monday,
      completed: true,
    );
    final nextWeekSession = StudySession(
      id: 'session-next',
      title: 'هفته بعد',
      subject: 'فیزیک',
      weekday: 1,
      startMinutes: 720,
      durationMinutes: 30,
      scheduledDate: nextMonday,
    );
    final sourceTask = StudyTask(
      'task-source',
      'تمرین',
      'شیمی',
      done: true,
      dueDate: monday,
    );
    final undatedTask = StudyTask('task-backlog', 'بدون تاریخ', 'عمومی');

    final plan = service.createNextWeekPlan(
      sessions: [sourceSession, nextWeekSession],
      tasks: [sourceTask, undatedTask],
      sourceWeekStart: DateTime(2026, 11, 18),
      createSessionId: (item) => 'copy-${item.id}',
      createTaskId: (item) => 'copy-${item.id}',
    );

    expect(plan.sourceWeekStart, DateTime(2026, 11, 14));
    expect(plan.targetWeekStart, DateTime(2026, 11, 21));
    expect(plan.sourceSessions, [sourceSession]);
    expect(plan.sourceTasks, [sourceTask]);
    expect(plan.copiedSessions.single.scheduledDate, nextMonday);
    expect(plan.copiedSessions.single.completed, isFalse);
    expect(plan.copiedTasks.single.dueDate, nextMonday);
    expect(plan.copiedTasks.single.done, isFalse);
    expect(plan.copiedSessions.single.id, 'copy-session-source');
    expect(plan.copiedTasks.single.id, 'copy-task-source');
  });

  test('empty source week produces an empty immutable plan', () {
    final plan = service.createNextWeekPlan(
      sessions: const [],
      tasks: const [],
      sourceWeekStart: DateTime(2026, 11, 14),
      createSessionId: (_) => 'unused-session',
      createTaskId: (_) => 'unused-task',
    );

    expect(plan.copiedSessions, isEmpty);
    expect(plan.copiedTasks, isEmpty);
  });
}

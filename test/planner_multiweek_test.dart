import 'package:flutter_test/flutter_test.dart';
import 'package:dars_yar/features/planner/application/planner_controller.dart';
import 'package:dars_yar/features/planner/domain/planner_calendar.dart';
import 'package:dars_yar/models/study_task.dart';
import 'package:dars_yar/study_session.dart';

void main() {
  const planner = PlannerController();

  StudySession makeSession(String id, DateTime date, {int start = 600, bool done = false}) =>
      StudySession(
        id: id,
        title: 'مطالعه',
        subject: 'ریاضی',
        weekday: StudySession.weekdayFor(date),
        startMinutes: start,
        durationMinutes: 60,
        scheduledDate: date,
        completed: done,
      );

  test('legacy weekday-only sessions migrate into the current Saturday week', () {
    const legacy = StudySession(
      id: 'old',
      title: 'جلسه قدیمی',
      subject: 'علوم',
      weekday: 1,
      startMinutes: 600,
      durationMinutes: 45,
    );
    final migrated = planner.migrateLegacySessions(
      [legacy],
      referenceDate: DateTime(2026, 11, 18),
    ).single;

    expect(migrated.id, legacy.id);
    expect(migrated.title, legacy.title);
    expect(migrated.scheduledDate, DateTime(2026, 11, 16));
    expect(migrated.weekday, 1);
  });

  test('same weekday in different weeks has independent sessions and conflicts', () {
    final thisWeek = makeSession('this-week', DateTime(2026, 11, 16));
    final nextWeek = makeSession('next-week', DateTime(2026, 11, 23));
    expect(planner.hasOverlap([thisWeek], nextWeek), isFalse);
    expect(planner.sessionsForWeek([thisWeek, nextWeek], DateTime(2026, 11, 14)), [thisWeek]);
    expect(planner.sessionsForWeek([thisWeek, nextWeek], DateTime(2026, 11, 21)), [nextWeek]);
  });

  test('sessions on the same date still reject overlapping times', () {
    final first = makeSession('first', DateTime(2026, 11, 16));
    final overlap = makeSession('overlap', DateTime(2026, 11, 16), start: 630);
    expect(planner.hasOverlap([first], overlap), isTrue);
  });

  test('copying a day to another week preserves details and resets completion', () {
    final source = makeSession('source', DateTime(2026, 11, 16), done: true);
    final copies = planner.copyDay(
      sessions: [source],
      sourceDay: source.weekday,
      targetDay: source.weekday,
      targetDate: DateTime(2026, 11, 23),
      createId: (_) => 'copied',
    );
    expect(copies.single.scheduledDate, DateTime(2026, 11, 23));
    expect(copies.single.title, source.title);
    expect(copies.single.completed, isFalse);
  });

  test('date-based tasks round-trip while legacy tasks remain unscheduled', () {
    final task = StudyTask('t1', 'تمرین', 'فیزیک', dueDate: DateTime(2026, 11, 23));
    final restored = StudyTask.fromJson(task.toJson());
    expect(restored.dueDate, DateTime(2026, 11, 23));
    final legacy = StudyTask.fromJson({'id': 'old', 'title': 'وظیفه', 'subject': 'ریاضی'});
    expect(legacy.dueDate, isNull);
  });

  test('week boundaries remain Saturday through Friday across year changes', () {
    expect(PlannerCalendar.startOfWeek(DateTime(2026, 12, 31)), DateTime(2026, 12, 26));
    expect(PlannerCalendar.startOfWeek(DateTime(2027, 1, 1)), DateTime(2026, 12, 26));
  });
}

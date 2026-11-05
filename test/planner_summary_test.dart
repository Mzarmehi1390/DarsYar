import 'package:flutter_test/flutter_test.dart';
import 'package:dars_yar/planner_summary.dart';
import 'package:dars_yar/study_session.dart';

void main() {
  const sessions = [
    StudySession(id: 'late', title: 'دوم', subject: 'ریاضی', weekday: 2, startMinutes: 700, durationMinutes: 40),
    StudySession(id: 'done', title: 'اول', subject: 'علوم', weekday: 2, startMinutes: 600, durationMinutes: 30, completed: true),
    StudySession(id: 'other', title: 'روز دیگر', subject: 'فارسی', weekday: 3, startMinutes: 500, durationMinutes: 20),
  ];

  test('aggregates weekly counts, minutes and completion safely', () {
    final summary = PlannerSummary.fromSessions(sessions);
    expect(summary.totalSessionCount, 3);
    expect(summary.completedSessionCount, 1);
    expect(summary.plannedMinutes, 90);
    expect(summary.completedMinutes, 30);
    expect(summary.completion, closeTo(1 / 3, 0.0001));
  });

  test('returns selected-day sessions in chronological order', () {
    final summary = PlannerSummary.fromSessions(sessions);
    expect(summary.sessionsForDay(2).map((session) => session.id), ['done', 'late']);
    expect(summary.minutesForDay(2), 70);
    expect(summary.sessionsForDay(1), isEmpty);
  });

  test('empty planner has zero progress and no sessions', () {
    final summary = PlannerSummary.fromSessions(const []);
    expect(summary.plannedMinutes, 0);
    expect(summary.completedMinutes, 0);
    expect(summary.completion, 0);
    expect(summary.totalSessionCount, 0);
    expect(summary.completedSessionCount, 0);
  });
}

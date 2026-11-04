import 'package:flutter_test/flutter_test.dart';
import 'package:dars_yar/features/planner/application/planner_controller.dart';
import 'package:dars_yar/study_session.dart';

void main() {
  const planner = PlannerController();

  StudySession session({
    required String id,
    required int weekday,
    required int start,
    int duration = 45,
  }) =>
      StudySession(
        id: id,
        title: 'مطالعه',
        subject: 'ریاضی',
        weekday: weekday,
        startMinutes: start,
        durationMinutes: duration,
      );

  test('sessionsForDay filters and sorts sessions by start time', () {
    final sessions = [
      session(id: 'late', weekday: 1, start: 900),
      session(id: 'other-day', weekday: 2, start: 400),
      session(id: 'early', weekday: 1, start: 500),
    ];

    expect(
      planner.sessionsForDay(sessions, 1).map((item) => item.id).toList(),
      ['early', 'late'],
    );
  });

  test('hasOverlap ignores other days and supports excluding an edited item', () {
    final existing = session(id: 'existing', weekday: 1, start: 600);
    final sameTime = session(id: 'candidate', weekday: 1, start: 620);
    final otherDay = session(id: 'other', weekday: 2, start: 620);

    expect(planner.hasOverlap([existing], sameTime), isTrue);
    expect(planner.hasOverlap([existing], otherDay), isFalse);
    expect(
      planner.hasOverlap([existing], sameTime, excludingId: 'existing'),
      isFalse,
    );
  });

  test('copyDay preserves lesson details and resets completion state', () {
    final source = session(id: 'source', weekday: 1, start: 540);
    final copies = planner.copyDay(
      sessions: [source],
      sourceDay: 1,
      targetDay: 4,
      createId: (item) => 'copy-${item.id}',
    );

    expect(copies, hasLength(1));
    expect(copies.single.id, 'copy-source');
    expect(copies.single.weekday, 4);
    expect(copies.single.startMinutes, 540);
    expect(copies.single.title, source.title);
    expect(copies.single.subject, source.subject);
    expect(copies.single.completed, isFalse);
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:dars_yar/study_session.dart';

void main() {
  const session = StudySession(
    id: 'session-1',
    title: 'مرور فصل اول',
    subject: 'ریاضی',
    weekday: 2,
    startMinutes: 16 * 60 + 30,
    durationMinutes: 55,
    completed: true,
  );

  test('serializes and restores a study session', () {
    expect(StudySession.fromJson(session.toJson()).toJson(), session.toJson());
  });

  test('uses safe defaults for optional legacy fields', () {
    final restored = StudySession.fromJson({
      'id': 'legacy',
      'title': 'مرور',
    });
    expect(restored.subject, 'عمومی');
    expect(restored.weekday, 0);
    expect(restored.startMinutes, 960);
    expect(restored.durationMinutes, 55);
    expect(restored.completed, isFalse);
  });

  test('copyWith changes completion without changing schedule', () {
    final updated = session.copyWith(completed: false);
    expect(updated.completed, isFalse);
    expect(updated.title, session.title);
    expect(updated.startMinutes, session.startMinutes);
    final rescheduled = session.copyWith(title: 'تمرین جدید', weekday: 5, startMinutes: 600, durationMinutes: 45);
    expect(rescheduled.title, 'تمرین جدید');
    expect(rescheduled.weekday, 5);
    expect(rescheduled.startMinutes, 600);
    expect(rescheduled.durationMinutes, 45);
    expect(rescheduled.completed, session.completed);
  });

  test('detects overlapping sessions only on the same day', () {
    const first = StudySession(id: 'a', title: 'اول', subject: 'ریاضی', weekday: 1, startMinutes: 600, durationMinutes: 55);
    const overlap = StudySession(id: 'b', title: 'دوم', subject: 'علوم', weekday: 1, startMinutes: 640, durationMinutes: 30);
    const touchesEnd = StudySession(id: 'c', title: 'سوم', subject: 'علوم', weekday: 1, startMinutes: 655, durationMinutes: 30);
    const anotherDay = StudySession(id: 'd', title: 'چهارم', subject: 'علوم', weekday: 2, startMinutes: 640, durationMinutes: 30);
    expect(studySessionsOverlap(first, overlap), isTrue);
    expect(studySessionsOverlap(first, touchesEnd), isFalse);
    expect(studySessionsOverlap(first, anotherDay), isFalse);
  });
  test('clamps restored duration so a session cannot cross midnight', () {
    final restored = StudySession.fromJson({
      'id': 'late-session',
      'title': 'مطالعه شبانه',
      'weekday': 6,
      'startMinutes': 1430,
      'durationMinutes': 120,
    });

    expect(restored.startMinutes, 1430);
    expect(restored.durationMinutes, 10);
    expect(restored.startMinutes + restored.durationMinutes, 1440);
  });

}

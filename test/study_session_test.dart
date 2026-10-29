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
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:dars_yar/features/settings/application/backup_service.dart';
import 'package:dars_yar/features/planner/domain/models/study_session.dart';
import 'package:dars_yar/features/planner/domain/models/study_task.dart';
import 'package:dars_yar/features/exams/domain/models/exam_sheet.dart';

void main() {
  const service = DarsYarBackupService();

  test('backup service round-trips typed collections and active exam', () {
    final task = StudyTask(
      'task-1',
      'تمرین',
      'ریاضی',
      dueDate: DateTime(2026, 11, 23),
    );
    final session = StudySession(
      id: 'session-1',
      title: 'مطالعه',
      subject: 'فیزیک',
      weekday: 1,
      startMinutes: 600,
      durationMinutes: 45,
      scheduledDate: DateTime(2026, 11, 23),
    );
    final exam = ExamSheet(id: 'exam-1', name: 'آزمون اول');

    final raw = service.encode(
      activeExamId: exam.id,
      tasks: [task],
      studySessions: [session],
      exams: [exam],
      results: const [],
      exportedAt: DateTime.utc(2026, 11, 15),
    );
    final restored = service.decode(
      raw,
      referenceDate: DateTime(2026, 11, 18),
    );

    expect(restored.activeExamId, 'exam-1');
    expect(restored.tasks.single.dueDate, DateTime(2026, 11, 23));
    expect(restored.studySessions.single.scheduledDate, DateTime(2026, 11, 23));
    expect(restored.exams.single.name, 'آزمون اول');
    expect(restored.results, isEmpty);
  });

  test('legacy sessions migrate during decoding without changing other data', () {
    final legacySession = StudySession(
      id: 'legacy-session',
      title: 'جلسه قدیمی',
      subject: 'علوم',
      weekday: 1,
      startMinutes: 540,
      durationMinutes: 30,
    );
    final exam = ExamSheet(id: 'exam-1', name: 'آزمون');

    final raw = service.encode(
      activeExamId: exam.id,
      tasks: const [],
      studySessions: [legacySession],
      exams: [exam],
      results: const [],
      exportedAt: DateTime.utc(2026, 11, 15),
    );
    final restored = service.decode(
      raw,
      referenceDate: DateTime(2026, 11, 18),
    );

    expect(restored.studySessions.single.id, legacySession.id);
    expect(restored.studySessions.single.scheduledDate, DateTime(2026, 11, 16));
    expect(restored.studySessions.single.title, legacySession.title);
  });

  test('invalid backup is rejected before producing a snapshot', () {
    expect(() => service.decode('{invalid'), throwsFormatException);
  });
}

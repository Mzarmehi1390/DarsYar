import 'package:flutter_test/flutter_test.dart';
import 'package:dars_yar/answer_scoring.dart';
import 'package:dars_yar/backup_codec.dart';
import 'package:dars_yar/exam_result.dart';
import 'package:dars_yar/exam_sheet.dart';
import 'package:dars_yar/study_session.dart';

void main() {
  test('backup round-trip preserves tasks, schedules, exam answers and results', () {
    final task = <String, dynamic>{
      'id': 'task-1',
      'title': 'مرور فصل اول',
      'subject': 'علوم',
      'done': true,
    };
    final session = StudySession(
      id: 'session-1',
      title: 'مطالعه علوم',
      subject: 'علوم',
      weekday: 2,
      startMinutes: 960,
      durationMinutes: 55,
      completed: true,
    );
    final exam = ExamSheet(
      id: 'exam-1',
      name: 'آزمون فصل اول',
      questionCount: 4,
      durationSeconds: 1800,
      negativeMarking: true,
      isCompleted: true,
      answers: const {1: 0, 2: 2},
      answerKey: const {1: 0, 2: 1, 3: 2},
      marked: const {4},
    );
    final score = calculateAnswerScore(
      answers: exam.answers,
      answerKey: exam.answerKey,
      questionCount: exam.questionCount,
      negativeMarking: exam.negativeMarking,
    );
    final result = ExamResult(
      id: 'result-1',
      examId: exam.id,
      examName: exam.name,
      completedAt: '2026-10-30T12:00:00.000Z',
      questionCount: exam.questionCount,
      correct: score.correct,
      wrong: score.wrong,
      unanswered: score.unanswered,
      keyedQuestions: score.keyedQuestions,
      percentage: score.percentage,
      negativeMarking: exam.negativeMarking,
      answers: exam.answers,
      answerKey: exam.answerKey,
    );

    final payload = DarsYarBackupCodec.createPayload(
      exportedAt: '2026-10-30T12:00:00.000Z',
      activeExamId: exam.id,
      tasks: [task],
      studySessions: [session.toJson()],
      exams: [exam.toJson()],
      results: [result.toJson()],
    );

    final restored = DarsYarBackupCodec.decode(
      DarsYarBackupCodec.encode(payload),
    );
    final restoredSession = StudySession.fromJson(
      Map<String, dynamic>.from((restored['studySessions'] as List).single as Map),
    );
    final restoredExam = ExamSheet.fromJson(
      Map<String, dynamic>.from((restored['exams'] as List).single as Map),
    );
    final restoredResult = ExamResult.fromJson(
      Map<String, dynamic>.from((restored['results'] as List).single as Map),
    );

    expect(restored['activeExamId'], exam.id);
    expect(restored['tasks'], [task]);
    expect(restoredSession.toJson(), session.toJson());
    expect(restoredExam.toJson(), exam.toJson());
    expect(restoredResult.toJson(), result.toJson());
  });
}

import '../../../backup_codec.dart';
import '../../planner/application/planner_controller.dart';
import '../../planner/domain/models/study_session.dart';
import '../../planner/domain/models/study_task.dart';
import '../../exams/domain/models/exam_result.dart';
import '../../exams/domain/models/exam_sheet.dart';

/// Typed, feature-level boundary for exporting and restoring app backups.
///
/// The UI owns confirmation and persistence rollback. This service owns
/// serialization, validation, model decoding, and legacy schedule migration.
class DarsYarBackupService {
  const DarsYarBackupService({
    this._plannerController = const PlannerController(),
  });

  final PlannerController _plannerController;

  String encode({
    required String activeExamId,
    required Iterable<StudyTask> tasks,
    required Iterable<StudySession> studySessions,
    required Iterable<ExamSheet> exams,
    required Iterable<ExamResult> results,
    DateTime? exportedAt,
  }) {
    final payload = DarsYarBackupCodec.createPayload(
      exportedAt: (exportedAt ?? DateTime.now()).toUtc().toIso8601String(),
      activeExamId: activeExamId,
      tasks: tasks.map((item) => item.toJson()).toList(growable: false),
      studySessions: studySessions.map((item) => item.toJson()).toList(growable: false),
      exams: exams.map((item) => item.toJson()).toList(growable: false),
      results: results.map((item) => item.toJson()).toList(growable: false),
    );
    return DarsYarBackupCodec.encode(payload);
  }

  /// Decodes a validated backup into typed models without mutating app state.
  ///
  /// Legacy weekday-only sessions are assigned dates in [referenceDate]'s
  /// Saturday-based week, preserving the previous import behavior.
  DarsYarBackupSnapshot decode(
    String raw, {
    DateTime? referenceDate,
  }) {
    final payload = DarsYarBackupCodec.decode(raw);

    List<T> decodeCollection<T>(
      String key,
      T Function(Map<String, dynamic>) fromJson,
    ) {
      final records = payload[key] as List<dynamic>;
      return records
          .map((record) => fromJson(Map<String, dynamic>.from(record as Map)))
          .toList(growable: false);
    }

    final tasks = decodeCollection('tasks', StudyTask.fromJson);
    final sessions = decodeCollection('studySessions', StudySession.fromJson);
    final exams = decodeCollection('exams', ExamSheet.fromJson);
    final results = decodeCollection('results', ExamResult.fromJson);
    final migratedSessions = _plannerController.migrateLegacySessions(
      sessions,
      referenceDate: referenceDate ?? DateTime.now(),
    );

    return DarsYarBackupSnapshot(
      tasks: tasks,
      studySessions: migratedSessions,
      exams: exams,
      results: results,
      activeExamId: payload['activeExamId'] as String,
    );
  }
}

/// Fully decoded backup data. Collections are immutable snapshots.
class DarsYarBackupSnapshot {
  DarsYarBackupSnapshot({
    required List<StudyTask> tasks,
    required List<StudySession> studySessions,
    required List<ExamSheet> exams,
    required List<ExamResult> results,
    required this.activeExamId,
  })  : tasks = List.unmodifiable(tasks),
        studySessions = List.unmodifiable(studySessions),
        exams = List.unmodifiable(exams),
        results = List.unmodifiable(results);

  final List<StudyTask> tasks;
  final List<StudySession> studySessions;
  final List<ExamSheet> exams;
  final List<ExamResult> results;
  final String activeExamId;
}

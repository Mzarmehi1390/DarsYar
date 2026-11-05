import 'dart:convert';

import '../../darsyar_storage.dart';
import '../../features/exams/domain/models/exam_result.dart';
import '../../features/exams/domain/models/exam_sheet.dart';
import '../../features/planner/domain/models/study_task.dart';
import '../../features/planner/domain/models/study_session.dart';

/// Immutable result of restoring the app's persisted feature collections.
class DarsYarAppSnapshot {
  const DarsYarAppSnapshot({
    required this.tasks,
    required this.studySessions,
    required this.exams,
    required this.results,
    required this.activeExamId,
  });

  final List<StudyTask> tasks;
  final List<StudySession> studySessions;
  final List<ExamSheet> exams;
  final List<ExamResult> results;
  final String activeExamId;
}

/// App-level persistence boundary.
///
/// Widgets and feature presentation code work with typed models; JSON
/// compatibility, legacy migration and storage keys stay in this data layer.
class DarsYarRepository {
  DarsYarRepository({DarsYarStorage? storage})
      : _storage = storage ?? DarsYarStorage();

  final DarsYarStorage _storage;

  static const allSections = <String>{
    'tasks',
    'exams',
    'activeExam',
    'results',
    'studySessions',
  };

  Future<DarsYarAppSnapshot> load() async {
    final stored = await _storage.readSnapshot();
    final tasks = _decodeCollection(
      stored.stringValue('darsyar.tasks'),
      StudyTask.fromJson,
    );
    final sessions = _decodeCollection(
      stored.stringValue('darsyar.studySessions'),
      StudySession.fromJson,
    );
    final results = _decodeCollection(
      stored.stringValue('darsyar.results'),
      ExamResult.fromJson,
    );

    final storedExamsJson = stored.stringValue('darsyar.exams');
    final hasStoredExamsKey = stored.containsKey('darsyar.exams');
    var exams = _decodeCollection(storedExamsJson, ExamSheet.fromJson);

    if (exams.isEmpty && !hasStoredExamsKey) {
      // Migrate legacy single-sheet data only when the current-format key
      // does not exist. Corrupt current data must not resurrect stale answers.
      final markedValues = _decodeList(stored.stringValue('darsyar.marked'));
      final marked = <int>{
        for (final value in markedValues)
          if (value is num) value.toInt(),
      };
      exams = [
        ExamSheet(
          id: 'default',
          name: 'آزمون اول',
          questionCount:
              (stored.intValue('darsyar.count') ?? 20).clamp(1, 200).toInt(),
          answers: _decodeIntMap(stored.stringValue('darsyar.answers')),
          answerKey: _decodeIntMap(stored.stringValue('darsyar.answerKey')),
          marked: marked,
        ),
      ];
    }

    if (exams.isEmpty) {
      exams = [ExamSheet(id: 'default', name: 'آزمون اول')];
    }
    final requestedActiveId =
        stored.stringValue('darsyar.activeExamId') ?? exams.first.id;
    final activeExamId = exams.any((exam) => exam.id == requestedActiveId)
        ? requestedActiveId
        : exams.first.id;

    return DarsYarAppSnapshot(
      tasks: tasks,
      studySessions: sessions,
      exams: exams,
      results: results,
      activeExamId: activeExamId,
    );
  }

  Future<bool> save({
    required Set<String> sections,
    required List<StudyTask> tasks,
    required List<StudySession> studySessions,
    required List<ExamSheet> exams,
    required List<ExamResult> results,
    required String activeExamId,
  }) async {
    if (sections.isEmpty) return true;
    if (!allSections.containsAll(sections)) {
      throw ArgumentError.value(
        sections,
        'sections',
        'Unknown storage section',
      );
    }

    final values = <String, String>{
      if (sections.contains('tasks'))
        'darsyar.tasks': jsonEncode(tasks.map((item) => item.toJson()).toList()),
      if (sections.contains('exams'))
        'darsyar.exams': jsonEncode(exams.map((item) => item.toJson()).toList()),
      if (sections.contains('activeExam')) 'darsyar.activeExamId': activeExamId,
      if (sections.contains('results'))
        'darsyar.results':
            jsonEncode(results.map((item) => item.toJson()).toList()),
      if (sections.contains('studySessions'))
        'darsyar.studySessions':
            jsonEncode(studySessions.map((item) => item.toJson()).toList()),
    };
    return _storage.writeStrings(values);
  }

  List<T> _decodeCollection<T>(
    String? raw,
    T Function(Map<String, dynamic>) fromJson,
  ) {
    final values = _decodeList(raw);
    final decoded = <T>[];
    for (final value in values) {
      try {
        if (value is Map) {
          decoded.add(fromJson(Map<String, dynamic>.from(value)));
        }
      } catch (_) {
        // A malformed record must not hide valid records in the same section.
      }
    }
    return decoded;
  }

  List<dynamic> _decodeList(String? raw) {
    if (raw == null) return const [];
    try {
      final decoded = jsonDecode(raw);
      return decoded is List ? decoded : const [];
    } catch (_) {
      return const [];
    }
  }

  Map<int, int> _decodeIntMap(String? raw) {
    if (raw == null) return <int, int>{};
    try {
      final map = Map<String, dynamic>.from(jsonDecode(raw) as Map);
      return map.map(
        (key, value) => MapEntry(int.parse(key), (value as num).toInt()),
      );
    } catch (_) {
      return <int, int>{};
    }
  }
}

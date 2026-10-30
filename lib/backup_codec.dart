import 'dart:convert';

/// Encodes and validates the versioned, portable DarsYar JSON backup format.
class DarsYarBackupCodec {
  const DarsYarBackupCodec._();

  static const appName = 'DarsYar';
  static const schemaVersion = 1;
  static const _listKeys = ['tasks', 'studySessions', 'exams', 'results'];

  static Map<String, dynamic> createPayload({
    required String exportedAt,
    required String activeExamId,
    required List<Map<String, dynamic>> tasks,
    required List<Map<String, dynamic>> studySessions,
    required List<Map<String, dynamic>> exams,
    required List<Map<String, dynamic>> results,
  }) => {
        'app': appName,
        'schemaVersion': schemaVersion,
        'exportedAt': exportedAt,
        'activeExamId': activeExamId,
        'tasks': tasks,
        'studySessions': studySessions,
        'exams': exams,
        'results': results,
      };

  /// Returns a normalized payload or throws [FormatException].
  ///
  /// Each collection must be a list of JSON objects, and at least one exam
  /// sheet must exist. If the active exam ID is missing or stale, the first
  /// exam is selected so the app never restores an invalid selection.
  static Map<String, dynamic> decode(String raw) {
    final Object? value;
    try {
      value = jsonDecode(raw);
    } on FormatException {
      throw const FormatException('Malformed backup JSON');
    }
    if (value is! Map<String, dynamic> ||
        value['app'] != appName ||
        value['schemaVersion'] != schemaVersion) {
      throw const FormatException('Unsupported backup format');
    }

    final payload = Map<String, dynamic>.from(value);
    for (final key in _listKeys) {
      final items = payload[key];
      if (items is! List || items.any((item) => item is! Map)) {
        throw FormatException('Invalid $key collection');
      }
    }

    _validateRecords(
      payload['tasks'] as List,
      'tasks',
      requiredStrings: const ['id', 'title'],
      uniqueId: true,
      optionalStrings: const ['subject'],
      optionalBooleans: const ['done'],
    );
    _validateRecords(
      payload['studySessions'] as List,
      'studySessions',
      requiredStrings: const ['id', 'title'],
      uniqueId: true,
      optionalStrings: const ['subject'],
      optionalIntegers: const ['weekday', 'startMinutes', 'durationMinutes'],
      optionalBooleans: const ['completed'],
    );
    _validateRecords(
      payload['exams'] as List,
      'exams',
      requiredStrings: const ['id', 'name'],
      optionalIntegers: const ['questionCount', 'durationSeconds'],
      optionalBooleans: const ['negativeMarking', 'isCompleted'],
    );
    _validateExamAnswerData(payload['exams'] as List);

    _validateRecords(
      payload['results'] as List,
      'results',
      optionalNumbers: const [
        'questionCount',
        'correct',
        'wrong',
        'unanswered',
        'keyedQuestions',
        'percentage',
      ],
      optionalStrings: const ['id', 'examName', 'completedAt'],
      optionalBooleans: const ['negativeMarking'],
    );

    final exams = payload['exams'] as List;
    if (exams.isEmpty) {
      throw const FormatException('Backup has no exam sheets');
    }

    // Exam IDs are used as stable identifiers throughout the app. Reject
    // ambiguous IDs rather than silently restoring an unpredictable sheet.
    final examIds = <String>{};
    for (final item in exams) {
      final id = (item as Map)['id'];
      if (id is! String || id.trim().isEmpty) {
        throw const FormatException('Every exam sheet must have a non-empty ID');
      }
      if (!examIds.add(id)) {
        throw const FormatException('Exam sheet IDs must be unique');
      }
    }

    final requestedActiveId = payload['activeExamId'];
    payload['activeExamId'] =
        requestedActiveId is String && examIds.contains(requestedActiveId)
            ? requestedActiveId
            : (exams.first as Map)['id'] as String;
    return payload;
  }


  /// Exam answer maps are part of the portable backup contract. Reject
  /// malformed entries instead of letting ExamSheet.fromJson silently drop
  /// data during an import.
  static void _validateExamAnswerData(List exams) {
    for (var index = 0; index < exams.length; index++) {
      final exam = exams[index] as Map;
      final rawCount = exam['questionCount'] ?? 20;
      final count = rawCount is num && rawCount % 1 == 0
          ? rawCount.toInt()
          : 20;
      if (count < 1 || count > 200) {
        throw FormatException(
          'Invalid exams record at index $index: questionCount',
        );
      }

      for (final field in const ['answers', 'answerKey']) {
        final raw = exam[field];
        if (raw == null && !exam.containsKey(field)) continue;
        if (raw == null) continue;
        if (raw is! Map) {
          throw FormatException(
            'Invalid exams record at index $index: $field',
          );
        }
        final seenQuestions = <int>{};
        for (final entry in raw.entries) {
          final question = int.tryParse(entry.key.toString());
          final option = entry.value;
          if (question == null ||
              question < 1 ||
              question > count ||
              !seenQuestions.add(question) ||
              option is! num ||
              option % 1 != 0 ||
              option < 0 ||
              option > 3) {
            throw FormatException(
              'Invalid exams record at index $index: $field',
            );
          }
        }
      }

      final rawMarked = exam['marked'];
      if (rawMarked != null) {
        if (rawMarked is! List) {
          throw FormatException(
            'Invalid exams record at index $index: marked',
          );
        }
        final seenQuestions = <int>{};
        for (final item in rawMarked) {
          if (item is! num ||
              item % 1 != 0 ||
              item < 1 ||
              item > count ||
              !seenQuestions.add(item.toInt())) {
            throw FormatException(
              'Invalid exams record at index $index: marked',
            );
          }
        }
      }
    }
  }

  static void _validateRecords(
    List items,
    String collection, {
    List<String> requiredStrings = const [],
    bool uniqueId = false,
    List<String> optionalStrings = const [],
    List<String> optionalNumbers = const [],
    List<String> optionalIntegers = const [],
    List<String> optionalBooleans = const [],
  }) {
    final seenIds = <String>{};
    for (var index = 0; index < items.length; index++) {
      final item = items[index] as Map;
      void invalid(String field) {
        throw FormatException(
          'Invalid $collection record at index $index: $field',
        );
      }

      for (final field in requiredStrings) {
        final value = item[field];
        if (value is! String || value.trim().isEmpty) invalid(field);
      }
      if (uniqueId) {
        final id = item['id'] as String;
        if (!seenIds.add(id)) invalid('duplicate id');
      }
      for (final field in optionalStrings) {
        final value = item[field];
        if (item.containsKey(field) && value != null && value is! String) {
          invalid(field);
        }
      }
      for (final field in optionalNumbers) {
        final value = item[field];
        if (item.containsKey(field) && value != null && value is! num) {
          invalid(field);
        }
      }
      for (final field in optionalIntegers) {
        final value = item[field];
        if (item.containsKey(field) &&
            value != null &&
            (value is! num || value % 1 != 0)) {
          invalid(field);
        }
      }
      for (final field in optionalBooleans) {
        final value = item[field];
        if (item.containsKey(field) && value != null && value is! bool) {
          invalid(field);
        }
      }
    }
  }

  static String encode(Map<String, dynamic> payload) =>
      const JsonEncoder.withIndent('  ').convert(payload);
}

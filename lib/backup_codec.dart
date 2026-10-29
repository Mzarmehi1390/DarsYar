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

    final exams = payload['exams'] as List;
    if (exams.isEmpty) {
      throw const FormatException('Backup has no exam sheets');
    }
    final examIds = exams
        .map((exam) => (exam as Map)['id'])
        .whereType<String>()
        .toSet();
    final requestedActiveId = payload['activeExamId'];
    payload['activeExamId'] =
        requestedActiveId is String && examIds.contains(requestedActiveId)
            ? requestedActiveId
            : (exams.first as Map)['id'] is String
                ? (exams.first as Map)['id'] as String
                : '';
    return payload;
  }

  static String encode(Map<String, dynamic> payload) =>
      const JsonEncoder.withIndent('  ').convert(payload);
}

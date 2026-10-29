import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:dars_yar/backup_codec.dart';

void main() {
  Map<String, dynamic> validPayload({
    String activeExamId = 'exam-1',
    List<Map<String, dynamic>>? exams,
  }) => DarsYarBackupCodec.createPayload(
        exportedAt: '2026-10-29T00:00:00.000Z',
        activeExamId: activeExamId,
        tasks: [
          {'id': 'task-1', 'title': 'مرور', 'subject': 'ریاضی', 'done': false}
        ],
        studySessions: [],
        exams: exams ?? [
          {'id': 'exam-1', 'name': 'آزمون', 'questionCount': 10,
           'answers': <String, int>{}, 'answerKey': <String, int>{}, 'marked': <int>[]}
        ],
        results: [],
      );

  test('valid backup encodes and decodes with its active exam', () {
    final raw = DarsYarBackupCodec.encode(validPayload());
    final decoded = DarsYarBackupCodec.decode(raw);

    expect(decoded['app'], 'DarsYar');
    expect(decoded['schemaVersion'], 1);
    expect(decoded['activeExamId'], 'exam-1');
    expect((decoded['tasks'] as List).length, 1);
    expect(jsonDecode(raw), isA<Map<String, dynamic>>());
  });

  test('rejects malformed JSON', () {
    expect(
      () => DarsYarBackupCodec.decode('{not json'),
      throwsFormatException,
    );
  });

  test('rejects another app and unsupported schema versions', () {
    final wrongApp = validPayload()..['app'] = 'OtherApp';
    final wrongVersion = validPayload()..['schemaVersion'] = 99;

    expect(() => DarsYarBackupCodec.decode(jsonEncode(wrongApp)),
        throwsFormatException);
    expect(() => DarsYarBackupCodec.decode(jsonEncode(wrongVersion)),
        throwsFormatException);
  });

  test('rejects malformed collections and empty exam lists', () {
    final malformedList = validPayload()..['tasks'] = {'not': 'a list'};
    final malformedItem = validPayload()..['results'] = ['not an object'];
    final noExams = validPayload()..['exams'] = <Object>[];

    expect(() => DarsYarBackupCodec.decode(jsonEncode(malformedList)),
        throwsFormatException);
    expect(() => DarsYarBackupCodec.decode(jsonEncode(malformedItem)),
        throwsFormatException);
    expect(() => DarsYarBackupCodec.decode(jsonEncode(noExams)),
        throwsFormatException);
  });

  test('rejects empty and duplicate exam IDs', () {
    final duplicateIds = validPayload(exams: [
      {'id': 'same-id', 'name': 'آزمون اول'},
      {'id': 'same-id', 'name': 'آزمون دوم'},
    ]);
    final emptyId = validPayload(exams: [
      {'id': '  ', 'name': 'آزمون بدون شناسه'},
    ]);

    expect(
      () => DarsYarBackupCodec.decode(jsonEncode(duplicateIds)),
      throwsFormatException,
    );
    expect(
      () => DarsYarBackupCodec.decode(jsonEncode(emptyId)),
      throwsFormatException,
    );
  });

  test('falls back to first exam if active exam ID is missing or stale', () {
    final stale = DarsYarBackupCodec.decode(
      jsonEncode(validPayload(activeExamId: 'deleted-exam')),
    );
    final missing = validPayload()..remove('activeExamId');
    final normalizedMissing =
        DarsYarBackupCodec.decode(jsonEncode(missing));

    expect(stale['activeExamId'], 'exam-1');
    expect(normalizedMissing['activeExamId'], 'exam-1');
  });
}

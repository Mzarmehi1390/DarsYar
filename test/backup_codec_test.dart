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

  test('rejects records with missing or blank required fields', () {
    final missingTaskTitle = validPayload()
      ..['tasks'] = [{'id': 'task-1'}];
    final blankSessionId = validPayload()
      ..['studySessions'] = [
        {'id': ' ', 'title': 'جلسه مطالعه'}
      ];
    final missingExamName = validPayload()
      ..['exams'] = [
        {'id': 'exam-1'}
      ];

    expect(
      () => DarsYarBackupCodec.decode(jsonEncode(missingTaskTitle)),
      throwsFormatException,
    );
    expect(
      () => DarsYarBackupCodec.decode(jsonEncode(blankSessionId)),
      throwsFormatException,
    );
    expect(
      () => DarsYarBackupCodec.decode(jsonEncode(missingExamName)),
      throwsFormatException,
    );
  });

  test('rejects malformed field types before model deserialization', () {
    final invalidTaskFlag = validPayload()
      ..['tasks'] = [
        {'id': 'task-1', 'title': 'مرور', 'done': 'yes'}
      ];
    final invalidSessionTime = validPayload()
      ..['studySessions'] = [
        {
          'id': 'session-1',
          'title': 'مطالعه',
          'weekday': 2,
          'startMinutes': 'عصر',
          'durationMinutes': 45,
        }
      ];
    final invalidExamCount = validPayload()
      ..['exams'] = [
        {'id': 'exam-1', 'name': 'آزمون', 'questionCount': 'بیست'}
      ];
    final invalidResultScore = validPayload()
      ..['results'] = [
        {'correct': 'پانزده'}
      ];

    for (final payload in [
      invalidTaskFlag,
      invalidSessionTime,
      invalidExamCount,
      invalidResultScore,
    ]) {
      expect(
        () => DarsYarBackupCodec.decode(jsonEncode(payload)),
        throwsFormatException,
      );
    }
  });

  test('rejects fractional values for integer backup fields', () {
    final fractionalSessionTime = validPayload()
      ..['studySessions'] = [
        {
          'id': 'session-1',
          'title': 'مطالعه',
          'weekday': 2.5,
          'startMinutes': 600,
          'durationMinutes': 45,
        }
      ];
    final fractionalExamCount = validPayload()
      ..['exams'] = [
        {'id': 'exam-1', 'name': 'آزمون', 'questionCount': 20.5}
      ];

    expect(
      () => DarsYarBackupCodec.decode(jsonEncode(fractionalSessionTime)),
      throwsFormatException,
    );
    expect(
      () => DarsYarBackupCodec.decode(jsonEncode(fractionalExamCount)),
      throwsFormatException,
    );
  });

  test('rejects non-string optional subjects before model deserialization', () {
    final invalidTaskSubject = validPayload()
      ..['tasks'] = [
        {'id': 'task-1', 'title': 'مرور', 'subject': 42}
      ];
    final invalidSessionSubject = validPayload()
      ..['studySessions'] = [
        {'id': 'session-1', 'title': 'مطالعه', 'subject': false}
      ];

    expect(
      () => DarsYarBackupCodec.decode(jsonEncode(invalidTaskSubject)),
      throwsFormatException,
    );
    expect(
      () => DarsYarBackupCodec.decode(jsonEncode(invalidSessionSubject)),
      throwsFormatException,
    );
  });

  test('rejects duplicate task and study session IDs', () {
    final duplicateTasks = validPayload()
      ..['tasks'] = [
        {'id': 'same', 'title': 'اول'},
        {'id': 'same', 'title': 'دوم'},
      ];
    final duplicateSessions = validPayload()
      ..['studySessions'] = [
        {'id': 'same', 'title': 'اول'},
        {'id': 'same', 'title': 'دوم'},
      ];

    expect(
      () => DarsYarBackupCodec.decode(jsonEncode(duplicateTasks)),
      throwsFormatException,
    );
    expect(
      () => DarsYarBackupCodec.decode(jsonEncode(duplicateSessions)),
      throwsFormatException,
    );
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

  test('rejects malformed nested exam answers and review markers', () {
    final invalidAnswers = validPayload(exams: [
      {
        'id': 'exam-1',
        'name': 'آزمون',
        'questionCount': 10,
        'answers': {'1': 4},
        'answerKey': <String, int>{},
        'marked': <int>[],
      },
    ]);
    final fractionalAnswer = validPayload(exams: [
      {
        'id': 'exam-1',
        'name': 'آزمون',
        'questionCount': 10,
        'answers': {'1': 1.5},
        'answerKey': <String, int>{},
        'marked': <int>[],
      },
    ]);
    final outOfRangeQuestion = validPayload(exams: [
      {
        'id': 'exam-1',
        'name': 'آزمون',
        'questionCount': 10,
        'answers': {'11': 1},
        'answerKey': <String, int>{},
        'marked': <int>[],
      },
    ]);
    final invalidMarked = validPayload(exams: [
      {
        'id': 'exam-1',
        'name': 'آزمون',
        'questionCount': 10,
        'answers': <String, int>{},
        'answerKey': <String, int>{},
        'marked': [1, 2.5],
      },
    ]);
    final malformedAnswerMap = validPayload(exams: [
      {
        'id': 'exam-1',
        'name': 'آزمون',
        'questionCount': 10,
        'answers': [1, 2],
        'answerKey': <String, int>{},
        'marked': <int>[],
      },
    ]);

    for (final payload in [
      invalidAnswers,
      fractionalAnswer,
      outOfRangeQuestion,
      invalidMarked,
      malformedAnswerMap,
    ]) {
      expect(
        () => DarsYarBackupCodec.decode(jsonEncode(payload)),
        throwsFormatException,
      );
    }
  });

  test('rejects study sessions whose times would be silently clamped', () {
    final invalidWeekday = validPayload()
      ..['studySessions'] = [
        {
          'id': 'session-1',
          'title': 'مطالعه',
          'weekday': 7,
          'startMinutes': 600,
          'durationMinutes': 45,
        }
      ];
    final invalidStart = validPayload()
      ..['studySessions'] = [
        {
          'id': 'session-1',
          'title': 'مطالعه',
          'weekday': 2,
          'startMinutes': 1440,
          'durationMinutes': 45,
        }
      ];
    final durationPastMidnight = validPayload()
      ..['studySessions'] = [
        {
          'id': 'session-1',
          'title': 'مطالعه',
          'weekday': 2,
          'startMinutes': 1400,
          'durationMinutes': 60,
        }
      ];

    for (final payload in [
      invalidWeekday,
      invalidStart,
      durationPastMidnight,
    ]) {
      expect(
        () => DarsYarBackupCodec.decode(jsonEncode(payload)),
        throwsFormatException,
      );
    }
  });

  test('rejects exam durations outside the supported one-day limit', () {
    final zeroDuration = validPayload()
      ..['exams'] = [
        {'id': 'exam-1', 'name': 'آزمون', 'durationSeconds': 0}
      ];
    final excessiveDuration = validPayload()
      ..['exams'] = [
        {'id': 'exam-1', 'name': 'آزمون', 'durationSeconds': 86401}
      ];

    expect(
      () => DarsYarBackupCodec.decode(jsonEncode(zeroDuration)),
      throwsFormatException,
    );
    expect(
      () => DarsYarBackupCodec.decode(jsonEncode(excessiveDuration)),
      throwsFormatException,
    );
  });

  test('rejects malformed result links and non-finite percentages', () {
    final invalidExamLink = validPayload()
      ..['results'] = [
        {'examId': 42}
      ];
    final excessivePercentage = validPayload()
      ..['results'] = [
        {'percentage': 101}
      ];
    final infinitePercentage = jsonEncode(
      validPayload()..['results'] = [
        {'percentage': 1}
      ],
    ).replaceFirst('"percentage":1', '"percentage":1e999');

    expect(
      () => DarsYarBackupCodec.decode(jsonEncode(invalidExamLink)),
      throwsFormatException,
    );
    expect(
      () => DarsYarBackupCodec.decode(jsonEncode(excessivePercentage)),
      throwsFormatException,
    );
    expect(
      () => DarsYarBackupCodec.decode(infinitePercentage),
      throwsFormatException,
    );
  });

  test('rejects result counts outside their valid score ranges', () {
    final invalidResults = [
      {'questionCount': 201},
      {'questionCount': 10, 'keyedQuestions': 11},
      {'questionCount': 10, 'keyedQuestions': 5, 'correct': 6},
      {'questionCount': 10, 'keyedQuestions': 5, 'correct': 3, 'wrong': 3},
      {'questionCount': 10, 'unanswered': 11},
      {'questionCount': -1},
    ];

    for (final result in invalidResults) {
      final payload = validPayload()..['results'] = [result];
      expect(
        () => DarsYarBackupCodec.decode(jsonEncode(payload)),
        throwsFormatException,
        reason: 'Invalid result should be rejected: $result',
      );
    }
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

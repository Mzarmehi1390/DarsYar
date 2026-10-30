import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:dars_yar/exam_sheet.dart';

void main() {
  group('ExamSheet serialization', () {
    test('round-trips answers, answer key, flags and name', () {
      final original = ExamSheet(
        id: 'exam-1',
        name: 'آزمون ریاضی',
        questionCount: 30,
        durationSeconds: 2700,
        negativeMarking: true,
        answers: {1: 0, 7: 3},
        answerKey: {1: 0, 7: 2},
        marked: {3, 9},
      );

      final restored = ExamSheet.fromJson(
        Map<String, dynamic>.from(jsonDecode(jsonEncode(original.toJson())) as Map),
      );

      expect(restored.id, original.id);
      expect(restored.name, original.name);
      expect(restored.questionCount, 30);
      expect(restored.durationSeconds, 2700);
      expect(restored.negativeMarking, isTrue);
      expect(restored.answers, {1: 0, 7: 3});
      expect(restored.answerKey, {1: 0, 7: 2});
      expect(restored.marked, {3, 9});
    });

    test('uses defaults and clamps question count from stored data', () {
      final restored = ExamSheet.fromJson({
        'id': 'exam-2',
        'questionCount': 500,
      });

      expect(restored.name, 'آزمون');
      expect(restored.questionCount, 200);
      expect(restored.answers, isEmpty);
      expect(restored.answerKey, isEmpty);
      expect(restored.marked, isEmpty);
    });
  });
  test('ignores malformed and out-of-range saved answers', () {
    final restored = ExamSheet.fromJson({
      'id': 'exam-3',
      'questionCount': 3,
      'answers': {'1': 2, '2': 9, '4': 1, 'bad': 0, '3': 'x'},
      'answerKey': {'1': 2, '2': -1, '5': 0},
      'marked': [1, 3, 4, 'bad', 0],
    });

    expect(restored.answers, {1: 2});
    expect(restored.answerKey, {1: 2});
    expect(restored.marked, {1, 3});
  });

}

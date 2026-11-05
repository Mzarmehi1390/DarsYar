import 'package:flutter_test/flutter_test.dart';
import 'package:dars_yar/features/exams/application/exam_taking_lifecycle_controller.dart';

void main() {
  group('ExamTakingLifecycleController', () {
    late ExamTakingLifecycleController controller;
    setUp(() => controller = ExamTakingLifecycleController());
    test('prevents duplicate finish while confirmation is pending', () {
      controller.begin();
      expect(controller.beginFinish(), isTrue);
      expect(controller.beginFinish(), isFalse);
      controller.cancelFinish();
      expect(controller.beginFinish(), isTrue);
      controller.complete();
      expect(controller.isTaking, isFalse);
      expect(controller.beginFinish(), isFalse);
    });
    test('automatic expiry takes precedence over pending manual confirmation', () {
      controller.begin();
      expect(controller.beginFinish(), isTrue);
      expect(controller.beginFinish(automatic: true), isTrue);
      controller.complete();
      expect(controller.isTaking, isFalse);
    });

    test('leaving clears active and finishing states', () {
      controller.begin();
      expect(controller.beginFinish(), isTrue);
      controller.leave();
      expect(controller.isTaking, isFalse);
      expect(controller.isFinishing, isFalse);
    });
    test('allows only one result save at a time', () {
      expect(controller.beginSaveResult(), isTrue);
      expect(controller.beginSaveResult(), isFalse);
      controller.endSaveResult();
      expect(controller.beginSaveResult(), isTrue);
    });
  });
}

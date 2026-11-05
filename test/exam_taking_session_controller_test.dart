import 'package:flutter_test/flutter_test.dart';
import 'package:dars_yar/features/exams/application/exam_taking_session_controller.dart';

void main() {
  group('ExamTakingSessionController', () {
    test('selects questions within the available range', () {
      final controller = ExamTakingSessionController();

      controller.selectQuestion(8, questionCount: 5);
      expect(controller.currentQuestionNumber, 5);
      controller.selectQuestion(0, questionCount: 5);
      expect(controller.currentQuestionNumber, 1);
    });

    test('moves forward and backward without crossing the boundaries', () {
      final controller = ExamTakingSessionController();

      controller.previousQuestion(questionCount: 4);
      expect(controller.currentQuestionNumber, 1);
      controller.nextQuestion(questionCount: 4);
      expect(controller.currentQuestionNumber, 2);
      controller.selectQuestion(4, questionCount: 4);
      controller.nextQuestion(questionCount: 4);
      expect(controller.currentQuestionNumber, 4);
      controller.previousQuestion(questionCount: 4);
      expect(controller.currentQuestionNumber, 3);
    });

    test('toggles question navigator visibility', () {
      final controller = ExamTakingSessionController();

      expect(controller.showQuestionNavigator, isFalse);
      controller.toggleQuestionNavigator();
      expect(controller.showQuestionNavigator, isTrue);
      controller.toggleQuestionNavigator();
      expect(controller.showQuestionNavigator, isFalse);
    });
  });
}

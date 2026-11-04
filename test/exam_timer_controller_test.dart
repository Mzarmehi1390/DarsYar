import 'package:flutter_test/flutter_test.dart';
import 'package:dars_yar/features/exams/application/exam_timer_controller.dart';

void main() {
  test('exam timer controller initializes and pauses its countdown', () {
    final controller = ExamTimerController();

    controller.start(
      examId: 'exam-1',
      durationSeconds: 90,
      onExpired: () {},
    );

    expect(controller.examId, 'exam-1');
    expect(controller.remainingSeconds, 90);
    expect(controller.isRunning, isTrue);
    expect(controller.displaySeconds.value, 90);

    final remaining = controller.pause();
    expect(remaining, greaterThan(0));
    expect(remaining, lessThanOrEqualTo(90));
    expect(controller.isRunning, isFalse);
    expect(controller.deadline, isNull);

    controller.stop(reset: true);
    expect(controller.remainingSeconds, 0);
    expect(controller.examId, isNull);
    controller.dispose();
  });
}

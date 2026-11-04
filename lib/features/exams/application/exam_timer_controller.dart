import 'dart:async';

import 'package:flutter/foundation.dart';

/// Owns the countdown lifecycle for an exam independently of the page UI.
class ExamTimerController {
  Timer? _timer;
  final ValueNotifier<int> displaySeconds = ValueNotifier<int>(0);

  int remainingSeconds = 0;
  bool isRunning = false;
  String? examId;
  DateTime? deadline;

  void setRemaining(int value) {
    remainingSeconds = value.clamp(0, 24 * 60 * 60).toInt();
    displaySeconds.value = remainingSeconds;
  }

  void start({
    required String examId,
    required int durationSeconds,
    required VoidCallback onExpired,
  }) {
    _timer?.cancel();
    this.examId = examId;
    setRemaining(durationSeconds);
    deadline = DateTime.now().add(Duration(seconds: remainingSeconds));
    isRunning = true;
    _schedule(onExpired);
  }

  void resume({required VoidCallback onExpired}) {
    if (remainingSeconds <= 0) return;
    deadline = DateTime.now().add(Duration(seconds: remainingSeconds));
    isRunning = true;
    _schedule(onExpired);
  }

  int pause() {
    final currentDeadline = deadline;
    final milliseconds = currentDeadline?.difference(DateTime.now()).inMilliseconds;
    final remaining = milliseconds == null
        ? remainingSeconds
        : milliseconds <= 0
            ? 0
            : (milliseconds + 999) ~/ 1000;
    _timer?.cancel();
    _timer = null;
    setRemaining(remaining);
    isRunning = false;
    deadline = null;
    return remainingSeconds;
  }

  void stop({bool reset = false}) {
    _timer?.cancel();
    _timer = null;
    isRunning = false;
    deadline = null;
    if (reset) {
      setRemaining(0);
      examId = null;
    }
  }

  void _schedule(VoidCallback onExpired) {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      final currentDeadline = deadline;
      if (!isRunning || currentDeadline == null) return;
      final milliseconds = currentDeadline.difference(DateTime.now()).inMilliseconds;
      final remaining = milliseconds <= 0 ? 0 : (milliseconds + 999) ~/ 1000;
      if (remaining <= 0) {
        stop();
        onExpired();
      } else if (remaining != remainingSeconds) {
        setRemaining(remaining);
      }
    });
  }

  void dispose() {
    stop();
    displaySeconds.dispose();
  }
}

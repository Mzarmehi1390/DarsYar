import 'package:flutter/material.dart';

import '../domain/models/exam_sheet.dart';
import 'exam_question_navigator.dart';
import 'exam_question_workspace.dart';
import 'exam_taking_header.dart';

/// Composes the active exam presentation while leaving state and persistence
/// ownership in the page/controller layer.
class ExamTakingView extends StatelessWidget {
  const ExamTakingView({
    required this.exam,
    required this.currentQuestion,
    required this.remainingSeconds,
    required this.timerDisplay,
    required this.timerExamMatches,
    required this.timerRunning,
    required this.showQuestionNavigator,
    required this.onBack,
    required this.onToggleNavigator,
    required this.onToggleTimer,
    required this.onQuestionSelected,
    required this.onAnswerSelected,
    required this.onToggleMarked,
    required this.onPrevious,
    required this.onNext,
    required this.onFinish,
    required this.formatDuration,
    super.key,
  });

  final ExamSheet exam;
  final int currentQuestion;
  final int remainingSeconds;
  final ValueListenable<int> timerDisplay;
  final bool timerExamMatches;
  final bool timerRunning;
  final bool showQuestionNavigator;
  final VoidCallback onBack;
  final VoidCallback onToggleNavigator;
  final VoidCallback onToggleTimer;
  final ValueChanged<int> onQuestionSelected;
  final ValueChanged<int> onAnswerSelected;
  final VoidCallback onToggleMarked;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onFinish;
  final String Function(int) formatDuration;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ExamTakingHeader(
          exam: exam,
          currentQuestion: currentQuestion,
          answeredCount: exam.answers.length,
          remainingSeconds: remainingSeconds,
          timerDisplay: timerDisplay,
          timerExamMatches: timerExamMatches,
          timerRunning: timerRunning,
          showQuestionNavigator: showQuestionNavigator,
          onBack: onBack,
          onToggleNavigator: onToggleNavigator,
          onToggleTimer: onToggleTimer,
          formatDuration: formatDuration,
        ),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (showQuestionNavigator)
                ExamQuestionNavigator(
                  exam: exam,
                  currentQuestion: currentQuestion,
                  onQuestionSelected: onQuestionSelected,
                ),
              Expanded(
                child: ExamQuestionWorkspace(
                  exam: exam,
                  currentQuestion: currentQuestion,
                  onAnswerSelected: onAnswerSelected,
                  onToggleMarked: onToggleMarked,
                  onPrevious: onPrevious,
                  onNext: onNext,
                  onFinish: onFinish,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';

import '../../../design_system/darsyar_theme.dart';
import '../../../design_system/glass_surface.dart';
import '../domain/models/exam_sheet.dart';

/// Compact, scrollable question index for the active exam.
class ExamQuestionNavigator extends StatelessWidget {
  const ExamQuestionNavigator({
    required this.exam,
    required this.currentQuestion,
    required this.onQuestionSelected,
    super.key,
  });

  final ExamSheet exam;
  final int currentQuestion;
  final ValueChanged<int> onQuestionSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final markerBackground = isDark
        ? const Color(0xFF244D39)
        : const Color(0xFFB8EBD2);
    final markerForeground = isDark
        ? DarsYarTokens.accentLight
        : const Color(0xFF155C3D);

    return SizedBox(
      width: (MediaQuery.of(context).size.width * 0.34)
          .clamp(112.0, 190.0)
          .toDouble(),
      child: DarsYarContentSurface(
        radius: 18,
        child: ListView.builder(
          key: const PageStorageKey<String>('exam-question-navigator'),
          // The floating tab bar overlays the lower edge of the exam
          // workspace. Keep the last shortcut scrollable above that dock.
          padding: const EdgeInsets.fromLTRB(
            8,
            8,
            8,
            DarsYarTokens.pageBottomClearance,
          ),
          itemCount: exam.questionCount,
          itemBuilder: (context, index) {
            final number = index + 1;
            final current = number == currentQuestion;
            final markedQuestion = exam.marked.contains(number);
            final hasAnswer = exam.answers.containsKey(number);
            final itemColor = markedQuestion
                ? markerBackground
                : current
                    ? theme.colorScheme.primary
                        .withValues(alpha: isDark ? 0.22 : 0.13)
                    : hasAnswer
                        ? theme.colorScheme.surfaceContainerHighest
                        : theme.colorScheme.surface;

            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Material(
                color: itemColor,
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => onQuestionSelected(number),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: 11,
                      horizontal: 8,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            'سؤال $number',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: current || markedQuestion
                                  ? FontWeight.w800
                                  : FontWeight.w500,
                              color: markedQuestion ? markerForeground : null,
                            ),
                          ),
                        ),
                        if (markedQuestion)
                          Icon(
                            Icons.flag_rounded,
                            size: 15,
                            color: markerForeground,
                          )
                        else if (hasAnswer)
                          Icon(
                            Icons.check_circle_rounded,
                            size: 14,
                            color: theme.colorScheme.primary,
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

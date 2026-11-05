import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import '../../../design_system/darsyar_theme.dart';
import '../../../design_system/glass_button.dart';
import '../../../design_system/glass_selector.dart';
import '../../../design_system/glass_surface.dart';
import '../domain/models/exam_sheet.dart';

/// Scrollable question content and navigation controls for an active exam.
class ExamQuestionWorkspace extends StatelessWidget {
  const ExamQuestionWorkspace({
    required this.exam,
    required this.currentQuestion,
    required this.onAnswerSelected,
    required this.onToggleMarked,
    required this.onPrevious,
    required this.onNext,
    required this.onFinish,
    super.key,
  });

  final ExamSheet exam;
  final int currentQuestion;
  final ValueChanged<int> onAnswerSelected;
  final VoidCallback onToggleMarked;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onFinish;

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
    final isMarked = exam.marked.contains(currentQuestion);
    final selectedAnswer = exam.answers[currentQuestion];

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        14,
        18,
        14,
        DarsYarTokens.pageBottomClearance,
      ),
      children: [
        DarsYarContentSurface(
          radius: 24,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: Icon(
                        Icons.quiz_outlined,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'سؤال $currentQuestion',
                        style: const TextStyle(
                          fontSize: 21,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    if (isMarked)
                      Icon(Icons.flag_rounded, color: markerForeground),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'گزینه پاسخ را انتخاب کن',
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (var option = 0; option < 4; option++)
                      DarsYarGlassChoiceChip(
                        label: 'گزینه ${option + 1}',
                        semanticLabel: 'سؤال $currentQuestion، گزینه ${option + 1}',
                        selected: selectedAnswer == option,
                        selectedColor: markerBackground,
                        labelStyle: TextStyle(
                          color: selectedAnswer == option
                              ? markerForeground
                              : theme.colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 13,
                          vertical: 9,
                        ),
                        quality: GlassQuality.standard,
                        onTap: () => onAnswerSelected(option),
                      ),
                  ],
                ),
                DarsYarGlassButton(
                  height: 42,
                  radius: 14,
                  quality: GlassQuality.standard,
                  style: GlassButtonStyle.transparent,
                  onTap: onToggleMarked,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isMarked ? Icons.flag_rounded : Icons.flag_outlined,
                        size: 18,
                        color: isMarked
                            ? theme.colorScheme.primary
                            : theme.colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 7),
                      Flexible(
                        child: Text(
                          isMarked ? 'حذف علامت مرور' : 'علامت برای مرور',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        LayoutBuilder(
          builder: (context, constraints) {
            final previousButton = DarsYarGlassButton(
              width: double.infinity,
              height: 48,
              radius: 15,
              quality: GlassQuality.standard,
              style: GlassButtonStyle.filled,
              onTap: onPrevious,
              child: const Text('قبلی'),
            );
            final nextButton = DarsYarGlassButton(
              width: double.infinity,
              height: 48,
              radius: 15,
              quality: GlassQuality.standard,
              style: GlassButtonStyle.prominent,
              onTap: onNext,
              child: Text(
                currentQuestion == exam.questionCount ? 'پایان آزمون' : 'بعدی',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            );

            // Stack controls when the question pane is narrow.
            if (constraints.maxWidth < 340) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  previousButton,
                  const SizedBox(height: 8),
                  nextButton,
                ],
              );
            }

            return Row(
              children: [
                Expanded(child: previousButton),
                const SizedBox(width: 8),
                Expanded(child: nextButton),
              ],
            );
          },
        ),
        Center(
          child: DarsYarGlassButton(
            height: 42,
            radius: 13,
            quality: GlassQuality.standard,
            style: GlassButtonStyle.transparent,
            onTap: onFinish,
            child: const Text('ثبت پایان آزمون'),
          ),
        ),
      ],
    );
  }
}

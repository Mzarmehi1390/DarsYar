import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import '../../../design_system/darsyar_theme.dart';
import '../../../design_system/glass_button.dart';
import '../../../design_system/glass_tokens.dart';
import '../domain/models/exam_sheet.dart';

/// Glass header and progress summary for an active exam.
class ExamTakingHeader extends StatelessWidget {
  const ExamTakingHeader({
    required this.exam,
    required this.currentQuestion,
    required this.answeredCount,
    required this.remainingSeconds,
    required this.timerDisplay,
    required this.timerExamMatches,
    required this.timerRunning,
    required this.showQuestionNavigator,
    required this.onBack,
    required this.onToggleNavigator,
    required this.onToggleTimer,
    required this.formatDuration,
    super.key,
  });

  final ExamSheet exam;
  final int currentQuestion;
  final int answeredCount;
  final int remainingSeconds;
  final ValueListenable<int> timerDisplay;
  final bool timerExamMatches;
  final bool timerRunning;
  final bool showQuestionNavigator;
  final VoidCallback onBack;
  final VoidCallback onToggleNavigator;
  final VoidCallback onToggleTimer;
  final String Function(int seconds) formatDuration;

  @override
  Widget build(BuildContext context) {
    return GlassContainer.card(
      shape: const LiquidRoundedSuperellipse(borderRadius: 22),
      useOwnLayer: true,
      quality: GlassQuality.standard,
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 12),
        child: Column(
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 430;
                final backButton = DarsYarGlassIconButton(
                  icon: const Icon(Icons.arrow_forward),
                  onPressed: onBack,
                  size: 40,
                  shape: GlassIconButtonShape.roundedSquare,
                  quality: GlassQuality.standard,
                  semanticLabel: 'بازگشت به پاسخ‌برگ',
                );
                final timerBadge = Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest
                        .withValues(alpha: 0.72),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.timer_outlined,
                        size: 17,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 5),
                      ValueListenableBuilder<int>(
                        valueListenable: timerDisplay,
                        builder: (context, seconds, _) => Text(
                          formatDuration(timerExamMatches ? seconds : remainingSeconds),
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                            color: Theme.of(context).colorScheme.primary,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ),
                    ],
                  ),
                );
                final navigatorButton = DarsYarGlassIconButton(
                  icon: Icon(
                    Icons.format_list_numbered_rounded,
                    color: showQuestionNavigator
                        ? Theme.of(context).colorScheme.primary
                        : null,
                  ),
                  onPressed: onToggleNavigator,
                  size: 40,
                  shape: GlassIconButtonShape.roundedSquare,
                  quality: GlassQuality.standard,
                  semanticLabel: 'فهرست سؤال‌ها',
                );
                final timerButton = DarsYarGlassIconButton(
                  icon: Icon(timerRunning ? Icons.pause : Icons.play_arrow),
                  onPressed: onToggleTimer,
                  size: 40,
                  shape: GlassIconButtonShape.roundedSquare,
                  quality: GlassQuality.standard,
                  semanticLabel: timerRunning ? 'توقف زمان‌سنج' : 'ادامه زمان‌سنج',
                );
                final examTitle = Expanded(
                  child: Text(
                    exam.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                );

                if (compact) {
                  return Column(
                    children: [
                      Row(
                        children: [
                          backButton,
                          const SizedBox(width: 6),
                          examTitle,
                          const SizedBox(width: 6),
                          timerBadge,
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          navigatorButton,
                          const SizedBox(width: 6),
                          timerButton,
                        ],
                      ),
                    ],
                  );
                }

                return Row(
                  children: [
                    backButton,
                    const SizedBox(width: 8),
                    examTitle,
                    const SizedBox(width: 8),
                    timerBadge,
                    const SizedBox(width: 4),
                    navigatorButton,
                    timerButton,
                  ],
                );
              },
            ),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: GlassProgressIndicator.linear(
                value: exam.questionCount == 0
                    ? 0
                    : answeredCount / exam.questionCount,
                height: 7,
                minWidth: 0,
                color: DarsYarTokens.accent,
                backgroundColor:
                    Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.08),
                quality: GlassQuality.standard,
                semanticLabel: 'پیشرفت آزمون',
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              runAlignment: WrapAlignment.center,
              spacing: 8,
              runSpacing: 4,
              children: [
                Text(
                  'پاسخ داده‌شده: $answeredCount از ${exam.questionCount}',
                  style: TextStyle(
                    fontSize: 11,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                Text(
                  'سؤال $currentQuestion از ${exam.questionCount}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

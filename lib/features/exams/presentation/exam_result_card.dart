import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import '../../../design_system/darsyar_theme.dart';
import '../../../design_system/glass_button.dart';
import '../../../design_system/glass_surface.dart';
import '../../../exam_result.dart';

class ExamResultCard extends StatelessWidget {
  const ExamResultCard({
    super.key,
    required this.result,
    required this.onAddAnswerKey,
  });

  final ExamResult result;
  final VoidCallback onAddAnswerKey;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final hasScore = result.percentage != null;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: DarsYarContentSurface(
        radius: 21,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: DarsYarTokens.accent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: DarsYarTokens.accent.withValues(alpha: 0.12),
                      ),
                    ),
                    child: const Icon(
                      Icons.assignment_turned_in_outlined,
                      color: DarsYarTokens.accent,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      result.examName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        height: 1.35,
                        color: colors.onSurface,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    constraints: const BoxConstraints(minWidth: 64),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: hasScore
                          ? DarsYarTokens.accent.withValues(alpha: 0.13)
                          : colors.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: hasScore
                            ? DarsYarTokens.accent.withValues(alpha: 0.18)
                            : colors.outlineVariant.withValues(alpha: 0.45),
                      ),
                    ),
                    child: Text(
                      hasScore ? '${result.percentage!.round()}٪' : 'بدون کلید',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        color: hasScore
                            ? DarsYarTokens.accent
                            : colors.onSurfaceVariant,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 11),
              Wrap(
                spacing: 7,
                runSpacing: 7,
                children: [
                  _MetaPill(
                    icon: Icons.calendar_today_rounded,
                    label: '${result.dateTime.day.toString().padLeft(2, '0')}/${result.dateTime.month.toString().padLeft(2, '0')}/${result.dateTime.year}',
                  ),
                  _MetaPill(
                    icon: Icons.quiz_outlined,
                    label: '${result.questionCount} سؤال',
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 7,
                runSpacing: 7,
                children: [
                  _MetaPill(
                    icon: Icons.check_circle_outline_rounded,
                    label: 'درست: ${result.correct}',
                  ),
                  _MetaPill(
                    icon: Icons.close_rounded,
                    label: 'غلط: ${result.wrong}',
                  ),
                  _MetaPill(
                    icon: Icons.remove_circle_outline_rounded,
                    label: 'بی‌پاسخ: ${result.unanswered}',
                  ),
                ],
              ),
              if (!hasScore) ...[
                const SizedBox(height: 8),
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: DarsYarGlassButton(
                    height: 40,
                    radius: 13,
                    quality: GlassQuality.standard,
                    style: GlassButtonStyle.transparent,
                    onTap: onAddAnswerKey,
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.key_rounded, size: 17),
                        SizedBox(width: 7),
                        Text('ثبت کلید و محاسبه درصد'),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _MetaPill extends StatelessWidget {
  const _MetaPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.72),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(
        color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.35),
      ),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: Theme.of(context).colorScheme.onSurfaceVariant),
        const SizedBox(width: 5),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    ),
  );
}

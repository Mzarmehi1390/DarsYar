import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import '../../../design_system/darsyar_theme.dart';
import '../../../design_system/glass_surface.dart';
import '../../../planner_summary.dart';
import '../../../study_session.dart';

/// Self-contained weekly study summary card.
class PlannerWeeklyReportCard extends StatelessWidget {
  const PlannerWeeklyReportCard({
    super.key,
    required this.summary,
    required this.sessions,
  });

  final PlannerSummary summary;
  final List<StudySession> sessions;

  Widget _metric(BuildContext context, String label, int value, String unit) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$value',
            style: const TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w800,
              color: DarsYarTokens.accent,
            ),
          ),
          Text(
            unit,
            style: TextStyle(
              fontSize: 11,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      );

  @override
  Widget build(BuildContext context) {
    final plannedMinutes = summary.plannedMinutes;
    final completedMinutes = summary.completedMinutes;
    final completion = summary.completion;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return DarsYarContentSurface(
      radius: 24,
      tint: isDark ? const Color(0xFF20392D) : const Color(0xFFF1FAF4),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.insights_rounded, color: DarsYarTokens.accent),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'گزارش هفتگی مطالعه',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            LayoutBuilder(
              builder: (context, constraints) {
                final metrics = [
                  _metric(context, 'برنامه‌ریزی‌شده', plannedMinutes, 'دقیقه'),
                  _metric(context, 'مطالعه تکمیل‌شده', completedMinutes, 'دقیقه'),
                  _metric(context, 'پیشرفت', (completion * 100).round(), '٪'),
                ];
                if (constraints.maxWidth < 340) {
                  final itemWidth = (constraints.maxWidth - 12) / 2;
                  return Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      for (final metric in metrics)
                        SizedBox(width: itemWidth, child: metric),
                    ],
                  );
                }
                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    for (final metric in metrics) Expanded(child: metric),
                  ],
                );
              },
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: GlassProgressIndicator.linear(
                height: 7,
                minWidth: 0,
                value: completion,
                backgroundColor:
                    Theme.of(context).colorScheme.surfaceContainerHighest,
                color: DarsYarTokens.accent,
                quality: GlassQuality.standard,
                semanticLabel: 'پیشرفت هفتگی مطالعه',
              ),
            ),
            const SizedBox(height: 8),
            Text(
              sessions.isEmpty
                  ? 'با افزودن جلسه‌ها، گزارش اینجا نمایش داده می‌شود.'
                  : '${sessions.where((session) => session.completed).length} از ${sessions.length} جلسه تکمیل شده است.',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

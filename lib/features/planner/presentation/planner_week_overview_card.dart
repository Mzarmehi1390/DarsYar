import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import '../../../design_system/glass_surface.dart';
import '../../../design_system/darsyar_theme.dart';
import '../../../study_session.dart';

/// A lightweight, stateless summary card for one weekday in the planner.
class PlannerWeekOverviewCard extends StatelessWidget {
  const PlannerWeekOverviewCard({
    required this.dayLabel,
    required this.sessions,
    required this.selected,
    required this.animationsEnabled,
    required this.onTap,
    super.key,
  });

  final String dayLabel;
  final List<StudySession> sessions;
  final bool selected;
  final bool animationsEnabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final minutes = sessions.fold<int>(
      0,
      (sum, session) => sum + session.durationMinutes,
    );
    final done = sessions.where((session) => session.completed).length;
    final completion = sessions.isEmpty ? 0.0 : done / sessions.length;
    final cardContent = InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    dayLabel,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: selected ? DarsYarTokens.accent : null,
                    ),
                  ),
                ),
                if (selected)
                  Semantics(
                    label: 'روز انتخاب‌شده',
                    child: Container(
                      key: const ValueKey<String>(
                        'planner-week-selected-indicator',
                      ),
                      width: 9,
                      height: 9,
                      decoration: BoxDecoration(
                        color: DarsYarTokens.accent,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: DarsYarTokens.accent.withValues(alpha: 0.28),
                            blurRadius: 7,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 5),
            Text(
              '${sessions.length} جلسه • $minutes دقیقه',
              style: TextStyle(
                fontSize: 11,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 5),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 0, end: completion),
                duration: animationsEnabled
                    ? const Duration(milliseconds: 130)
                    : Duration.zero,
                curve: Curves.easeOutCubic,
                builder: (context, progress, _) =>
                    GlassProgressIndicator.linear(
                  height: 5,
                  minWidth: 0,
                  value: progress,
                  backgroundColor:
                      Theme.of(context).colorScheme.surfaceContainerHighest,
                  color: DarsYarTokens.accent,
                  quality: GlassQuality.standard,
                  semanticLabel: 'پیشرفت روز $dayLabel',
                ),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              sessions.isEmpty
                  ? 'بدون برنامه'
                  : '$done از ${sessions.length} انجام‌شده',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );

    if (selected) {
      return GlassContainer.card(
        padding: EdgeInsets.zero,
        shape: const LiquidRoundedSuperellipse(borderRadius: 18),
        quality: GlassQuality.standard,
        useOwnLayer: false,
        child: cardContent,
      );
    }

    return DarsYarContentSurface(radius: 18, child: cardContent);
  }
}

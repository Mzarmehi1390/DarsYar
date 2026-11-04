import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import '../../../design_system/darsyar_theme.dart';
import '../../../design_system/page_header.dart';
import '../../../models/study_task.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({
    super.key,
    required this.tasks,
    required this.onOpenPlanner,
    required this.onOpenExam,
    required this.taskTileBuilder,
    required this.emptyStateBuilder,
  });

  final List<StudyTask> tasks;
  final VoidCallback onOpenPlanner;
  final VoidCallback onOpenExam;
  final Widget Function(StudyTask task) taskTileBuilder;
  final Widget Function(IconData icon, String title, String subtitle) emptyStateBuilder;

  int get completed => tasks.where((task) => task.done).length;

Widget dashboard() => ListView(key: const PageStorageKey<String>('dashboard-scroll'), padding: const EdgeInsets.fromLTRB(20, 20, 20, DarsYarTokens.pageBottomClearance), children: [
    const DarsYarPageHeader(
      title: 'درس‌یار',
      subtitle: 'برنامه‌ریزی هوشمند برای یادگیری بهتر',
      icon: Icons.auto_stories_rounded,
    ),
    SizedBox(height: 24),
    GlassContainer.card(
      padding: EdgeInsets.zero,
      shape: const LiquidRoundedSuperellipse(borderRadius: 30),
      useOwnLayer: true,
      quality: GlassQuality.standard,
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // A restrained specular rim makes the shader material read as glass
          // without washing out the Persian copy inside the hero.
          Positioned(
            top: 0,
            left: 24,
            right: 24,
            child: IgnorePointer(
              child: Container(
                height: 1.2,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.white.withValues(alpha: 0),
                      Colors.white.withValues(
                        alpha: Theme.of(context).brightness == Brightness.dark
                            ? 0.34
                            : 0.72,
                      ),
                      Colors.white.withValues(
                        alpha: Theme.of(context).brightness == Brightness.dark
                            ? 0.20
                            : 0.48,
                      ),
                      Colors.white.withValues(alpha: 0),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: 1,
            left: 22,
            child: IgnorePointer(
              child: Container(
                width: 112,
                height: 34,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(30),
                  gradient: RadialGradient(
                    colors: [
                      Colors.white.withValues(
                        alpha: Theme.of(context).brightness == Brightness.dark
                            ? 0.10
                            : 0.20,
                      ),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: -66,
            left: -42,
            child: IgnorePointer(
              child: Container(
                width: 220,
                height: 220,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFF72C9E9).withValues(
                        alpha: Theme.of(context).brightness == Brightness.dark ? 0.19 : 0.25,
                      ),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            right: -58,
            bottom: -100,
            child: IgnorePointer(
              child: Container(
                width: 230,
                height: 230,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFF55C8A5).withValues(
                        alpha: Theme.of(context).brightness == Brightness.dark ? 0.20 : 0.28,
                      ),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.10),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.16),
                              ),
                            ),
                            child: Text(
                              'تمرکز امروز',
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.primary,
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          const SizedBox(height: 13),
                          Text(
                            'هر روز، یک قدم به هدفت نزدیک‌تر',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onSurface,
                              fontSize: 20,
                              height: 1.35,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(19),
                        border: Border.all(
                          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.18),
                        ),
                      ),
                      child: Icon(
                        Icons.auto_awesome_rounded,
                        color: Theme.of(context).colorScheme.primary,
                        size: 25,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 9),
                Text(
                  'برنامه‌ات را ساده نگه دار و با استمرار پیش برو.',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 22),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        tasks.isEmpty
                            ? 'هنوز وظیفه‌ای ثبت نشده است'
                            : 'وظایف انجام‌شده: $completed از ${tasks.length}',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Text(
                      tasks.isEmpty ? '۰٪' : '${(completed / tasks.length * 100).round()}٪',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: tasks.isEmpty ? 0 : completed / tasks.length),
                    duration: const Duration(milliseconds: 150),
                    curve: Curves.easeOutCubic,
                    builder: (context, progress, _) => LinearProgressIndicator(
                      minHeight: 8,
                      value: progress,
                      backgroundColor: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.09),
                      color: DarsYarTokens.accent,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
    SizedBox(height: 24),
    Text('دسترسی سریع', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Theme.of(context).colorScheme.onSurface)),
    SizedBox(height: 12),
    LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 350;
        final actionHeight = compact ? 116.0 : 172.0;
        final plannerAction = quickAction(
          Icons.calendar_month_rounded,
          'برنامه‌ریزی درسی',
          'مدیریت وظایف',
          onOpenPlanner,
          const Color(0xFFDDF5E9),
          compact: compact,
          height: actionHeight,
        );
        final examAction = quickAction(
          Icons.fact_check_rounded,
          'پاسخ‌برگ آزمون',
          'ثبت پاسخ‌ها',
          onOpenExam,
          const Color(0xFFD5F0E8),
          compact: compact,
          height: actionHeight,
        );
        if (compact) {
          return Column(
            children: [
              plannerAction,
              const SizedBox(height: 10),
              examAction,
            ],
          );
        }
        return Row(
          children: [
            Expanded(child: plannerAction),
            const SizedBox(width: 12),
            Expanded(child: examAction),
          ],
        );
      },
    ),
    SizedBox(height: 14),
    Row(children: [Expanded(child: Text('وظایف پیش رو', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Theme.of(context).colorScheme.onSurface))),
      GlassButton.custom(
        height: 36,
        shape: const LiquidRoundedSuperellipse(borderRadius: 12),
        quality: GlassQuality.standard,
        style: GlassButtonStyle.transparent,
        onTap: onOpenPlanner,
        child: const Text('مشاهده همه'),
      )]),
    if (tasks.where((e) => !e.done).isEmpty)
      emptyStateBuilder(Icons.event_available_rounded, 'هنوز وظیفه‌ای ثبت نشده', 'از بخش برنامه‌ریزی، اولین وظیفه‌ات را اضافه کن.')
    else ...tasks.where((e) => !e.done).take(3).map(taskTileBuilder),
  ]);

  Widget quickAction(
    IconData icon,
    String title,
    String subtitle,
    VoidCallback action,
    Color tint, {
    bool compact = false,
    double height = 172,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final iconTop = isDark
        ? Color.lerp(tint, const Color(0xFF18372B), 0.58)!
        : Color.lerp(tint, Colors.white, 0.34)!;
    final iconBottom = isDark
        ? Color.lerp(tint, const Color(0xFF0B1B14), 0.72)!
        : Color.lerp(tint, const Color(0xFFB5DDC9), 0.30)!;
    final iconColor = isDark
        ? DarsYarTokens.DarsYarTokens.accentLight
        : const Color(0xFF12664A);

    return GlassButton.custom(
      width: double.infinity,
      height: height,
      shape: const LiquidRoundedSuperellipse(borderRadius: 23),
      quality: GlassQuality.standard,
      style: GlassButtonStyle.filled,
      onTap: action,
      child: Padding(
        padding: EdgeInsets.all(compact ? 12 : 16),
        child: compact
            ? Row(
                children: [
                  _quickActionIcon(icon, iconTop, iconBottom, iconColor, isDark),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_left_rounded, size: 20),
                ],
              )
            : Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _quickActionIcon(icon, iconTop, iconBottom, iconColor, isDark),
            const SizedBox(height: 12),
            Text(
              title,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _quickActionIcon(
    IconData icon,
    Color iconTop,
    Color iconBottom,
    Color iconColor,
    bool isDark,
  ) {
    return Container(
      width: 46,
              height: 46,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [iconTop, iconBottom],
                ),
                borderRadius: BorderRadius.circular(15),
                border: Border.all(
                  color: Colors.white.withValues(alpha: isDark ? 0.22 : 0.76),
                ),
                boxShadow: [
                  BoxShadow(
                    color: DarsYarTokens.accent.withValues(alpha: 0.18),
                    blurRadius: 14,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
      child: Icon(icon, color: iconColor),
    );
  }
}

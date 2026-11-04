import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import '../../../design_system/darsyar_theme.dart';
import '../../../design_system/page_header.dart';
import '../../../models/study_task.dart';
import '../../../planner_summary.dart';
import '../../../study_session.dart';

class PlannerPage extends StatelessWidget {
  const PlannerPage({
    super.key,
    required this.sessions,
    required this.tasks,
    required this.selectedDay,
    required this.onSelectedDayChanged,
    required this.daysOrder,
    required this.dayLabels,
    required this.dayKeys,
    required this.weekKeys,
    required this.summaryBuilder,
    required this.weekOverviewCardBuilder,
    required this.weeklyReportCardBuilder,
    required this.studySessionTileBuilder,
    required this.taskTileBuilder,
    required this.emptyStateBuilder,
    required this.onAddStudySession,
    required this.onAddTask,
    required this.onCopySelectedDayTo,
  });

  final List<StudySession> sessions;
  final List<StudyTask> tasks;
  final int selectedDay;
  final ValueChanged<int> onSelectedDayChanged;
  final List<int> daysOrder;
  final List<String> dayLabels;
  final Map<int, GlobalKey> dayKeys;
  final Map<int, GlobalKey> weekKeys;
  final Widget Function(String label, int? value, IconData icon) summaryBuilder;
  final Widget Function(int day) weekOverviewCardBuilder;
  final Widget Function(PlannerSummary summary) weeklyReportCardBuilder;
  final Widget Function(StudySession session) studySessionTileBuilder;
  final Widget Function(StudyTask task) taskTileBuilder;
  final Widget Function(IconData icon, String title, String subtitle) emptyStateBuilder;
  final VoidCallback onAddStudySession;
  final VoidCallback onAddTask;
  final ValueChanged<int> onCopySelectedDayTo;

@override
  Widget build(BuildContext context) {
    final plannerSummary = PlannerSummary.fromSessions(sessions);
    final daySessions = plannerSummary.sessionsForDay(selectedDay);
    final completedSessions = plannerSummary.completedSessionCount;
    final totalMinutes = plannerSummary.minutesForDay(selectedDay);
    return ListView(key: const PageStorageKey<String>('planner-scroll'), padding: const EdgeInsets.fromLTRB(20, 22, 20, DarsYarTokens.pageBottomClearance), children: [
      const DarsYarPageHeader(
        title: 'برنامه‌ریزی درسی',
        subtitle: 'برای هر روز، جلسه مطالعه با زمان و مدت مشخص بچین.',
        icon: Icons.calendar_month_rounded,
      ),
      SizedBox(height: 18),
      LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 390;
          final width = compact ? (constraints.maxWidth - 10) / 2 : null;
          final cards = [
            summaryBuilder('جلسه‌ها', sessions.length, Icons.calendar_month_rounded),
            summaryBuilder('انجام‌شده', completedSessions, Icons.check_circle_outline),
            summaryBuilder('دقیقه امروز', totalMinutes, Icons.timer_outlined),
          ];
          if (compact) {
            return Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final card in cards)
                  SizedBox(width: width, child: card),
              ],
            );
          }
          return Row(
            children: [
              for (var i = 0; i < cards.length; i++) ...[
                if (i > 0) const SizedBox(width: 8),
                Expanded(child: cards[i]),
              ],
            ],
          );
        },
      ),
      SizedBox(height: 20),
      Text('انتخاب روز', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
      SizedBox(height: 10),
      SizedBox(
        height: 44,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: daysOrder.map((day) => Padding(
          key: dayKeys[day],
          padding: const EdgeInsets.only(left: 8),
          child: GlassChip(
            key: ValueKey<String>('planner-day-$day'),
            label: dayLabels[day],
            semanticLabel: dayLabels[day],
            selected: selectedDay == day,
            selectedColor: DarsYarTokens.accent.withValues(
              alpha: Theme.of(context).brightness == Brightness.dark ? 0.28 : 0.18,
            ),
            labelStyle: TextStyle(
              color: selectedDay == day
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.onSurfaceVariant,
              fontWeight: selectedDay == day
                  ? FontWeight.w800
                  : FontWeight.w600,
              fontSize: 13,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            quality: GlassQuality.standard,
            onTap: () {
              onSelectedDayChanged(day);
            },
          ),
        )).toList(),
          ),
        ),
      ),
      SizedBox(height: 20),
      Text('نمای کلی هفته', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
      SizedBox(height: 10),
      SizedBox(
        height: 124,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: daysOrder.map((day) => Padding(
              padding: const EdgeInsets.only(left: 10),
              child: SizedBox(
                key: weekKeys[day],
                width: 190,
                child: weekOverviewCardBuilder(day),
              ),
            )).toList(),
          ),
        ),
      ),
      SizedBox(height: 16),
      weeklyReportCardBuilder(plannerSummary),
      SizedBox(height: 20),
      Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        runSpacing: 8,
        children: [
          Text(
            dayLabels[selectedDay],
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          GlassButton.custom(
            width: 132,
            height: 44,
            shape: const LiquidRoundedSuperellipse(borderRadius: 15),
            quality: GlassQuality.standard,
            style: GlassButtonStyle.filled,
            onTap: onAddStudySession,
            child: const Text(
              'جلسه جدید',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          GlassPullDownButton(
            icon: const Icon(Icons.copy_all_rounded),
            semanticLabel: 'کپی برنامه این روز',
            quality: GlassQuality.standard,
            menuWidth: 230,
            items: [
              for (var day = 0; day < 7; day++)
                GlassMenuItem(
                  title: 'کپی برنامه به ${dayLabels[day]}',
                  icon: const Icon(Icons.calendar_today_rounded),
                  enabled: day != selectedDay,
                  onTap: () => onCopySelectedDayTo(day),
                ),
            ],
          ),
        ],
      ),
      if (daySessions.isEmpty)
        emptyStateBuilder(Icons.event_available_rounded, 'برای این روز جلسه‌ای نداری', 'با دکمه «جلسه جدید» یک زمان مطالعه اضافه کن.')
      else ...daySessions.map(studySessionTileBuilder),
      SizedBox(height: 22),
      Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        runSpacing: 8,
        children: [
          Text(
            'فهرست وظایف',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          GlassButton.custom(
            width: 126,
            height: 44,
            shape: const LiquidRoundedSuperellipse(borderRadius: 15),
            quality: GlassQuality.standard,
            style: GlassButtonStyle.filled,
            onTap: onAddTask,
            child: const Text(
              'ثبت وظیفه',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
      SizedBox(height: 10),
      if (tasks.isEmpty)
        emptyStateBuilder(Icons.edit_calendar_rounded, 'هنوز وظیفه‌ای ثبت نشده', 'برای یادآوری تکالیف، دکمه «افزودن وظیفه» را بزن.')
      else ...tasks.map(taskTileBuilder),
    ]);
  }
}

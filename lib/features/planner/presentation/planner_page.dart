import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import '../../../design_system/darsyar_theme.dart';
import '../../../design_system/glass_button.dart';
import '../../../design_system/glass_menu.dart';
import '../../../design_system/glass_selector.dart';
import '../../../design_system/page_header.dart';
import '../../../models/study_task.dart';
import '../../../planner_summary.dart';
import '../../../study_session.dart';
import '../domain/planner_calendar.dart';

class PlannerPage extends StatelessWidget {
  const PlannerPage({
    super.key,
    required this.sessions,
    required this.tasks,
    required this.selectedDay,
    required this.weekStartDate,
    required this.onWeekOffsetChanged,
    required this.onCopyWeekToNext,
    required this.onSelectedDayChanged,
    required this.daysOrder,
    required this.dayLabels,
    required this.dayKeys,
    required this.weekKeys,
    required this.plannerSummary,
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
  final DateTime weekStartDate;
  final ValueChanged<int> onWeekOffsetChanged;
  final VoidCallback onCopyWeekToNext;
  final ValueChanged<int> onSelectedDayChanged;
  final List<int> daysOrder;
  final List<String> dayLabels;
  final Map<int, GlobalKey> dayKeys;
  final Map<int, GlobalKey> weekKeys;
  final PlannerSummary plannerSummary;
  final Widget Function(String label, int? value, IconData icon) summaryBuilder;
  final Widget Function(int day) weekOverviewCardBuilder;
  final Widget Function({required PlannerSummary summary}) weeklyReportCardBuilder;
  final Widget Function(StudySession session) studySessionTileBuilder;
  final Widget Function(StudyTask task) taskTileBuilder;
  final Widget Function(IconData icon, String title, String subtitle) emptyStateBuilder;
  final VoidCallback onAddStudySession;
  final VoidCallback onAddTask;
  final ValueChanged<int> onCopySelectedDayTo;

  DateTime _dateForWeekday(int weekday) =>
      PlannerCalendar.dateForWeekday(weekStartDate, weekday);

  @override
  Widget build(BuildContext context) {
    final daySessions = plannerSummary.sessionsForDay(selectedDay);
    final completedSessions = plannerSummary.completedSessionCount;
    final totalMinutes = plannerSummary.minutesForDay(selectedDay);

    return CustomScrollView(
      key: const PageStorageKey<String>('planner-scroll'),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 22, 20, 0),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              const DarsYarPageHeader(
                title: 'برنامه‌ریزی درسی',
                subtitle: 'برای هر روز، جلسه مطالعه با زمان و مدت مشخص بچین.',
                icon: Icons.calendar_month_rounded,
              ),
              const SizedBox(height: 18),
              _PlannerWeekNavigator(
                weekStartDate: weekStartDate,
                onPrevious: () => onWeekOffsetChanged(-1),
                onNext: () => onWeekOffsetChanged(1),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: DarsYarGlassButton(
                  height: 40,
                  radius: 13,
                  quality: GlassQuality.standard,
                  onTap: onCopyWeekToNext,
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.copy_all_rounded, size: 17),
                      SizedBox(width: 7),
                      Flexible(
                        child: Text(
                          'کپی این هفته به هفته بعد',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
              LayoutBuilder(
                builder: (context, constraints) {
                  final compact = constraints.maxWidth < 390;
                  final width = compact ? (constraints.maxWidth - 10) / 2 : null;
                  final cards = [
                    summaryBuilder('جلسه‌ها', sessions.length, Icons.calendar_month_rounded),
                    summaryBuilder('انجام‌شده', completedSessions, Icons.check_circle_outline),
                    summaryBuilder('دقیقه روز انتخاب‌شده', totalMinutes, Icons.timer_outlined),
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
              const SizedBox(height: 20),
              const Text('انتخاب روز', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
              const SizedBox(height: 10),
              SizedBox(
                height: 44,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: daysOrder.map((day) => Padding(
                      key: dayKeys[day],
                      padding: const EdgeInsets.only(left: 8),
                      child: DarsYarGlassChoiceChip(
                        key: ValueKey<String>('planner-day-$day'),
                        label: '${dayLabels[day]} ${_dateForWeekday(day).day}',
                        semanticLabel: '${dayLabels[day]} ${_dateForWeekday(day).day}',
                        selected: selectedDay == day,
                        selectedColor: DarsYarTokens.accent.withValues(
                          alpha: Theme.of(context).brightness == Brightness.dark ? 0.28 : 0.18,
                        ),
                        labelStyle: TextStyle(
                          color: selectedDay == day
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(context).colorScheme.onSurfaceVariant,
                          fontWeight: selectedDay == day ? FontWeight.w800 : FontWeight.w600,
                          fontSize: 13,
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        quality: GlassQuality.standard,
                        onTap: () => onSelectedDayChanged(day),
                      ),
                    )).toList(),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text('نمای کلی هفته', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
              const SizedBox(height: 10),
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
              const SizedBox(height: 16),
              weeklyReportCardBuilder(summary: plannerSummary),
              const SizedBox(height: 20),
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                runSpacing: 8,
                children: [
                  Text(
                    dayLabels[selectedDay],
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                  ),
                  DarsYarGlassButton(
                    width: 132,
                    height: 44,
                    radius: 15,
                    quality: GlassQuality.standard,
                    style: GlassButtonStyle.filled,
                    onTap: onAddStudySession,
                    child: const Text('جلسه جدید', style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                  DarsYarGlassMenuButton(
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
            ]),
          ),
        ),
        if (daySessions.isEmpty)
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            sliver: SliverToBoxAdapter(
              child: emptyStateBuilder(
                Icons.event_available_rounded,
                'برای این روز جلسه‌ای نداری',
                'با دکمه «جلسه جدید» یک زمان مطالعه اضافه کن.',
              ),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) => studySessionTileBuilder(daySessions[index]),
                childCount: daySessions.length,
              ),
            ),
          ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 22, 20, 0),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
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
                  DarsYarGlassButton(
                    width: 126,
                    height: 44,
                    radius: 15,
                    quality: GlassQuality.standard,
                    style: GlassButtonStyle.filled,
                    onTap: onAddTask,
                    child: const Text('ثبت وظیفه', style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              if (tasks.isEmpty)
                emptyStateBuilder(
                  Icons.edit_calendar_rounded,
                  'هنوز وظیفه‌ای ثبت نشده',
                  'برای یادآوری تکالیف، دکمه «افزودن وظیفه» را بزن.',
                ),
            ]),
          ),
        ),
        if (tasks.isNotEmpty)
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, DarsYarTokens.pageBottomClearance),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) => taskTileBuilder(tasks[index]),
                childCount: tasks.length,
              ),
            ),
          )
        else
          const SliverToBoxAdapter(
            child: SizedBox(height: DarsYarTokens.pageBottomClearance),
          ),
      ],
    );
  }
}


class _PlannerWeekNavigator extends StatelessWidget {
  const _PlannerWeekNavigator({
    required this.weekStartDate,
    required this.onPrevious,
    required this.onNext,
  });

  final DateTime weekStartDate;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final end = weekStartDate.add(const Duration(days: 6));
    String date(DateTime value) => '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}';
    return Row(
      children: [
        IconButton(
          tooltip: 'هفته قبل',
          onPressed: onPrevious,
          icon: const Icon(Icons.chevron_left_rounded),
        ),
        Expanded(
          child: Column(
            children: [
              Text('هفته برنامه‌ریزی', style: TextStyle(
                fontWeight: FontWeight.w800,
                color: Theme.of(context).colorScheme.onSurface,
              )),
              const SizedBox(height: 3),
              Text('${date(weekStartDate)} تا ${date(end)}',
                style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
            ],
          ),
        ),
        IconButton(
          tooltip: 'هفته بعد',
          onPressed: onNext,
          icon: const Icon(Icons.chevron_right_rounded),
        ),
      ],
    );
  }
}

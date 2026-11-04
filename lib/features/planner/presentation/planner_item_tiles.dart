import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import '../../../design_system/darsyar_theme.dart';
import '../../../design_system/glass_surface.dart';
import '../../../models/study_task.dart';
import '../../../study_session.dart';

/// Shared glass card used by both the dashboard and planner session lists.
class StudySessionTile extends StatelessWidget {
  const StudySessionTile({
    super.key,
    required this.session,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
  });

  final StudySession session;
  final Future<void> Function() onToggle;
  final VoidCallback onEdit;
  final Future<void> Function() onDelete;

  @override
  Widget build(BuildContext context) {
    final completed = session.completed;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: DarsYarContentSurface(
        radius: 21,
        tint: completed ? DarsYarTokens.accent.withValues(alpha: 0.07) : null,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  GlassIconButton(
                    icon: Icon(
                      completed ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                      color: completed ? DarsYarTokens.accent : Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    onPressed: onToggle,
                    size: 38,
                    shape: GlassIconButtonShape.circle,
                    quality: GlassQuality.standard,
                    semanticLabel: completed
                        ? 'علامت‌گذاری جلسه به‌عنوان انجام‌نشده'
                        : 'علامت‌گذاری جلسه به‌عنوان انجام‌شده',
                  ),
                  const SizedBox(width: 9),
                  Container(
                    width: 3,
                    height: 38,
                    decoration: BoxDecoration(
                      color: completed ? DarsYarTokens.accent.withValues(alpha: 0.55) : DarsYarTokens.accent,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      session.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        height: 1.35,
                        decoration: completed ? TextDecoration.lineThrough : null,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsetsDirectional.only(start: 58, top: 8),
                child: Wrap(
                  spacing: 7,
                  runSpacing: 6,
                  children: [
                    _PlannerMetaPill(icon: Icons.menu_book_rounded, label: session.subject),
                    _PlannerMetaPill(icon: Icons.schedule_rounded, label: _formatStudyTime(session.startMinutes)),
                    _PlannerMetaPill(icon: Icons.timelapse_rounded, label: '${session.durationMinutes} دقیقه'),
                  ],
                ),
              ),
              const SizedBox(height: 7),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  GlassIconButton(
                    icon: const Icon(Icons.edit_outlined, color: DarsYarTokens.accent),
                    onPressed: onEdit,
                    size: 36,
                    shape: GlassIconButtonShape.roundedSquare,
                    quality: GlassQuality.standard,
                    semanticLabel: 'ویرایش جلسه',
                  ),
                  const SizedBox(width: 6),
                  GlassIconButton(
                    icon: Icon(Icons.delete_outline_rounded, color: Theme.of(context).colorScheme.onSurfaceVariant),
                    onPressed: onDelete,
                    size: 36,
                    shape: GlassIconButtonShape.roundedSquare,
                    quality: GlassQuality.standard,
                    semanticLabel: 'حذف جلسه',
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Shared glass card used by both the dashboard and planner task lists.
class StudyTaskTile extends StatelessWidget {
  const StudyTaskTile({
    super.key,
    required this.task,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
  });

  final StudyTask task;
  final Future<void> Function() onToggle;
  final VoidCallback onEdit;
  final Future<void> Function() onDelete;

  @override
  Widget build(BuildContext context) {
    final completed = task.done;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: DarsYarContentSurface(
        radius: 21,
        tint: completed ? DarsYarTokens.accent.withValues(alpha: 0.07) : null,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 9),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  GlassIconButton(
                    icon: Icon(
                      completed ? Icons.check_circle_rounded : Icons.circle_outlined,
                      color: completed ? DarsYarTokens.accent : Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    onPressed: onToggle,
                    size: 38,
                    shape: GlassIconButtonShape.circle,
                    quality: GlassQuality.standard,
                    semanticLabel: completed
                        ? 'علامت‌گذاری وظیفه به‌عنوان انجام‌نشده'
                        : 'علامت‌گذاری وظیفه به‌عنوان انجام‌شده',
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          task.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            height: 1.35,
                            color: Theme.of(context).colorScheme.onSurface,
                            decoration: completed ? TextDecoration.lineThrough : null,
                          ),
                        ),
                        const SizedBox(height: 5),
                        _PlannerMetaPill(icon: Icons.menu_book_rounded, label: task.subject),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 5),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  GlassIconButton(
                    icon: const Icon(Icons.edit_outlined, color: DarsYarTokens.accent),
                    onPressed: onEdit,
                    size: 36,
                    shape: GlassIconButtonShape.roundedSquare,
                    quality: GlassQuality.standard,
                    semanticLabel: 'ویرایش وظیفه',
                  ),
                  const SizedBox(width: 6),
                  GlassIconButton(
                    icon: Icon(Icons.delete_outline_rounded, color: Theme.of(context).colorScheme.onSurfaceVariant),
                    onPressed: onDelete,
                    size: 36,
                    shape: GlassIconButtonShape.roundedSquare,
                    quality: GlassQuality.standard,
                    semanticLabel: 'حذف وظیفه',
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlannerMetaPill extends StatelessWidget {
  const _PlannerMetaPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Container(
        constraints: const BoxConstraints(maxWidth: 190),
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(
                alpha: Theme.of(context).brightness == Brightness.dark ? 0.48 : 0.72,
              ),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.42),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.circle, size: 0),
            Icon(icon, size: 13, color: DarsYarTokens.accent),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      );
}

String _formatStudyTime(int minutes) =>
    '${(minutes ~/ 60).toString().padLeft(2, '0')}:${(minutes % 60).toString().padLeft(2, '0')}';

import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import '../../../design_system/darsyar_theme.dart';
import '../../../design_system/glass_surface.dart';
import '../../../exam_sheet.dart';

class SavedExamCard extends StatelessWidget {
  const SavedExamCard({
    super.key,
    required this.exam,
    required this.durationLabel,
    required this.onRename,
    required this.onEditAnswerKey,
    required this.onDelete,
    required this.onBegin,
  });

  final ExamSheet exam;
  final String durationLabel;
  final VoidCallback onRename;
  final VoidCallback onEditAnswerKey;
  final VoidCallback onDelete;
  final VoidCallback onBegin;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: DarsYarContentSurface(
      radius: 22,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Text(
                    exam.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                ),
                GlassPullDownButton(
                  icon: const Icon(Icons.more_horiz_rounded),
                  semanticLabel: 'مدیریت آزمون ${exam.name}',
                  quality: GlassQuality.standard,
                  menuWidth: 220,
                  items: [
                    GlassMenuItem(
                      title: 'تغییر نام',
                      icon: const Icon(Icons.edit_rounded),
                      onTap: onRename,
                    ),
                    GlassMenuItem(
                      title: 'ویرایش کلید پاسخ',
                      icon: const Icon(Icons.key_rounded),
                      onTap: onEditAnswerKey,
                    ),
                    GlassMenuItem(
                      title: 'حذف آزمون',
                      icon: const Icon(Icons.delete_outline_rounded),
                      isDestructive: true,
                      onTap: onDelete,
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '${exam.questionCount} سؤال  •  $durationLabel  •  ${exam.answers.length} پاسخ',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerLeft,
              child: exam.isCompleted
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.check_circle_rounded, size: 17, color: DarsYarTokens.accent),
                        const SizedBox(width: 6),
                        Text(
                          'آزمون پایان یافته',
                          style: TextStyle(
                            color: DarsYarTokens.accent,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    )
                  : GlassButton.custom(
                      width: 142,
                      height: 44,
                      shape: const LiquidRoundedSuperellipse(borderRadius: 15),
                      quality: GlassQuality.standard,
                      style: GlassButtonStyle.filled,
                      onTap: onBegin,
                      child: Text(
                        exam.answers.isEmpty ? 'شروع آزمون' : 'ادامه آزمون',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
            ),
          ],
        ),
      ),
    ),
  );
}

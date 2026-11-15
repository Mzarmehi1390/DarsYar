import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import '../../../design_system/darsyar_theme.dart';
import '../../../design_system/glass_dialog.dart';
import '../../../design_system/glass_selector.dart';
import '../../../design_system/glass_tokens.dart';

/// Presents the focused answer/review editor for one exam question.
///
/// The caller owns persistence and applies the returned draft only after the
/// user confirms, so cancelling this dialog never mutates the exam.
Future<({int? answer, bool marked})?> showExamAnswerEditorDialog({
  required BuildContext context,
  required int questionNumber,
  required int? initialAnswer,
  required bool initiallyMarked,
  required bool animationsEnabled,
}) {
  int? answer = initialAnswer;
  var marked = initiallyMarked;
  const accent = DarsYarTokens.accent;

  return showDarsYarGlassDialog<({int? answer, bool marked})>(
    context: context,
    title: 'سؤال $questionNumber',
    maxWidth: 360,
    quality: GlassQuality.standard,
    reduceMotion: !animationsEnabled,
    barrierColor: DarsYarGlassTokens.dialogBarrierColor,
    content: StatefulBuilder(
      builder: (dialogContext, dialogSet) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'گزینهٔ پاسخ',
            style: TextStyle(
              color: Theme.of(dialogContext).colorScheme.onSurface,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (var option = 0; option < 4; option++)
                DarsYarGlassChoiceChip(
                  label: ['الف', 'ب', 'ج', 'د'][option],
                  semanticLabel: 'سؤال $questionNumber، گزینه ${['الف', 'ب', 'ج', 'د'][option]}',
                  selected: answer == option,
                  selectedColor: accent.withValues(alpha: 0.18),
                  labelStyle: TextStyle(
                    color: Theme.of(dialogContext).colorScheme.onSurface,
                    fontWeight: FontWeight.w700,
                  ),
                  quality: GlassQuality.standard,
                  onTap: () => dialogSet(
                    () => answer = answer == option ? null : option,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Text(
                  'نیاز به مرور دارد',
                  style: TextStyle(
                    color: Theme.of(dialogContext).colorScheme.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              GlassSwitch(
                value: marked,
                activeColor: accent,
                semanticLabel: 'علامت‌گذاری سؤال برای مرور',
                quality: GlassQuality.standard,
                onChanged: (value) => dialogSet(() => marked = value),
              ),
            ],
          ),
          Align(
            alignment: Alignment.centerRight,
            child: DarsYarGlassChoiceChip(
              label: 'پاک کردن پاسخ',
              semanticLabel: 'پاک کردن پاسخ سؤال $questionNumber',
              selected: false,
              selectedColor: accent.withValues(alpha: 0.16),
              labelStyle: TextStyle(
                color: Theme.of(dialogContext).colorScheme.onSurface,
                fontWeight: FontWeight.w700,
              ),
              quality: GlassQuality.standard,
              onTap: () => dialogSet(() => answer = null),
            ),
          ),
        ],
      ),
    ),
    actions: [
      GlassDialogAction(
        label: 'انصراف',
        onPressed: () => Navigator.of(context).pop(),
      ),
      GlassDialogAction(
        label: 'ذخیره',
        isPrimary: true,
        onPressed: () => Navigator.of(context).pop(
          (answer: answer, marked: marked),
        ),
      ),
    ],
  );
}

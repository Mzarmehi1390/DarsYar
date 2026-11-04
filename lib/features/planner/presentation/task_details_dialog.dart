import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import '../../../design_system/glass_dialog.dart';
import '../../../models/study_task.dart';

/// Owns the task editor's temporary form state and modal presentation.
Future<(String, String)?> showTaskDetailsDialog({
  required BuildContext context,
  required bool reduceMotion,
  StudyTask? existing,
}) async {
  final titleController = TextEditingController(text: existing?.title ?? '');
  final subjectController = TextEditingController(text: existing?.subject ?? '');
  try {
    return await showDarsYarGlassDialog<(String, String)>(
      context: context,
      title: existing == null ? 'وظیفه جدید' : 'ویرایش وظیفه',
      maxWidth: 360,
      quality: GlassQuality.standard,
      reduceMotion: reduceMotion,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          GlassFormField(
            label: 'عنوان وظیفه',
            child: GlassTextField(
              surfaceStyle: GlassSurfaceStyle.solid,
              controller: titleController,
              placeholder: 'مثلاً مرور فصل دوم',
              maxLength: 100,
              // Let the glass dialog finish its entrance before the keyboard resizes it.
              autofocus: false,
              textInputAction: TextInputAction.next,
            ),
          ),
          const SizedBox(height: 14),
          GlassFormField(
            label: 'درس',
            child: GlassTextField(
              surfaceStyle: GlassSurfaceStyle.solid,
              controller: subjectController,
              placeholder: 'مثلاً ریاضی',
              maxLength: 50,
              textInputAction: TextInputAction.done,
            ),
          ),
        ],
      ),
      actions: [
        GlassDialogAction(
          label: 'انصراف',
          onPressed: () => Navigator.of(context).pop(),
        ),
        GlassDialogAction(
          label: existing == null ? 'افزودن' : 'ذخیره',
          isPrimary: true,
          onPressed: () {
            final title = titleController.text.trim();
            if (title.isNotEmpty) {
              Navigator.of(context).pop((
                title,
                subjectController.text.trim(),
              ));
            }
          },
        ),
      ],
    );
  } finally {
    titleController.dispose();
    subjectController.dispose();
  }
}

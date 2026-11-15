import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import '../../../design_system/glass_dialog.dart';
import '../../../models/study_task.dart';
import '../../../design_system/input_focus_behavior.dart';

/// Owns the task editor's temporary form state and modal presentation.
Future<(String, String, DateTime?)?> showTaskDetailsDialog({
  required BuildContext context,
  required bool reduceMotion,
  required DateTime initialDueDate,
  StudyTask? existing,
}) async {
  final titleController = TextEditingController(text: existing?.title ?? '');
  final subjectController = TextEditingController(text: existing?.subject ?? '');
  final dueDate = ValueNotifier<DateTime?>(existing?.dueDate ?? initialDueDate);
  try {
    return await showDarsYarGlassDialog<(String, String, DateTime?)>(
      context: context,
      title: existing == null ? 'وظیفه جدید' : 'ویرایش وظیفه',
      maxWidth: 360,
      quality: GlassQuality.standard,
      reduceMotion: reduceMotion,
      content: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.55,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              GlassFormField(
                label: 'عنوان وظیفه',
                child: DarsYarInputFocusBehavior(
                  controller: titleController,
                  child: GlassTextField(
                  surfaceStyle: GlassSurfaceStyle.solid,
                  controller: titleController,
                  placeholder: 'مثلاً مرور فصل دوم',
                  maxLength: 100,
                  // Let the glass dialog finish its entrance before the keyboard resizes it.
                  autofocus: false,
                  textInputAction: TextInputAction.next,
                )),
              ),
              const SizedBox(height: 14),
              ValueListenableBuilder<DateTime?>(
                valueListenable: dueDate,
                builder: (context, value, _) => Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          final selected = await showDatePicker(
                            context: context,
                            initialDate: value ?? initialDueDate,
                            firstDate: DateTime(2000),
                            lastDate: DateTime(2100),
                            helpText: 'انتخاب تاریخ سررسید',
                          );
                          if (selected != null) {
                            dueDate.value = DateTime(selected.year, selected.month, selected.day);
                          }
                        },
                        icon: const Icon(Icons.event_outlined),
                        label: Text(value == null
                          ? 'انتخاب تاریخ سررسید'
                          : 'سررسید: ${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}'),
                      ),
                    ),
                    if (value != null)
                      IconButton(
                        tooltip: 'حذف تاریخ سررسید',
                        onPressed: () => dueDate.value = null,
                        icon: const Icon(Icons.event_busy_outlined),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              GlassFormField(
                label: 'درس',
                child: DarsYarInputFocusBehavior(
                  controller: subjectController,
                  child: GlassTextField(
                  surfaceStyle: GlassSurfaceStyle.solid,
                  controller: subjectController,
                  placeholder: 'مثلاً ریاضی',
                  maxLength: 50,
                  textInputAction: TextInputAction.done,
                )),
              ),
            ],
          ),
        ),
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
                dueDate.value,
              ));
            }
          },
        ),
      ],
    );
  } finally {
    titleController.dispose();
    subjectController.dispose();
    dueDate.dispose();
  }
}

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import '../../../study_session.dart';

class StudySessionEditorDialog extends StatefulWidget {
  const StudySessionEditorDialog({
    super.key,
    required this.initialWeekday,
    required this.weekDays,
    required this.hasOverlap,
    required this.onMessage,
    this.existing,
  });

  final StudySession? existing;
  final int initialWeekday;
  final List<String> weekDays;
  final bool Function(StudySession candidate) hasOverlap;
  final ValueChanged<String> onMessage;

  @override
  State<StudySessionEditorDialog> createState() => StudySessionEditorDialogState();
}

class StudySessionEditorDialogState extends State<StudySessionEditorDialog> {
  static const weekDayOrder = [6, 0, 1, 2, 3, 4, 5];
  late final TextEditingController _titleController;
  late final TextEditingController _subjectController;
  late final ValueNotifier<int> _weekday;
  late final ValueNotifier<int> _startMinutes;
  late final ValueNotifier<bool> _showTimePicker;
  late DateTime _selectedTime;
  late int _durationMinutes;
  late final TextEditingController _durationController;
  String? _lastError;
  DateTime? _lastErrorAt;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.existing?.title ?? '');
    _subjectController = TextEditingController(text: widget.existing?.subject ?? '');
    _weekday = ValueNotifier<int>(widget.existing?.weekday ?? widget.initialWeekday);
    _startMinutes = ValueNotifier<int>(widget.existing?.startMinutes ?? 16 * 60);
    _showTimePicker = ValueNotifier<bool>(false);
    _selectedTime = DateTime(2026, 1, 1, _startMinutes.value ~/ 60, _startMinutes.value % 60);
    _durationMinutes = widget.existing?.durationMinutes ?? 55;
    _durationController = TextEditingController(text: _durationMinutes.toString());
  }

  @override
  void dispose() {
    _titleController.dispose();
    _subjectController.dispose();
    _durationController.dispose();
    _weekday.dispose();
    _startMinutes.dispose();
    _showTimePicker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scrollData = ScrollControllerProvider.of(context);
    return SingleChildScrollView(
    controller: scrollData?.controller,
    physics: scrollData?.physics,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          widget.existing == null ? 'جلسه مطالعه جدید' : 'ویرایش جلسه مطالعه',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 16),
        GlassFormField(
          label: 'عنوان جلسه',
          child: GlassTextField(
            surfaceStyle: GlassSurfaceStyle.solid,
            controller: _titleController,
            // Let the glass sheet settle before the keyboard changes its viewport.
            autofocus: false,
            placeholder: 'مثلاً حل تمرین فصل اول',
            textInputAction: TextInputAction.next,
          ),
        ),
        const SizedBox(height: 14),
        GlassFormField(
          label: 'درس',
          child: GlassTextField(
            surfaceStyle: GlassSurfaceStyle.solid,
            controller: _subjectController,
            placeholder: 'مثلاً ریاضی',
            textInputAction: TextInputAction.next,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'روز هفته',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        ValueListenableBuilder<int>(
          valueListenable: _weekday,
          builder: (context, weekday, _) => SizedBox(
            width: double.infinity,
            child: GlassSegmentedControl.scrollable(
              segments: [
                for (final day in weekDayOrder)
                  GlassSegment(
                    label: widget.weekDays[day],
                    semanticLabel: widget.weekDays[day],
                  ),
              ],
              selectedIndex: weekDayOrder.indexOf(weekday),
              onSegmentSelected: (index) => _weekday.value = weekDayOrder[index],
              height: 44,
              quality: GlassQuality.standard,
              selectedTextStyle: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontWeight: FontWeight.w800,
                fontSize: 12,
              ),
              unselectedTextStyle: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'ساعت شروع',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        ValueListenableBuilder<int>(
          valueListenable: _startMinutes,
          builder: (context, startMinutes, _) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              GlassButton.custom(
                width: double.infinity,
                height: 50,
                shape: const LiquidRoundedSuperellipse(borderRadius: 16),
                quality: GlassQuality.standard,
                onTap: () => _showTimePicker.value = !_showTimePicker.value,
                child: ValueListenableBuilder<bool>(
                  valueListenable: _showTimePicker,
                  builder: (context, showPicker, _) => Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.schedule_rounded, size: 19),
                      const SizedBox(width: 10),
                      Text(_formatTime(startMinutes)),
                      const SizedBox(width: 8),
                      Icon(showPicker ? Icons.expand_less_rounded : Icons.expand_more_rounded, size: 18),
                    ],
                  ),
                ),
              ),
              ValueListenableBuilder<bool>(
                valueListenable: _showTimePicker,
                builder: (context, showPicker, _) {
                  if (!showPicker) return const SizedBox.shrink();
                  return Column(
                    children: [
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.fromLTRB(10, 10, 10, 12),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.42),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.42)),
                        ),
                        child: Column(
                          children: [
                            SizedBox(
                              height: 178,
                              child: CupertinoTheme(
                                data: CupertinoThemeData(
                                  brightness: Theme.of(context).brightness,
                                  primaryColor: Theme.of(context).colorScheme.primary,
                                ),
                                child: CupertinoDatePicker(
                                  mode: CupertinoDatePickerMode.time,
                                  initialDateTime: _selectedTime,
                                  use24hFormat: true,
                                  onDateTimeChanged: (value) => _selectedTime = value,
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Align(
                              alignment: AlignmentDirectional.centerEnd,
                              child: GlassButton.custom(
                                height: 40,
                                shape: const LiquidRoundedSuperellipse(borderRadius: 13),
                                quality: GlassQuality.standard,
                                style: GlassButtonStyle.filled,
                                onTap: () {
                                  _startMinutes.value = _selectedTime.hour * 60 + _selectedTime.minute;
                                  _showTimePicker.value = false;
                                },
                                child: const Text('اعمال ساعت انتخاب‌شده'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        GlassFormField(
          label: 'مدت جلسه (دقیقه)',
          helperText: 'مدت دلخواهت را از ۱ تا ۱۴۴۰ دقیقه وارد کن.',
          child: GlassTextField(
            surfaceStyle: GlassSurfaceStyle.solid,
            controller: _durationController,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(4),
            ],
            maxLength: 4,
            onChanged: (value) => _durationMinutes = int.tryParse(value) ?? 0,
            textInputAction: TextInputAction.done,
          ),
        ),
        const SizedBox(height: 22),
        Row(
          children: [
            Expanded(
              child: GlassButton.custom(
                height: 48,
                shape: const LiquidRoundedSuperellipse(borderRadius: 16),
                quality: GlassQuality.standard,
                onTap: () => Navigator.of(context).pop(),
                child: const Text('انصراف'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: GlassButton.custom(
                height: 48,
                shape: const LiquidRoundedSuperellipse(borderRadius: 16),
                quality: GlassQuality.standard,
                style: GlassButtonStyle.filled,
                onTap: _submit,
                child: Text(
                  widget.existing == null ? 'افزودن' : 'ذخیره تغییرات',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ],
        ),
      ],
    ),
  );
  }

  String _formatTime(int minutes) =>
      '${(minutes ~/ 60).toString().padLeft(2, '0')}:${(minutes % 60).toString().padLeft(2, '0')}';

  void _submit() {
    final title = _titleController.text.trim();
    _durationMinutes = int.tryParse(_durationController.text) ?? 0;
    if (_durationMinutes < 1 || _durationMinutes > 1440) { _showMessage('مدت جلسه باید بین ۱ تا ۱۴۴۰ دقیقه باشد.'); return; }
    if (title.isEmpty) {
      _showMessage('عنوان جلسه را وارد کن.');
      return;
    }
    if (_startMinutes.value + _durationMinutes > 1440) {
      _showMessage('جلسه نباید از نیمه‌شب عبور کند؛ ساعت شروع را تغییر بده.');
      return;
    }
    final candidate = StudySession(
      id: widget.existing?.id ?? DateTime.now().microsecondsSinceEpoch.toString(),
      title: title,
      subject: _subjectController.text.trim().isEmpty
          ? 'عمومی'
          : _subjectController.text.trim(),
      weekday: _weekday.value,
      startMinutes: _startMinutes.value,
      durationMinutes: _durationMinutes,
      completed: widget.existing?.completed ?? false,
    );
    if (widget.hasOverlap(candidate)) {
      _showMessage('این زمان با یک جلسهٔ دیگر در همین روز تداخل دارد.');
      return;
    }
    Navigator.pop(context, candidate);
  }

  void _showMessage(String message) {
    final now = DateTime.now();
    if (_lastError == message && _lastErrorAt != null &&
        now.difference(_lastErrorAt!) < const Duration(seconds: 2)) {
      return;
    }
    _lastError = message;
    _lastErrorAt = now;
    widget.onMessage(message);
  }
}

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import '../../../study_session.dart';
import '../../../design_system/modal_content.dart';
import '../../../design_system/glass_button.dart';
import '../../../design_system/input_focus_behavior.dart';

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
        return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            controller: scrollData?.controller,
            physics: scrollData?.physics,
            child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          widget.existing == null ? 'جلسه مطالعه جدید' : 'ویرایش جلسه مطالعه',
          style: TextStyle(
            fontSize: 18,
            height: 1.25,
            fontWeight: FontWeight.w800,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 16),
        GlassFormField(
          label: 'عنوان جلسه',
          child: DarsYarInputFocusBehavior(
            controller: _titleController,
            child: GlassTextField(
            surfaceStyle: GlassSurfaceStyle.solid,
            controller: _titleController,
            // Let the glass sheet settle before the keyboard changes its viewport.
            autofocus: false,
            placeholder: 'مثلاً حل تمرین فصل اول',
            textInputAction: TextInputAction.next,
          )),
        ),
        const SizedBox(height: 14),
        GlassFormField(
          label: 'درس',
          child: DarsYarInputFocusBehavior(
            controller: _subjectController,
            child: GlassTextField(
            surfaceStyle: GlassSurfaceStyle.solid,
            controller: _subjectController,
            placeholder: 'مثلاً ریاضی',
            textInputAction: TextInputAction.next,
          )),
        ),
        const SizedBox(height: 16),
        Text(
          'روز هفته',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface,
            fontSize: 16,
            height: 1.3,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        ValueListenableBuilder<int>(
          valueListenable: _weekday,
          builder: (context, weekday, _) => SizedBox(
            height: 48,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final day in weekDayOrder)
                    Padding(
                      padding: const EdgeInsetsDirectional.only(end: 9),
                      child: Tooltip(
                        message: widget.weekDays[day],
                        child: Semantics(
                          button: true,
                          selected: weekday == day,
                          label: widget.weekDays[day],
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              key: ValueKey<String>('study-session-day-$day'),
                              customBorder: const CircleBorder(),
                              onTap: () => _weekday.value = day,
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 150),
                                curve: Curves.easeOutCubic,
                                width: 42,
                                height: 42,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: weekday == day
                                      ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.18)
                                      : Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.55),
                                  border: Border.all(
                                    color: weekday == day
                                        ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.78)
                                        : Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.62),
                                    width: weekday == day ? 1.4 : 0.8,
                                  ),
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  widget.weekDays[day].substring(0, 1),
                                  style: TextStyle(
                                    color: weekday == day
                                        ? Theme.of(context).colorScheme.primary
                                        : Theme.of(context).colorScheme.onSurface,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'ساعت شروع',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface,
            fontSize: 16,
            height: 1.3,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        ValueListenableBuilder<int>(
          valueListenable: _startMinutes,
          builder: (context, startMinutes, _) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DarsYarGlassButton(
                width: double.infinity,
                height: 50,
                radius: 16,
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
                              child: DarsYarGlassButton(
                                height: 40,
                                radius: 13,
                                quality: GlassQuality.standard,
                                style: GlassButtonStyle.filled,
                                onTap: () {
                                  _startMinutes.value = _selectedTime.hour * 60 + _selectedTime.minute;
                                  _showTimePicker.value = false;
                                },
                                child: const DarsYarModalButtonLabel(
                                  primary: true,
                                  child: Text('اعمال ساعت انتخاب‌شده'),
                                ),
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
          child: DarsYarInputFocusBehavior(
            controller: _durationController,
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
          )),
        ),
            ],
          ),
        ),
      ),
      const Divider(height: 1),
SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(16, 0, 16, 12),
            child: Row(
              children: [
                Expanded(
                  child: DarsYarGlassButton(
                    height: 48,
                    radius: 16,
                    quality: GlassQuality.standard,
                    onTap: () => Navigator.of(context).pop(),
                    child: const DarsYarModalButtonLabel(child: Text('انصراف')),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: DarsYarGlassButton(
                    height: 48,
                    radius: 16,
                    quality: GlassQuality.standard,
                    style: GlassButtonStyle.filled,
                    onTap: _submit,
                    child: DarsYarModalButtonLabel(
                      primary: true,
                      child: Text(widget.existing == null ? 'افزودن' : 'ذخیره تغییرات'),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
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

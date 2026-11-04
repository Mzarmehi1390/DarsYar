import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import '../../../design_system/glass_modal_sheet.dart';
import '../../../design_system/modal_content.dart';
import '../../../study_session.dart';

class TimePickerSheet extends StatefulWidget {
  const TimePickerSheet({required this.initialTime});

  final TimeOfDay initialTime;

  @override
  State<TimePickerSheet> createState() => TimePickerSheetState();
}

class TimePickerSheetState extends State<TimePickerSheet> {
  late DateTime _selected;

  @override
  void initState() {
    super.initState();
    _selected = DateTime(
      2026,
      1,
      1,
      widget.initialTime.hour,
      widget.initialTime.minute,
    );
  }

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(
        'انتخاب ساعت شروع',
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurface,
          fontSize: 19,
          fontWeight: FontWeight.w800,
        ),
      ),
      const SizedBox(height: 10),
      SizedBox(
        height: 178,
        child: CupertinoDatePicker(
          mode: CupertinoDatePickerMode.time,
          initialDateTime: _selected,
          use24hFormat: true,
          onDateTimeChanged: (value) => setState(() => _selected = value),
        ),
      ),
      const SizedBox(height: 12),
      Row(
        children: [
          Expanded(
            child: GlassButton.custom(
              height: 46,
              shape: const LiquidRoundedSuperellipse(borderRadius: 15),
              quality: GlassQuality.standard,
              onTap: () => Navigator.of(context).pop(),
              child: const Text('انصراف'),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: GlassButton.custom(
              height: 46,
              shape: const LiquidRoundedSuperellipse(borderRadius: 15),
              quality: GlassQuality.standard,
              style: GlassButtonStyle.filled,
              onTap: () => Navigator.of(context).pop(
                TimeOfDay(hour: _selected.hour, minute: _selected.minute),
              ),
              child: const Text(
                'انتخاب',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ],
      ),
    ],
  );
}

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
  late int _weekday;
  late int _startMinutes;
  late int _durationMinutes;
  late final TextEditingController _durationController;
  String? _lastError;
  DateTime? _lastErrorAt;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.existing?.title ?? '');
    _subjectController = TextEditingController(text: widget.existing?.subject ?? '');
    _weekday = widget.existing?.weekday ?? widget.initialWeekday;
    _startMinutes = widget.existing?.startMinutes ?? 16 * 60;
    _durationMinutes = widget.existing?.durationMinutes ?? 55;
    _durationController = TextEditingController(text: _durationMinutes.toString());
  }

  @override
  void dispose() {
    _titleController.dispose();
    _subjectController.dispose();
    _durationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
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
            autofocus: widget.existing == null,
            placeholder: 'مثلاً حل تمرین فصل اول',
            quality: GlassQuality.standard,
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
            quality: GlassQuality.standard,
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
        GlassSegmentedControl.scrollable(
          segments: [
            for (final day in weekDayOrder)
              GlassSegment(
                label: widget.weekDays[day],
                semanticLabel: widget.weekDays[day],
              ),
          ],
          selectedIndex: weekDayOrder.indexOf(_weekday),
          onSegmentSelected: (index) =>
              setState(() => _weekday = weekDayOrder[index]),
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
        const SizedBox(height: 16),
        Text(
          'ساعت شروع',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        GlassButton.custom(
          width: 250,
          height: 50,
          shape: const LiquidRoundedSuperellipse(borderRadius: 16),
          quality: GlassQuality.standard,
          onTap: () async {
            final picked = await showDarsYarGlassSheet<TimeOfDay>(
              context: context,
              builder: (_) => DarsYarModalContent(
                child: TimePickerSheet(
                  initialTime: TimeOfDay(
                    hour: _startMinutes ~/ 60,
                    minute: _startMinutes % 60,
                  ),
                ),
              ),
              initialState: GlassSheetState.half,
              halfSize: 0.54,
              fullSize: 0.64,
              quality: GlassQuality.standard,
              fillThreshold: 1.0,
              maintainContentGlass: true,
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              barrierColor: Colors.transparent,
            );
            if (picked != null && mounted) {
              setState(() => _startMinutes = picked.hour * 60 + picked.minute);
            }
          },
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.schedule_rounded, size: 19),
              const SizedBox(width: 10),
              Text(_formatTime(_startMinutes)),
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
            quality: GlassQuality.standard,
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
    if (_startMinutes + _durationMinutes > 1440) {
      _showMessage('جلسه نباید از نیمه‌شب عبور کند؛ ساعت شروع را تغییر بده.');
      return;
    }
    final candidate = StudySession(
      id: widget.existing?.id ?? DateTime.now().microsecondsSinceEpoch.toString(),
      title: title,
      subject: _subjectController.text.trim().isEmpty
          ? 'عمومی'
          : _subjectController.text.trim(),
      weekday: _weekday,
      startMinutes: _startMinutes,
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

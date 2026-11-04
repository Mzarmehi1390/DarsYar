import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import '../../../design_system/darsyar_theme.dart';
import '../../../design_system/glass_modal_sheet.dart';
import '../../../design_system/glass_surface.dart';
import '../../../design_system/glass_tokens.dart';
import '../../../design_system/modal_content.dart';

class AnswerKeyEditorSheet extends StatefulWidget {
  const AnswerKeyEditorSheet({
    super.key,
    required this.title,
    required this.questionCount,
    required this.initialAnswers,
    required this.clearLabel,
    required this.saveLabel,
  });

  final String title;
  final int questionCount;
  final Map<int, int> initialAnswers;
  final String clearLabel;
  final String saveLabel;

  @override
  State<AnswerKeyEditorSheet> createState() => AnswerKeyEditorSheetState();
}

class AnswerKeyEditorSheetState extends State<AnswerKeyEditorSheet> {
  late final Map<int, int> _draft;

  static const _options = ['الف', 'ب', 'ج', 'د'];

  @override
  void initState() {
    super.initState();
    _draft = Map<int, int>.from(widget.initialAnswers);
  }

  Widget _questionRow(int question) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 64,
            child: Text(
              'سؤال $question',
              style: TextStyle(
                color: scheme.onSurface,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ),
          Expanded(
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (var option = 0; option < _options.length; option++)
                  _answerOption(question, option, scheme),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Answer choices are intentionally shader-free: a 200-question key can
  /// create 800 controls, so per-chip backdrop captures cause avoidable GPU
  /// work and make the editor feel sluggish while scrolling.
  Widget _answerOption(
    int question,
    int option,
    ColorScheme scheme,
  ) {
    final selected = _draft[question] == option;
    return Semantics(
      button: true,
      selected: selected,
      label: 'سؤال $question، گزینه ${_options[option]}',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(11),
          onTap: () => setState(() {
            if (selected) {
              _draft.remove(question);
            } else {
              _draft[question] = option;
            }
          }),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            curve: Curves.easeOut,
            constraints: const BoxConstraints(minWidth: 38, minHeight: 36),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: selected
                  ? scheme.primary.withValues(alpha: 0.16)
                  : scheme.surfaceContainerHighest.withValues(alpha: 0.48),
              borderRadius: BorderRadius.circular(11),
              border: Border.all(
                color: selected
                    ? scheme.primary.withValues(alpha: 0.72)
                    : scheme.outlineVariant.withValues(alpha: 0.62),
                width: selected ? 1.3 : 0.8,
              ),
            ),
            alignment: Alignment.center,
            child: Text(
              _options[option],
              style: TextStyle(
                color: selected ? scheme.primary : scheme.onSurface,
                fontWeight: FontWeight.w800,
                fontSize: 12,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _footerActions() => Padding(
    padding: const EdgeInsets.only(top: 12, bottom: 8),
    child: Wrap(
      alignment: WrapAlignment.center,
      spacing: 8,
      runSpacing: 8,
      children: [
        GlassButton.custom(
          width: 96,
          height: 44,
          shape: const LiquidRoundedSuperellipse(borderRadius: 15),
          quality: GlassQuality.standard,
          onTap: () => setState(_draft.clear),
          child: Text(widget.clearLabel),
        ),
        GlassButton.custom(
          width: 96,
          height: 44,
          shape: const LiquidRoundedSuperellipse(borderRadius: 15),
          quality: GlassQuality.standard,
          onTap: () => Navigator.of(context).pop(),
          child: const Text('انصراف'),
        ),
        GlassButton.custom(
          width: 122,
          height: 44,
          shape: const LiquidRoundedSuperellipse(borderRadius: 15),
          quality: GlassQuality.standard,
          style: GlassButtonStyle.filled,
          onTap: () => Navigator.of(context).pop(Map<int, int>.from(_draft)),
          child: Text(
            widget.saveLabel,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final questionCount = widget.questionCount.clamp(0, 200);
    final scrollData = ScrollControllerProvider.of(context);
    return ListView.builder(
      controller: scrollData?.controller,
      physics: scrollData?.physics,
      padding: EdgeInsets.zero,
      itemCount: questionCount + 4,
      itemBuilder: (context, index) {
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              widget.title,
              style: TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.w800,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          );
        }
        if (index == 1) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              '${_draft.length} از $questionCount سؤال دارای کلید پاسخ است.',
              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
          );
        }
        if (index == 2) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: GlassProgressIndicator.linear(
                height: 5,
                minWidth: 0,
                value: questionCount == 0
                    ? 0
                    : (_draft.length / questionCount).clamp(0.0, 1.0).toDouble(),
                color: DarsYarTokens.accent,
                backgroundColor:
                    Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.08),
                quality: GlassQuality.standard,
                semanticLabel: 'پیشرفت ورود کلید پاسخ',
              ),
            ),
          );
        }
        if (index == questionCount + 3) {
          return _footerActions();
        }
        return _questionRow(index - 2);
      },
    );
  }
}


class ExamSetupPanel extends StatefulWidget {
  const ExamSetupPanel({super.key, required this.onCreate, required this.onMessage});
  final void Function(String, int, int, bool, Map<int, int>) onCreate;
  final ValueChanged<String> onMessage;

  @override
  State<ExamSetupPanel> createState() => ExamSetupPanelState();
}

class ExamSetupPanelState extends State<ExamSetupPanel> {
  final _name = TextEditingController();
  final _count = TextEditingController(text: '20');
  Duration _duration = const Duration(minutes: 30);
  final Map<int, int> _answerKey = {};
  bool _negativeMarking = false;
  String? _lastError;
  DateTime? _lastErrorAt;

  void _showValidationMessage(String message) {
    final now = DateTime.now();
    if (_lastError == message && _lastErrorAt != null && now.difference(_lastErrorAt!) < const Duration(seconds: 2)) {
      return;
    }
    _lastError = message; _lastErrorAt = now;
    widget.onMessage(message);
  }

  @override
  void dispose() {
    _name.dispose();
    _count.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _name.text.trim();
    final count = int.tryParse(_count.text);
    if (name.isEmpty || count == null || count < 1 || count > 200) {
      _showValidationMessage('نام و تعداد سؤال را درست وارد کن.');
      return;
    }
    final duration = _duration.inSeconds;
    if (duration < 1 || duration > 24 * 60 * 60) {
      _showValidationMessage('زمان آزمون باید بین یک ثانیه تا ۲۴ ساعت باشد.');
      return;
    }
    widget.onCreate(name, count, duration, _negativeMarking, Map<int, int>.fromEntries(_answerKey.entries.where((entry) => entry.key >= 1 && entry.key <= count)));
  }

  String _formatExamDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  Future<void> _editDuration() async {
    final updated = await showDarsYarGlassSheet<Duration>(
      context: context,
      builder: (_) => DarsYarModalContent(
        child: ExamDurationDialog(initialDuration: _duration, onMessage: widget.onMessage),
      ),
      initialState: GlassSheetState.full,
      fullSize: 0.82,
      quality: GlassQuality.standard,
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
      barrierColor: DarsYarGlassTokens.sheetBarrierColor,
    );
    if (updated != null && mounted) setState(() => _duration = updated);
  }

  Future<void> _editSetupAnswerKey() async {
    final count = int.tryParse(_count.text)?.clamp(1, 200).toInt() ?? 20;
    final updated = await showDarsYarGlassSheet<Map<int, int>>(
      context: context,
      builder: (_) => DarsYarModalContent(
        child: AnswerKeyEditorSheet(
          title: 'کلید پاسخ آزمون',
          questionCount: count,
          initialAnswers: _answerKey,
          clearLabel: 'پاک‌کردن',
          saveLabel: 'ذخیره کلید',
        ),
      ),
      initialState: GlassSheetState.full,
      fullSize: 0.90,
      quality: GlassQuality.standard,
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 22),
      barrierColor: DarsYarGlassTokens.sheetBarrierColor,
    );
    if (updated != null && mounted) {
      setState(() {
        _answerKey
          ..clear()
          ..addAll(updated);
      });
    }
  }

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(20, 8, 20, DarsYarTokens.pageBottomClearance),
    children: [
      DarsYarContentSurface(child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('مشخصات آزمون', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          SizedBox(height: 14),
          GlassFormField(
            label: 'نام آزمون',
            child: GlassTextField(
              surfaceStyle: GlassSurfaceStyle.solid,
              controller: _name,
              maxLength: 60,
              placeholder: 'مثلاً آزمون فصل اول ریاضی',
              quality: GlassQuality.standard,
              textInputAction: TextInputAction.next,
            ),
          ),
          const SizedBox(height: 12),
          GlassFormField(
            label: 'تعداد سؤال (۱ تا ۲۰۰)',
            child: GlassTextField(
              surfaceStyle: GlassSurfaceStyle.solid,
              controller: _count,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              maxLength: 3,
              quality: GlassQuality.standard,
              textInputAction: TextInputAction.next,
            ),
          ),
          SizedBox(height: 14),
          Text('زمان دلخواه آزمون', style: TextStyle(fontWeight: FontWeight.w700)),
          SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.48),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Theme.of(context).dividerColor.withValues(alpha: 0.35)),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 300;
                final timerIcon = Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: DarsYarTokens.accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.timer_outlined, color: DarsYarTokens.accent),
                );
                final durationLabel = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('مدت آزمون', style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: 12,
                    )),
                    SizedBox(height: 3),
                    Text(_formatExamDuration(_duration),
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: 1.2)),
                  ],
                );
                final editButton = GlassButton.custom(
                  width: 112,
                  height: 42,
                  shape: const LiquidRoundedSuperellipse(borderRadius: 14),
                  quality: GlassQuality.standard,
                  style: GlassButtonStyle.filled,
                  onTap: _editDuration,
                  child: const Text('تغییر زمان'),
                );
                if (compact) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(children: [
                        timerIcon,
                        SizedBox(width: 12),
                        Expanded(child: durationLabel),
                      ]),
                      SizedBox(height: 8),
                      Align(alignment: Alignment.centerLeft, child: editButton),
                    ],
                  );
                }
                return Row(children: [
                  timerIcon,
                  SizedBox(width: 12),
                  Expanded(child: durationLabel),
                  editButton,
                ]);
              },
            ),
          ),
          SizedBox(height: 12),
          Row(children: [Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('کلید پاسخ اختیاری', style: TextStyle(fontWeight: FontWeight.w700)), Text(_answerKey.isEmpty ? 'هنوز کلیدی ثبت نشده' : 'کلید ${_answerKey.length} سؤال وارد شده', style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant))])), GlassButton.custom(
                      width: 112,
                      height: 40,
                      shape: const LiquidRoundedSuperellipse(borderRadius: 13),
                      quality: GlassQuality.standard,
                      style: GlassButtonStyle.filled,
                      onTap: _editSetupAnswerKey,
                      child: const Text('ورود کلید'),
                    )]),
          const SizedBox(height: 8),
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () => setState(() => _negativeMarking = !_negativeMarking),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('محاسبه با نمره منفی', style: TextStyle(fontWeight: FontWeight.w700)),
                          const SizedBox(height: 3),
                          Text(
                            'هر سه پاسخ غلط، معادل یک پاسخ درست کسر می‌شود.',
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IgnorePointer(
                      child: GlassSwitch(
                        value: _negativeMarking,
                        activeColor: DarsYarTokens.accent,
                        semanticLabel: 'محاسبه با نمره منفی',
                        quality: GlassQuality.standard,
                        onChanged: (value) => setState(() => _negativeMarking = value),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: GlassButton.custom(
              height: 52,
              shape: const LiquidRoundedSuperellipse(borderRadius: 17),
              quality: GlassQuality.standard,
              style: GlassButtonStyle.prominent,
              onTap: _submit,
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 10),
                child: Text(
                  'ساخت پاسخ‌برگ و شروع آزمون',
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  softWrap: true,
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                ),
              ),
            ),
          ),
          SizedBox(height: 4),
          Text('ثبت کلید پاسخ اختیاری است و می‌توانی بعد از آزمون آن را وارد کنی.',
            style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
        ]),
      )),
    ],
  );
}


class ExamDurationDialog extends StatefulWidget {
  const ExamDurationDialog({super.key, required this.initialDuration, required this.onMessage});

  final Duration initialDuration;
  final ValueChanged<String> onMessage;

  @override
  State<ExamDurationDialog> createState() => ExamDurationDialogState();
}

class ExamDurationDialogState extends State<ExamDurationDialog> {
  late final TextEditingController _hours;
  late final TextEditingController _minutes;
  late final TextEditingController _seconds;

  @override
  void initState() {
    super.initState();
    _hours = TextEditingController(text: widget.initialDuration.inHours.toString());
    _minutes = TextEditingController(
      text: widget.initialDuration.inMinutes.remainder(60).toString(),
    );
    _seconds = TextEditingController(
      text: widget.initialDuration.inSeconds.remainder(60).toString(),
    );
  }

  @override
  void dispose() {
    _hours.dispose();
    _minutes.dispose();
    _seconds.dispose();
    super.dispose();
  }

  void _setPreset(int minutes) {
    setState(() {
      _hours.text = (minutes ~/ 60).toString();
      _minutes.text = (minutes % 60).toString();
      _seconds.text = '0';
    });
  }

  void _submit() {
    final hours = int.tryParse(_hours.text) ?? -1;
    final minutes = int.tryParse(_minutes.text) ?? -1;
    final seconds = int.tryParse(_seconds.text) ?? -1;
    if (hours < 0 || hours > 24 ||
        minutes < 0 || minutes > 59 ||
        seconds < 0 || seconds > 59 ||
        (hours == 24 && (minutes != 0 || seconds != 0))) {
      widget.onMessage('ساعت باید حداکثر ۲۴ و دقیقه و ثانیه کمتر از ۶۰ باشند.');
      return;
    }
    final duration = Duration(hours: hours, minutes: minutes, seconds: seconds);
    if (duration.inSeconds < 1) {
      widget.onMessage('زمان آزمون باید حداقل یک ثانیه باشد.');
      return;
    }
    Navigator.of(context).pop(duration);
  }

  Widget _timeField(String label, TextEditingController controller) =>
      Expanded(
        child: GlassFormField(
          label: label,
          child: GlassTextField(
            surfaceStyle: GlassSurfaceStyle.solid,
            controller: controller,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(2),
            ],
            maxLength: 2,
            quality: GlassQuality.standard,
            onChanged: (_) => setState(() {}),
            textInputAction: TextInputAction.next,
          ),
        ),
      );

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
          'تنظیم زمان آزمون',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'زمان را به ساعت، دقیقه و ثانیه وارد کن.',
          style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 18),
        if (MediaQuery.sizeOf(context).width < 460)
          Column(
            children: [
              GlassFormField(
                label: 'ساعت',
                child: GlassTextField(
                  surfaceStyle: GlassSurfaceStyle.solid,
                  controller: _hours,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(2),
                  ],
                  maxLength: 2,
                  quality: GlassQuality.standard,
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(height: 12),
              GlassFormField(
                label: 'دقیقه',
                child: GlassTextField(
                  surfaceStyle: GlassSurfaceStyle.solid,
                  controller: _minutes,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(2),
                  ],
                  maxLength: 2,
                  quality: GlassQuality.standard,
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(height: 12),
              GlassFormField(
                label: 'ثانیه',
                child: GlassTextField(
                  surfaceStyle: GlassSurfaceStyle.solid,
                  controller: _seconds,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(2),
                  ],
                  maxLength: 2,
                  quality: GlassQuality.standard,
                  onChanged: (_) => setState(() {}),
                ),
              ),
            ],
          )
        else
          Row(
            children: [
              _timeField('ساعت', _hours),
              const SizedBox(width: 8),
              _timeField('دقیقه', _minutes),
              const SizedBox(width: 8),
              _timeField('ثانیه', _seconds),
            ],
          ),
        const SizedBox(height: 20),
        Text(
          'زمان‌های پیشنهادی',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final preset in [15, 30, 45, 60, 90, 120])
              GlassChip(
                label: '$preset دقیقه',
                selected: _hours.text == (preset ~/ 60).toString() &&
                    _minutes.text == (preset % 60).toString() &&
                    _seconds.text == '0',
                selectedColor: DarsYarTokens.accent.withValues(alpha: 0.16),
                quality: GlassQuality.standard,
                onTap: () => _setPreset(preset),
              ),
          ],
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
                child: const Text(
                  'ذخیره زمان',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ],
        ),
      ],
    ),
  );
  }
}

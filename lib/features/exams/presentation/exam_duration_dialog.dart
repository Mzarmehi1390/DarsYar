import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import '../../../design_system/darsyar_theme.dart';
import '../../../design_system/modal_content.dart';
import '../../../design_system/input_focus_behavior.dart';

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
          child: DarsYarInputFocusBehavior(
            controller: controller,
            child: GlassTextField(
            surfaceStyle: GlassSurfaceStyle.solid,
            controller: controller,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(2),
            ],
            maxLength: 2,
            onChanged: (_) => setState(() {}),
            textInputAction: TextInputAction.next,
          )),
        ),
      );

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
          'تنظیم زمان آزمون',
          style: TextStyle(
            fontSize: 18,
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
                child: DarsYarInputFocusBehavior(
                  controller: _hours,
                  child: GlassTextField(
                  surfaceStyle: GlassSurfaceStyle.solid,
                  controller: _hours,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(2),
                  ],
                  maxLength: 2,
                  onChanged: (_) => setState(() {}),
                )),
              ),
              const SizedBox(height: 12),
              GlassFormField(
                label: 'دقیقه',
                child: DarsYarInputFocusBehavior(
                  controller: _minutes,
                  child: GlassTextField(
                  surfaceStyle: GlassSurfaceStyle.solid,
                  controller: _minutes,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(2),
                  ],
                  maxLength: 2,
                  onChanged: (_) => setState(() {}),
                )),
              ),
              const SizedBox(height: 12),
              GlassFormField(
                label: 'ثانیه',
                child: DarsYarInputFocusBehavior(
                  controller: _seconds,
                  child: GlassTextField(
                  surfaceStyle: GlassSurfaceStyle.solid,
                  controller: _seconds,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(2),
                  ],
                  maxLength: 2,
                  onChanged: (_) => setState(() {}),
                )),
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
            ],
          ),
        ),
      ),
      const Divider(height: 1),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(0, 10, 0, 8),
            child: Row(
          children: [
            Expanded(
              child: GlassButton.custom(
                height: 48,
                shape: const LiquidRoundedSuperellipse(borderRadius: 16),
                quality: GlassQuality.standard,
                onTap: () => Navigator.of(context).pop(),
                child: const DarsYarModalButtonLabel(child: Text('انصراف')),
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
                child: const DarsYarModalButtonLabel(
                  primary: true,
                  child: Text('ذخیره زمان'),
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
}

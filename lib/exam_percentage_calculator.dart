import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import 'design_system/glass_surface.dart';

class ExamPercentageResult {
  const ExamPercentageResult({
    required this.withoutPenalty,
    required this.withPenalty,
  });

  final double? withoutPenalty;
  final double? withPenalty;
}

ExamPercentageResult calculateExamPercentages({
  required int correct,
  required int wrong,
  required int unanswered,
}) {
  final total = correct + wrong + unanswered;
  if (correct < 0 || wrong < 0 || unanswered < 0 || total < 1 || total > 200) {
    return const ExamPercentageResult(
      withoutPenalty: null,
      withPenalty: null,
    );
  }
  final plain = correct * 100 / total;
  final penalized = ((correct - wrong / 3) * 100 / total)
      .clamp(0.0, 100.0).toDouble();
  return ExamPercentageResult(
    withoutPenalty: plain,
    withPenalty: penalized,
  );
}

/// Standalone what-if calculator for exam percentages.
/// The three counts are user-entered; wrong answers cost one third of a
/// correct answer in the negative-marking scenario.
class ExamPercentageCalculator extends StatefulWidget {
  const ExamPercentageCalculator({super.key});

  @override
  State<ExamPercentageCalculator> createState() =>
      _ExamPercentageCalculatorState();
}

class _ExamPercentageCalculatorState extends State<ExamPercentageCalculator> {
  late final TextEditingController _correct;
  late final TextEditingController _wrong;
  late final TextEditingController _unanswered;

  @override
  void initState() {
    super.initState();
    _correct = TextEditingController(text: '0');
    _wrong = TextEditingController(text: '0');
    _unanswered = TextEditingController(text: '0');
  }

  @override
  void dispose() {
    _correct.dispose();
    _wrong.dispose();
    _unanswered.dispose();
    super.dispose();
  }

  int _read(TextEditingController controller) =>
      int.tryParse(controller.text.trim()) ?? 0;

  ExamPercentageResult get _result => calculateExamPercentages(
        correct: _read(_correct),
        wrong: _read(_wrong),
        unanswered: _read(_unanswered),
      );

  String _format(double? value) =>
      value == null ? '—' : '${value.toStringAsFixed(1)}٪';

  Widget _countField(String label, TextEditingController controller) =>
      SizedBox(
        width: 88,
        child: GlassFormField(
          label: label,
          child: Focus(
            onFocusChange: (hasFocus) {
              if (hasFocus && controller.text == '0') {
                controller.selection = TextSelection(
                  baseOffset: 0,
                  extentOffset: controller.text.length,
                );
              }
            },
            child: GlassTextField(
              surfaceStyle: GlassSurfaceStyle.solid,
              controller: controller,
              keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(3),
            ],
              onChanged: (_) => setState(() {}),
            ),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final result = _result;
    final valid = result.withoutPenalty != null;
    return DarsYarContentSurface(
      radius: 22,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.calculate_outlined, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'ماشین‌حساب درصد آزمون',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            'تعداد پاسخ‌های درست، غلط و بی‌پاسخ را وارد کن؛ مجموع باید حداکثر ۲۰۰ باشد.',
            style: TextStyle(fontSize: 12, height: 1.5, color: muted),
          ),
          const SizedBox(height: 16),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            runSpacing: 12,
            children: [
              _countField('درست', _correct),
              _countField('غلط', _wrong),
              _countField('بی‌پاسخ', _unanswered),
            ],
          ),
          if (!valid) ...[
            const SizedBox(height: 8),
            Text(
              'برای محاسبه، تعدادها را طوری وارد کن که مجموع بین ۱ تا ۲۰۰ باشد.',
              style: TextStyle(color: theme.colorScheme.error, fontSize: 12),
            ),
          ],
          const SizedBox(height: 16),
          _resultRow(
            context,
            'بدون نمره منفی',
            _format(result.withoutPenalty),
            Icons.check_circle_outline_rounded,
          ),
          const SizedBox(height: 8),
          _resultRow(
            context,
            'با نمره منفی (هر ۳ غلط = ۱ درست)',
            _format(result.withPenalty),
            Icons.remove_circle_outline_rounded,
          ),
        ],
      ),
    );
  }

  Widget _resultRow(
    BuildContext context,
    String label,
    String value,
    IconData icon,
  ) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, size: 18, color: theme.colorScheme.primary),
        const SizedBox(width: 8),
        Expanded(
          child: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        ),
        Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
      ],
    );
  }
}

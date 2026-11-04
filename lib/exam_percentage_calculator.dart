import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import 'design_system/glass_surface.dart';

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

  double? get _plainPercentage {
    final correct = _read(_correct);
    final wrong = _read(_wrong);
    final unanswered = _read(_unanswered);
    final total = correct + wrong + unanswered;
    if (correct < 0 || wrong < 0 || unanswered < 0 || total == 0 || total > 200) {
      return null;
    }
    return correct * 100 / total;
  }

  double? get _negativePercentage {
    final plain = _plainPercentage;
    if (plain == null) return null;
    final total = _read(_correct) + _read(_wrong) + _read(_unanswered);
    final score = _read(_correct) - _read(_wrong) / 3;
    return (score * 100 / total).clamp(0.0, 100.0).toDouble();
  }

  String _format(double? value) =>
      value == null ? '—' : '${value.toStringAsFixed(1)}٪';

  Widget _countField(String label, TextEditingController controller) =>
      SizedBox(
        width: 88,
        child: GlassFormField(
          label: label,
          child: GlassTextField(
            surfaceStyle: GlassSurfaceStyle.solid,
            controller: controller,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(3),
            ],
            onChanged: (_) => setState(() {}),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final valid = _plainPercentage != null;
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
            _format(_plainPercentage),
            Icons.check_circle_outline_rounded,
          ),
          const SizedBox(height: 8),
          _resultRow(
            context,
            'با نمره منفی (هر ۳ غلط = ۱ درست)',
            _format(_negativePercentage),
            Icons.remove_circle_outline_rounded,
          ),
          const SizedBox(height: 8),
          _resultRow(
            context,
            'اگر پاسخ‌های غلط را سفید می‌گذاشتی',
            _format(_plainPercentage),
            Icons.lightbulb_outline_rounded,
          ),
          const SizedBox(height: 8),
          Text(
            'در حالت آخر، پاسخ‌های غلط بی‌پاسخ فرض می‌شوند؛ بنابراین فقط جریمه نمره منفی حذف می‌شود.',
            style: TextStyle(fontSize: 11, height: 1.45, color: muted),
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

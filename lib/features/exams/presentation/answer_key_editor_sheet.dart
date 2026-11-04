import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import '../../../design_system/darsyar_theme.dart';
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
  late final Map<int, ValueNotifier<int?>> _selectedByQuestion;
  late final ValueNotifier<int> _answeredCount;

  static const _options = ['الف', 'ب', 'ج', 'د'];

  @override
  void initState() {
    super.initState();
    final questionCount = widget.questionCount.clamp(0, 200);
    // Ignore stale keys outside the current exam and invalid option indices.
    // Otherwise the progress counter can exceed the question count and a
    // later save can silently preserve answers that have no visible row.
    _draft = Map<int, int>.fromEntries(
      widget.initialAnswers.entries.where(
        (entry) => entry.key >= 1 &&
            entry.key <= questionCount &&
            entry.value >= 0 &&
            entry.value < _options.length,
      ),
    );
    _selectedByQuestion = {
      for (var question = 1; question <= questionCount; question++)
        question: ValueNotifier<int?>(_draft[question]),
    };
    _answeredCount = ValueNotifier<int>(_draft.length);
  }

  @override
  void dispose() {
    for (final selected in _selectedByQuestion.values) {
      selected.dispose();
    }
    _answeredCount.dispose();
    super.dispose();
  }

  void _selectAnswer(int question, int option) {
    final selected = _selectedByQuestion[question];
    if (selected == null) return;

    if (selected.value == option) {
      _draft.remove(question);
      selected.value = null;
    } else {
      _draft[question] = option;
      selected.value = option;
    }
    _answeredCount.value = _draft.length;
  }

  void _clearAnswers() {
    _draft.clear();
    for (final selected in _selectedByQuestion.values) {
      selected.value = null;
    }
    _answeredCount.value = 0;
  }

  Widget _questionRow(int question) {
    return ValueListenableBuilder<int?>(
      valueListenable: _selectedByQuestion[question]!,
      builder: (context, selectedOption, _) {
        final scheme = Theme.of(context).colorScheme;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 7),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest.withValues(alpha: 0.24),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: scheme.outlineVariant.withValues(alpha: 0.34),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
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
                      _answerOption(
                        question,
                        option,
                        selected: selectedOption == option,
                        scheme: scheme,
                      ),
                  ],
                ),
              ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// Keep the dense answer grid shader-free: the surrounding sheet retains
  /// its Liquid Glass material while individual choices stay inexpensive.
  Widget _answerOption(
    int question,
    int option, {
    required bool selected,
    required ColorScheme scheme,
  }) {
    return Semantics(
      container: true,
      button: true,
      selected: selected,
      label: 'سؤال $question، گزینه ${_options[option]}',
      child: ExcludeSemantics(
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(11),
            onTap: () => _selectAnswer(question, option),
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
      ),
    );
  }

  Widget _footerActions() => Padding(
        padding: const EdgeInsets.fromLTRB(0, 10, 0, 8),
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
              onTap: _clearAnswers,
              child: DarsYarModalButtonLabel(child: Text(widget.clearLabel)),
            ),
            GlassButton.custom(
              width: 96,
              height: 44,
              shape: const LiquidRoundedSuperellipse(borderRadius: 15),
              quality: GlassQuality.standard,
              onTap: () => Navigator.of(context).pop(),
              child: const DarsYarModalButtonLabel(child: Text('انصراف')),
            ),
            GlassButton.custom(
              width: 122,
              height: 44,
              shape: const LiquidRoundedSuperellipse(borderRadius: 15),
              quality: GlassQuality.standard,
              style: GlassButtonStyle.filled,
              onTap: () => Navigator.of(context).pop(Map<int, int>.from(_draft)),
              child: DarsYarModalButtonLabel(
                primary: true,
                child: Text(widget.saveLabel),
              ),
            ),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    final questionCount = widget.questionCount.clamp(0, 200);
    final scrollData = ScrollControllerProvider.of(context);
    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            controller: scrollData?.controller,
            physics: scrollData?.physics,
            padding: EdgeInsets.zero,
            itemCount: questionCount + 3,
            itemBuilder: (context, index) {
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              widget.title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          );
        }
        if (index == 1) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: ValueListenableBuilder<int>(
              valueListenable: _answeredCount,
              builder: (context, answeredCount, _) => Text(
                '$answeredCount از $questionCount سؤال دارای کلید پاسخ است.',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          );
        }
        if (index == 2) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: ValueListenableBuilder<int>(
                valueListenable: _answeredCount,
                builder: (context, answeredCount, _) =>
                    GlassProgressIndicator.linear(
                  height: 5,
                  minWidth: 0,
                  value: questionCount == 0
                      ? 0
                      : (answeredCount / questionCount).clamp(0.0, 1.0),
                  color: DarsYarTokens.accent,
                  backgroundColor: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.08),
                  quality: GlassQuality.standard,
                  semanticLabel: 'پیشرفت ورود کلید پاسخ',
                ),
              ),
            ),
          );
        }
              return _questionRow(index - 2);
            },
          ),
        ),
        const Divider(height: 1),
        _footerActions(),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import '../../../design_system/darsyar_theme.dart';

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
      container: true,
      button: true,
      selected: selected,
      label: 'سؤال $question، گزینه ${_options[option]}',
      child: ExcludeSemantics(
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

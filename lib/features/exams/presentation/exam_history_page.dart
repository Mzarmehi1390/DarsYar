import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import '../../../design_system/darsyar_theme.dart';
import '../../../design_system/glass_surface.dart';
import '../../../exam_result.dart';
import 'exam_result_card.dart';

/// Presentation for saved exam history and the recent score trend.
class ExamHistoryPage extends StatelessWidget {
  const ExamHistoryPage({
    super.key,
    required this.results,
    required this.summaryBuilder,
    required this.emptyState,
    required this.onAddAnswerKey,
  });

  final List<ExamResult> results;
  final Widget Function(String label, int? value, IconData icon) summaryBuilder;
  final Widget emptyState;
  final Future<void> Function(ExamResult result) onAddAnswerKey;

  @override
  Widget build(BuildContext context) {
    final sorted = results.toList()
      ..sort((a, b) => b.dateTime.compareTo(a.dateTime));
    final chartResults = sorted
        .where((result) => result.percentage != null)
        .take(7)
        .toList()
        .reversed
        .toList();
    final scoredResults =
        results.where((result) => result.percentage != null).toList();
    final average = scoredResults.isEmpty
        ? 0.0
        : scoredResults
                .map((result) => result.percentage!)
                .reduce((a, b) => a + b) /
            scoredResults.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'تاریخچه و پیشرفت',
          style: TextStyle(
            fontSize: 25,
            fontWeight: FontWeight.w800,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'نتایج ذخیره‌شده آزمون‌ها و روند درصدها را دنبال کن.',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(
              child: summaryBuilder(
                'آزمون‌ها',
                results.length,
                Icons.assignment_turned_in_outlined,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: summaryBuilder(
                'میانگین درصد',
                scoredResults.isEmpty ? null : average.round(),
                Icons.insights_rounded,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        if (results.isEmpty)
          emptyState
        else ...[
          if (chartResults.isNotEmpty) ...[
            Text(
              'روند ۷ نتیجه اخیر',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 12),
            DarsYarContentSurface(
              radius: 20,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  children: [
                    for (var i = 0; i < chartResults.length; i++)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 7),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 26,
                              child: Text(
                                '${i + 1}',
                                style: TextStyle(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                ),
                              ),
                            ),
                            Expanded(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: GlassProgressIndicator.linear(
                                  height: 12,
                                  minWidth: 0,
                                  value: ((chartResults[i].percentage ?? 0) /
                                          100)
                                      .clamp(0.0, 1.0)
                                      .toDouble(),
                                  color: DarsYarTokens.accent,
                                  backgroundColor: Theme.of(context)
                                      .colorScheme
                                      .surfaceContainerHighest,
                                  quality: GlassQuality.standard,
                                  semanticLabel: 'درصد نتیجه آزمون',
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            SizedBox(
                              width: 46,
                              child: Text(
                                '${chartResults[i].percentage?.round() ?? '—'}%',
                                textAlign: TextAlign.end,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 20),
          Text(
            'همه نتایج',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 10),
          for (final result in sorted)
            ExamResultCard(
              result: result,
              onAddAnswerKey: () => onAddAnswerKey(result),
            ),
        ],
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import '../../../design_system/page_header.dart';
import 'exam_setup_widgets.dart';

class ExamPage extends StatelessWidget {
  const ExamPage({
    super.key,
    required this.isTakingExam,
    required this.examSection,
    required this.onExamSectionChanged,
    required this.onCreate,
    required this.onMessage,
    required this.takingExamBuilder,
    required this.myExamsBuilder,
  });

  final bool isTakingExam;
  final int examSection;
  final ValueChanged<int> onExamSectionChanged;
  final void Function(String, int, int, bool, Map<int, int>) onCreate;
  final ValueChanged<String> onMessage;
  final Widget Function() takingExamBuilder;
  final Widget Function() myExamsBuilder;

  @override
  Widget build(BuildContext context) {
    if (isTakingExam) return takingExamBuilder();
    return Column(children: [
      Padding(
        padding: const EdgeInsets.all(18),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const DarsYarPageHeader(
            title: 'پاسخ‌برگ آزمون',
            subtitle: 'آزمون بساز، پاسخ‌ها را ثبت کن و نتیجه‌ها را بررسی کن.',
            icon: Icons.fact_check_rounded,
          ),
          const SizedBox(height: 14),
          GlassSegmentedControl(
            segments: const [
              GlassSegment(
                label: 'ساخت آزمون جدید',
                semanticLabel: 'ساخت آزمون جدید',
              ),
              GlassSegment(
                label: 'آزمون‌های من',
                semanticLabel: 'آزمون‌های من',
              ),
            ],
            selectedIndex: examSection,
            onSegmentSelected: onExamSectionChanged,
            height: 46,
            borderRadius: 20,
            useOwnLayer: true,
            quality: GlassQuality.standard,
            selectedTextStyle: TextStyle(
              color: Theme.of(context).colorScheme.onSurface,
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
            ),
            unselectedTextStyle: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
            ),
            backgroundColor: Theme.of(context).colorScheme.surface.withValues(alpha: 0.22),
            indicatorColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
          ),
        ]),
      ),
      Expanded(
        child: examSection == 0
            ? ExamSetupPanel(onCreate: onCreate, onMessage: onMessage)
            : myExamsBuilder(),
      ),
    ]);
  }
}

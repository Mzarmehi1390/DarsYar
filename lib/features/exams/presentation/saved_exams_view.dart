import 'package:flutter/material.dart';

import '../../../design_system/darsyar_theme.dart';
import '../domain/models/exam_sheet.dart';

/// Scrollable saved-answer-sheet history, independent from exam orchestration.
class SavedExamsView extends StatelessWidget {
  const SavedExamsView({
    required this.exams,
    required this.savedExamCardBuilder,
    required this.emptyStateBuilder,
    required this.resultsHistoryBuilder,
    super.key,
  });

  final List<ExamSheet> exams;
  final Widget Function(ExamSheet exam) savedExamCardBuilder;
  final Widget Function(IconData icon, String title, String subtitle)
      emptyStateBuilder;
  final Widget Function() resultsHistoryBuilder;

  @override
  Widget build(BuildContext context) {
    final savedExams = exams.reversed.toList(growable: false);
    final empty = savedExams.isEmpty;
    final itemCount = empty ? 7 : savedExams.length + 6;

    return CustomScrollView(
      key: const PageStorageKey<String>('my-exams-scroll'),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(
            16,
            8,
            16,
            DarsYarTokens.pageBottomClearance,
          ),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                if (index == 0) {
                  return const Text(
                    'پاسخ‌برگ‌های ذخیره‌شده',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                  );
                }
                if (index == 1) return const SizedBox(height: 10);

                if (empty) {
                  switch (index) {
                    case 2:
                      return emptyStateBuilder(
                        Icons.assignment_outlined,
                        'هنوز آزمونی نساخته‌ای',
                        'از بخش ساخت آزمون جدید، اولین پاسخ‌برگت را ایجاد کن.',
                      );
                    case 3:
                      return const SizedBox(height: 14);
                    case 4:
                      return const Text(
                        'نتایج آزمون‌ها',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                      );
                    case 5:
                      return const SizedBox(height: 8);
                    case 6:
                      return resultsHistoryBuilder();
                  }
                } else {
                  final examIndex = index - 2;
                  if (examIndex < savedExams.length) {
                    return savedExamCardBuilder(savedExams[examIndex]);
                  }
                  switch (examIndex - savedExams.length) {
                    case 0:
                      return const SizedBox(height: 14);
                    case 1:
                      return const Text(
                        'نتایج آزمون‌ها',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                      );
                    case 2:
                      return const SizedBox(height: 8);
                    case 3:
                      return resultsHistoryBuilder();
                  }
                }
                return const SizedBox.shrink();
              },
              childCount: itemCount,
              addAutomaticKeepAlives: false,
              addRepaintBoundaries: true,
            ),
          ),
        ),
      ],
    );
  }
}

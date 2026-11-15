import '../domain/models/exam_result.dart';
import '../domain/models/exam_sheet.dart';

/// Owns answer-sheet mutations independently from widget lifecycle and UI.
class ExamSheetController {
  const ExamSheetController();

  ExamSheet create({
    required String id,
    required String name,
    int questionCount = 20,
    int durationSeconds = 30 * 60,
    bool negativeMarking = false,
    Map<int, int>? answerKey,
  }) => ExamSheet(
    id: id,
    name: name,
    questionCount: questionCount,
    durationSeconds: durationSeconds,
    negativeMarking: negativeMarking,
    answerKey: answerKey,
  );

  void rename({
    required ExamSheet exam,
    required List<ExamResult> results,
    required String name,
  }) {
    final previousName = exam.name;
    exam.name = name;
    for (var index = 0; index < results.length; index++) {
      final result = results[index];
      if (result.examId == exam.id ||
          (result.examId == null && result.examName == previousName)) {
        results[index] = result.copyWith(examName: name);
      }
    }
  }

  /// Removes a sheet and its linked history, returning the next active ID.
  /// The final remaining sheet is protected even if called outside the UI.
  String delete({
    required List<ExamSheet> exams,
    required List<ExamResult> results,
    required String activeExamId,
  }) {
    if (exams.length <= 1) {
      throw StateError('At least one exam sheet must remain.');
    }
    final index = exams.indexWhere((exam) => exam.id == activeExamId);
    if (index < 0) throw StateError('Active exam sheet was not found.');
    final deleted = exams.removeAt(index);
    results.removeWhere((result) =>
      result.examId == deleted.id ||
      (result.examId == null && result.examName == deleted.name)
    );
    return exams[(index - 1).clamp(0, exams.length - 1).toInt()].id;
  }

  void resize(ExamSheet exam, int questionCount) {
    final nextCount = questionCount.clamp(1, 200).toInt();
    exam.questionCount = nextCount;
    exam.answers.removeWhere((question, _) => question > nextCount);
    exam.answerKey.removeWhere((question, _) => question > nextCount);
    exam.marked.removeWhere((question) => question > nextCount);
  }

  void setAnswer({
    required ExamSheet exam,
    required int question,
    required int? answer,
    required bool marked,
  }) {
    if (answer != null) {
      exam.answers[question] = answer;
      exam.marked.remove(question);
      return;
    }
    exam.answers.remove(question);
    if (marked) {
      exam.marked.add(question);
    } else {
      exam.marked.remove(question);
    }
  }

  void replaceAnswerKey(ExamSheet exam, Map<int, int> answerKey) {
    exam.answerKey
      ..clear()
      ..addAll(answerKey);
  }
}

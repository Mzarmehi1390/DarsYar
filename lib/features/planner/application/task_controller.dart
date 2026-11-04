import '../../../models/study_task.dart';

/// Owns task-list mutations used by the planner and dashboard.
class TaskController {
  const TaskController();

  int completedCount(Iterable<StudyTask> tasks) =>
      tasks.where((task) => task.done).length;

  void toggleCompletion(StudyTask task) {
    task.done = !task.done;
  }

  void removeById(List<StudyTask> tasks, String id) {
    tasks.removeWhere((task) => task.id == id);
  }

  void upsert({
    required List<StudyTask> tasks,
    required String title,
    required String subject,
    StudyTask? existing,
    required String Function() createId,
  }) {
    final normalizedSubject = subject.isEmpty ? 'عمومی' : subject;
    if (existing == null) {
      tasks.add(StudyTask(createId(), title, normalizedSubject));
      return;
    }

    final index = tasks.indexWhere((task) => task.id == existing.id);
    if (index < 0) return;
    tasks[index] = StudyTask(
      existing.id,
      title,
      normalizedSubject,
      done: existing.done,
    );
  }
}

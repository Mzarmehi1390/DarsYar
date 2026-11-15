/// A scheduled study task shown in the planner and dashboard.
class StudyTask {
  StudyTask(this.id, this.title, this.subject, {
    this.done = false,
    this.dueDate,
  });

  final String id;
  final String title;
  final String subject;
  bool done;
  /// Optional local calendar due date; null means an unscheduled task.
  final DateTime? dueDate;

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'subject': subject,
    'done': done,
    if (dueDate != null) 'dueDate': _taskDateKey(dueDate!),
  };

  factory StudyTask.fromJson(Map<String, dynamic> json) {
    final rawDate = json['dueDate'];
    final parsedDate = rawDate is String ? DateTime.tryParse(rawDate) : null;
    return StudyTask(
      json['id'] as String,
      json['title'] as String,
      json['subject'] as String? ?? 'عمومی',
      done: json['done'] as bool? ?? false,
      dueDate: parsedDate == null
          ? null
          : DateTime(parsedDate.year, parsedDate.month, parsedDate.day),
    );
  }
}

String _taskDateKey(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

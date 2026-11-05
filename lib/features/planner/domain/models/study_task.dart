/// A scheduled study task shown in the planner and dashboard.
class StudyTask {
  StudyTask(this.id, this.title, this.subject, {this.done = false});

  final String id;
  final String title;
  final String subject;
  bool done;

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'subject': subject,
    'done': done,
  };

  factory StudyTask.fromJson(Map<String, dynamic> json) => StudyTask(
    json['id'] as String,
    json['title'] as String,
    json['subject'] as String? ?? 'عمومی',
    done: json['done'] as bool? ?? false,
  );
}

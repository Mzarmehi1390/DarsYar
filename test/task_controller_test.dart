import 'package:flutter_test/flutter_test.dart';
import 'package:dars_yar/features/planner/application/task_controller.dart';
import 'package:dars_yar/models/study_task.dart';

void main() {
  const controller = TaskController();

  test('completion count and toggle stay in sync', () {
    final tasks = [
      StudyTask('a', 'تمرین', 'ریاضی'),
      StudyTask('b', 'مرور', 'علوم', done: true),
    ];

    expect(controller.completedCount(tasks), 1);
    controller.toggleCompletion(tasks.first);
    expect(controller.completedCount(tasks), 2);
    controller.toggleCompletion(tasks.last);
    expect(controller.completedCount(tasks), 1);
  });

  test('upsert creates tasks and preserves completion on edit', () {
    final tasks = <StudyTask>[];
    controller.upsert(
      tasks: tasks,
      title: 'تمرین جدید',
      subject: '',
      createId: () => 'task-1',
    );
    expect(tasks.single.id, 'task-1');
    expect(tasks.single.subject, 'عمومی');

    tasks.single.done = true;
    controller.upsert(
      tasks: tasks,
      title: 'تمرین ویرایش‌شده',
      subject: 'فیزیک',
      existing: tasks.single,
      createId: () => 'unused',
    );
    expect(tasks, hasLength(1));
    expect(tasks.single.id, 'task-1');
    expect(tasks.single.title, 'تمرین ویرایش‌شده');
    expect(tasks.single.subject, 'فیزیک');
    expect(tasks.single.done, isTrue);
  });

  test('removeById removes only the requested task', () {
    final tasks = [
      StudyTask('a', 'اول', 'ریاضی'),
      StudyTask('b', 'دوم', 'علوم'),
    ];
    controller.removeById(tasks, 'a');
    expect(tasks.map((task) => task.id).toList(), ['b']);
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dars_yar/app/data/darsyar_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('DarsYarRepository', () {
    test('restores the legacy answer sheet without changing its data', () async {
      SharedPreferences.setMockInitialValues({
        'darsyar.answers': '{"1":2,"3":0}',
        'darsyar.answerKey': '{"1":1,"3":0}',
        'darsyar.marked': '[3]',
        'darsyar.count': 12,
      });

      final snapshot = await DarsYarRepository().load();

      expect(snapshot.exams, hasLength(1));
      expect(snapshot.exams.single.questionCount, 12);
      expect(snapshot.exams.single.answers, {1: 2, 3: 0});
      expect(snapshot.exams.single.answerKey, {1: 1, 3: 0});
      expect(snapshot.exams.single.marked, {3});
      expect(snapshot.activeExamId, 'default');
    });

    test('does not resurrect legacy data when current exam data is corrupt',
        () async {
      SharedPreferences.setMockInitialValues({
        'darsyar.exams': '{invalid-json',
        'darsyar.answers': '{"1":2}',
        'darsyar.answerKey': '{"1":3}',
        'darsyar.count': 40,
      });

      final snapshot = await DarsYarRepository().load();

      expect(snapshot.exams, hasLength(1));
      expect(snapshot.exams.single.questionCount, 20);
      expect(snapshot.exams.single.answers, isEmpty);
      expect(snapshot.exams.single.answerKey, isEmpty);
    });
  });
}

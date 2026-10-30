import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dars_yar/darsyar_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({
      'darsyar.tasks': '[{"id":"task-1"}]',
      'darsyar.count': 25,
      'darsyar.exams': '[]',
    });
  });

  test('reads existing storage keys without changing their representation', () async {
    final snapshot = await DarsYarStorage().readSnapshot();

    expect(snapshot.stringValue('darsyar.tasks'), '[{"id":"task-1"}]');
    expect(snapshot.intValue('darsyar.count'), 25);
    expect(snapshot.containsKey('darsyar.exams'), isTrue);
    expect(snapshot.stringValue('darsyar.missing'), isNull);
    expect(snapshot.containsKey('darsyar.missing'), isFalse);
  });

  test('serializes queued writes and persists the latest requested value', () async {
    final storage = DarsYarStorage();

    final first = storage.writeStrings({'darsyar.tasks': 'first'});
    final second = storage.writeStrings({'darsyar.tasks': 'second'});

    expect(await first, isTrue);
    expect(await second, isTrue);

    final snapshot = await storage.readSnapshot();
    expect(snapshot.stringValue('darsyar.tasks'), 'second');
  });

  test('writes only requested keys and preserves unrelated values', () async {
    final storage = DarsYarStorage();

    expect(await storage.writeStrings({'darsyar.tasks': '[]'}), isTrue);

    final snapshot = await storage.readSnapshot();
    expect(snapshot.stringValue('darsyar.tasks'), '[]');
    expect(snapshot.intValue('darsyar.count'), 25);
    expect(snapshot.stringValue('darsyar.exams'), '[]');
  });
}

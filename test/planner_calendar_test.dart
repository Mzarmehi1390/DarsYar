import 'package:flutter_test/flutter_test.dart';
import 'package:dars_yar/features/planner/domain/planner_calendar.dart';

void main() {
  group('PlannerCalendar', () {
    test('uses Saturday through Friday weeks', () {
      expect(PlannerCalendar.startOfWeek(DateTime(2026, 11, 15)), DateTime(2026, 11, 14));
      expect(PlannerCalendar.startOfWeek(DateTime(2026, 11, 20)), DateTime(2026, 11, 14));
      expect(PlannerCalendar.startOfWeek(DateTime(2026, 11, 21)), DateTime(2026, 11, 21));
    });
    test('maps legacy weekdays into the selected Saturday week', () {
      final start = DateTime(2026, 11, 14);
      expect(PlannerCalendar.dateForWeekday(start, 6), DateTime(2026, 11, 14));
      expect(PlannerCalendar.dateForWeekday(start, 0), DateTime(2026, 11, 15));
      expect(PlannerCalendar.dateForWeekday(start, 5), DateTime(2026, 11, 20));
    });
    test('distinguishes dates in different weeks', () {
      expect(PlannerCalendar.isInWeek(DateTime(2026, 11, 16), DateTime(2026, 11, 14)), isTrue);
      expect(PlannerCalendar.isInWeek(DateTime(2026, 11, 23), DateTime(2026, 11, 14)), isFalse);
    });
  });
}

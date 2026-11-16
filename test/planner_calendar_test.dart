import 'package:flutter_test/flutter_test.dart';
import 'package:dars_yar/features/planner/domain/planner_calendar.dart';

void main() {
  group('PlannerCalendar', () {
    test('uses Saturday through Friday weeks', () {
      expect(PlannerCalendar.startOfWeek(DateTime(2026, 11, 15)), DateTime(2026, 11, 14));
      expect(PlannerCalendar.startOfWeek(DateTime(2026, 11, 20)), DateTime(2026, 11, 14));
      expect(PlannerCalendar.startOfWeek(DateTime(2026, 11, 21)), DateTime(2026, 11, 21));
    });

    test('maps every legacy weekday to its matching date in the week', () {
      final start = DateTime(2026, 11, 14);
      for (var weekday = 0; weekday <= 6; weekday++) {
        final date = PlannerCalendar.dateForWeekday(start, weekday);
        expect(date.weekday % 7, weekday);
        expect(date, DateTime(2026, 11, 15 + weekday));
      }
      expect(PlannerCalendar.dateForWeekday(start, 6), DateTime(2026, 11, 14));
    });

    test('distinguishes dates in different weeks', () {
      expect(PlannerCalendar.isInWeek(DateTime(2026, 11, 16), DateTime(2026, 11, 14)), isTrue);
      expect(PlannerCalendar.isInWeek(DateTime(2026, 11, 23), DateTime(2026, 11, 14)), isFalse);
    });
  });
}

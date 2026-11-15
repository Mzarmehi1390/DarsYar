/// Calendar rules for the planner. Weeks follow the Iranian Saturday-Friday
/// convention while dates use the device's local calendar.
class PlannerCalendar {
  const PlannerCalendar._();

  static DateTime dateOnly(DateTime value) => DateTime(value.year, value.month, value.day);

  static DateTime startOfWeek(DateTime value) {
    final date = dateOnly(value);
    final daysSinceSaturday = (date.weekday + 1) % 7;
    return date.subtract(Duration(days: daysSinceSaturday));
  }

  static DateTime dateForWeekday(DateTime weekStart, int weekday) {
    assert(weekday >= 0 && weekday <= 6);
    final offset = weekday == 6 ? 0 : weekday + 1;
    return dateOnly(weekStart).add(Duration(days: offset));
  }

  static DateTime migrateLegacyDate(int weekday, DateTime reference) =>
      dateForWeekday(startOfWeek(reference), weekday);

  static bool isInWeek(DateTime date, DateTime weekStart) {
    final start = startOfWeek(weekStart);
    final value = dateOnly(date);
    return !value.isBefore(start) && value.isBefore(start.add(const Duration(days: 7)));
  }

  static List<DateTime> days(DateTime weekStart) => List<DateTime>.generate(
        7, (index) => dateOnly(weekStart).add(Duration(days: index)),
        growable: false,
      );

  static String dateKey(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
}

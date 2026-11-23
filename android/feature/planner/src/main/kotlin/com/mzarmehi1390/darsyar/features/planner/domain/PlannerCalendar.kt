package com.mzarmehi1390.darsyar.features.planner.domain

import java.time.DayOfWeek
import java.time.LocalDate
import java.time.format.DateTimeFormatter
import java.time.temporal.TemporalAdjusters

/** Saturday-Friday calendar rules matching the original planner and backup contract. */
object PlannerCalendar {
    private val dateFormatter = DateTimeFormatter.ISO_LOCAL_DATE

    fun startOfWeek(value: LocalDate): LocalDate =
        value.with(TemporalAdjusters.previousOrSame(DayOfWeek.SATURDAY))

    /** Dart-compatible weekday keys: Sunday=0 ... Saturday=6. */
    fun weekdayForDate(value: LocalDate): Int = value.dayOfWeek.value % 7

    fun dateForWeekday(weekStart: LocalDate, weekday: Int): LocalDate {
        require(weekday in 0..6) { "Weekday must be between 0 and 6." }
        return startOfWeek(weekStart).plusDays(((weekday + 1) % 7).toLong())
    }

    fun migrateLegacyDate(weekday: Int, reference: LocalDate): LocalDate =
        dateForWeekday(startOfWeek(reference), weekday)

    fun isInWeek(date: LocalDate, weekStart: LocalDate): Boolean {
        val start = startOfWeek(weekStart)
        return !date.isBefore(start) && date.isBefore(start.plusDays(7))
    }

    fun days(weekStart: LocalDate): List<LocalDate> =
        (0L..6L).map { startOfWeek(weekStart).plusDays(it) }

    fun dateKey(value: LocalDate): String = value.format(dateFormatter)

    fun parseDateKey(value: String?): LocalDate? =
        value?.let { runCatching { LocalDate.parse(it, dateFormatter) }.getOrNull() }
}

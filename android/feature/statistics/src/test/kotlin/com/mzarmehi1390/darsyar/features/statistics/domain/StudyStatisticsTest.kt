package com.mzarmehi1390.darsyar.features.statistics.domain

import com.mzarmehi1390.darsyar.features.planner.domain.models.StudySession
import com.mzarmehi1390.darsyar.features.planner.domain.models.StudyTask
import org.junit.Assert.assertEquals
import org.junit.Test
import java.time.LocalDate

class StudyStatisticsTest {
    private val saturday = LocalDate.parse("2026-11-21")

    @Test
    fun aggregatesDatedSessionsAndCompletedMinutesByPlannerWeek() {
        val sessions = listOf(
            session("1", "2026-11-21", 60, true),
            session("2", "2026-11-22", 45, false),
            session("3", "2026-11-27", 30, true),
            session("4", "2026-11-28", 90, true),
        )
        val result = StudyStatistics.calculate(sessions, emptyList(), saturday.plusDays(3))
        assertEquals(135, result.totalPlannedMinutes)
        assertEquals(90, result.totalCompletedMinutes)
        assertEquals(60, result.dailyTotals[0].completedMinutes)
        assertEquals(45, result.dailyTotals[1].plannedMinutes)
        assertEquals(30, result.dailyTotals[6].plannedMinutes)
        assertEquals(2.0 / 3.0, result.completion, 0.0001)
    }

    @Test
    fun legacyWeekdaySessionsAreMappedIntoCurrentPlannerWeek() {
        val legacySaturday = StudySession("legacy", "مرور", "علوم", 6, 540, 55, true)
        val result = StudyStatistics.calculate(listOf(legacySaturday), emptyList(), saturday)
        assertEquals(55, result.totalPlannedMinutes)
        assertEquals(55, result.dailyTotals.first().completedMinutes)
    }

    @Test
    fun malformedDatedSessionsAreIgnoredInsteadOfTreatedAsLegacy() {
        val malformed = session("bad", "not-a-date", 100, true)
        val result = StudyStatistics.calculate(
            listOf(malformed),
            listOf(StudyTask("t1", "تمرین", "ریاضی", done = true)),
            saturday,
        )
        assertEquals(0, result.totalPlannedMinutes)
        assertEquals(1, result.completedTaskCount)
        assertEquals(1, result.totalTaskCount)
        assertEquals(0.0, result.completion, 0.0)
        assertEquals(1.0, result.taskCompletion, 0.0)
    }

    private fun session(id: String, date: String, minutes: Int, completed: Boolean) =
        StudySession(id, "مطالعه", "علوم", 0, 540, minutes, completed, date)
}

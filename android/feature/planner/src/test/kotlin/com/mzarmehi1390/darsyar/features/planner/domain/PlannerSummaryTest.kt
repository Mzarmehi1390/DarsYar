package com.mzarmehi1390.darsyar.features.planner.domain

import com.mzarmehi1390.darsyar.features.planner.domain.models.StudySession
import org.junit.Assert.assertEquals
import org.junit.Test

class PlannerSummaryTest {
    @Test
    fun aggregatesDurationCompletionAndSaturdayBasedBuckets() {
        val sessions = listOf(
            StudySession("s1", "A", "Math", 1, 600, 55, completed = true, scheduledDate = "2026-11-23"),
            StudySession("s2", "B", "Science", 2, 500, 40, scheduledDate = "2026-11-24"),
            StudySession("s3", "C", "Persian", 6, 700, 30, scheduledDate = "2026-11-21"),
        )
        val summary = PlannerSummary.fromSessions(sessions)

        assertEquals(3, summary.totalSessionCount)
        assertEquals(1, summary.completedSessionCount)
        assertEquals(125, summary.plannedMinutes)
        assertEquals(55, summary.completedMinutes)
        assertEquals(55.0 / 125.0, summary.completion, 0.0001)
        assertEquals(55, summary.minutesByDay[1])
        assertEquals(40, summary.minutesByDay[2])
        assertEquals(30, summary.minutesByDay[6])
        assertEquals("s1", summary.sessionsByDay[1]?.single()?.id)
    }

    @Test
    fun emptyPlanHasZeroCompletionWithoutDivisionByZero() {
        val summary = PlannerSummary.fromSessions(emptyList())
        assertEquals(0, summary.totalSessionCount)
        assertEquals(0.0, summary.completion, 0.0)
    }

    @Test
    fun malformedDatedSessionsRemainInGlobalTotalsButAreExcludedFromDayBuckets() {
        val malformed = StudySession(
            "bad-date", "جلسه با تاریخ نامعتبر", "علوم",
            weekday = 2, startMinutes = 540, durationMinutes = 45,
            completed = true, scheduledDate = "24/11/2026",
        )
        val validLegacy = StudySession(
            "legacy", "جلسه هفتگی", "ریاضی",
            weekday = 2, startMinutes = 600, durationMinutes = 30,
        )

        val summary = PlannerSummary.fromSessions(listOf(malformed, validLegacy))

        assertEquals(2, summary.totalSessionCount)
        assertEquals(1, summary.completedSessionCount)
        assertEquals(75, summary.plannedMinutes)
        assertEquals(45, summary.completedMinutes)
        assertEquals(listOf("legacy"), summary.sessionsByDay[2]?.map { it.id })
        assertEquals(30, summary.minutesByDay[2])
    }

    @Test
    fun invalidLegacyWeekdayIsExcludedFromDayBuckets() {
        val invalidWeekday = StudySession(
            "bad-weekday", "جلسه با روز نامعتبر", "عمومی",
            weekday = 7, startMinutes = 540, durationMinutes = 20,
        )

        val summary = PlannerSummary.fromSessions(listOf(invalidWeekday))

        assertEquals(1, summary.totalSessionCount)
        assertEquals(20, summary.plannedMinutes)
        assertEquals(emptyMap<Int, List<StudySession>>(), summary.sessionsByDay)
        assertEquals(emptyMap<Int, Int>(), summary.minutesByDay)
    }
}

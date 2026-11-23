package com.mzarmehi1390.darsyar.features.planner.domain

import com.mzarmehi1390.darsyar.features.planner.domain.models.StudySession
import com.mzarmehi1390.darsyar.features.planner.domain.models.StudyTask
import java.time.LocalDate
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class PlannerCalendarTest {
    @Test
    fun weekStartsOnSaturdayAndContainsSevenDays() {
        val monday = LocalDate.parse("2026-11-23")
        val start = PlannerCalendar.startOfWeek(monday)

        assertEquals(LocalDate.parse("2026-11-21"), start)
        assertEquals(7, PlannerCalendar.days(start).size)
        assertEquals(LocalDate.parse("2026-11-27"), PlannerCalendar.days(start).last())
    }

    @Test
    fun dartWeekdayKeysMapToSaturdayBasedDates() {
        val saturday = LocalDate.parse("2026-11-21")
        assertEquals(LocalDate.parse("2026-11-22"), PlannerCalendar.dateForWeekday(saturday, 0))
        assertEquals(LocalDate.parse("2026-11-23"), PlannerCalendar.dateForWeekday(saturday, 1))
        assertEquals(saturday, PlannerCalendar.dateForWeekday(saturday, 6))
    }

    @Test
    fun legacyWeekdaySessionMigratesWithinReferenceWeek() {
        val legacy = StudySession(
            id = "s1", title = "ریاضی", subject = "ریاضی",
            weekday = 0, startMinutes = 600, durationMinutes = 55,
        )
        val migrated = PlannerOperations.migrateLegacySessions(
            listOf(legacy),
            LocalDate.parse("2026-11-25"),
        ).single()

        assertEquals("2026-11-22", migrated.scheduledDate)
        assertEquals(legacy.id, migrated.id)
    }

    @Test
    fun overlapUsesOccurrenceDateWhenBothDatesExist() {
        val monday = StudySession("a", "A", "Math", 1, 600, 60, scheduledDate = "2026-11-23")
        val otherMonday = StudySession("b", "B", "Math", 1, 630, 60, scheduledDate = "2026-11-30")
        assertFalse(PlannerOperations.hasOverlap(listOf(otherMonday), monday))
        assertTrue(PlannerOperations.hasOverlap(listOf(monday), monday.copy(id = "c", startMinutes = 630)))
    }

    @Test
    fun nextWeekCopyCreatesNewIdsAndResetsCompletion() {
        val session = StudySession(
            "s1", "Study", "Math", 1, 600, 55,
            completed = true, scheduledDate = "2026-11-23",
        )
        val task = StudyTask("t1", "Homework", "Math", done = true, dueDate = "2026-11-24")
        val plan = PlannerWeekCopyService().createNextWeekPlan(
            sessions = listOf(session),
            tasks = listOf(task),
            sourceWeekStart = LocalDate.parse("2026-11-23"),
            createSessionId = { "copy-${it.id}" },
            createTaskId = { "copy-${it.id}" },
        )

        assertEquals("2026-11-28", plan.targetWeekStart.toString())
        assertEquals("2026-11-30", plan.copiedSessions.single().scheduledDate)
        assertFalse(plan.copiedSessions.single().completed)
        assertEquals("2026-12-01", plan.copiedTasks.single().dueDate)
        assertFalse(plan.copiedTasks.single().done)
    }
}

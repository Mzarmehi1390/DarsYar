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
    fun editorWeekdayUsesInitialDateForLegacySession() {
        val selectedDate = LocalDate.parse("2026-11-24")
        assertEquals(
            PlannerCalendar.weekdayForDate(selectedDate),
            PlannerCalendar.weekdayForDateOrFallback(null, selectedDate),
        )
    }

    @Test
    fun editorWeekdayPrefersConcreteScheduledDate() {
        assertEquals(
            PlannerCalendar.weekdayForDate(LocalDate.parse("2026-11-25")),
            PlannerCalendar.weekdayForDateOrFallback("2026-11-25", LocalDate.parse("2026-11-24")),
        )
    }

    @Test
    fun sameOccurrenceHandlesDatedAndLegacyRecurringSessions() {
        assertTrue(
            PlannerCalendar.sameOccurrence(
                firstDateKey = "2026-11-24",
                firstWeekday = 1,
                secondDateKey = null,
                secondWeekday = 2,
            ),
        )
        assertFalse(
            PlannerCalendar.sameOccurrence(
                firstDateKey = "2026-11-24",
                firstWeekday = 1,
                secondDateKey = null,
                secondWeekday = 1,
            ),
        )
        assertTrue(
            PlannerCalendar.sameOccurrence(
                firstDateKey = "2026-11-24",
                firstWeekday = 1,
                secondDateKey = "2026-11-24",
                secondWeekday = 1,
            ),
        )
        assertFalse(
            PlannerCalendar.sameOccurrence(
                firstDateKey = "2026-11-24",
                firstWeekday = 2,
                secondDateKey = "2026-11-25",
                secondWeekday = 3,
            ),
        )
    }

    @Test
    fun malformedNonNullDateIsNotSilentlyTreatedAsLegacyOccurrence() {
        assertFalse(
            PlannerCalendar.sameOccurrence(
                firstDateKey = "2026-02-30",
                firstWeekday = 1,
                secondDateKey = null,
                secondWeekday = 1,
            ),
        )
        assertFalse(
            PlannerCalendar.sameOccurrence(
                firstDateKey = null,
                firstWeekday = 1,
                secondDateKey = "not-a-date",
                secondWeekday = 1,
            ),
        )
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
    fun overlapMatchesDatedSessionWithLegacyWeekdayUsingCalendarDate() {
        val datedTuesdayWithStaleWeekday = StudySession(
            "dated", "جلسه تاریخ‌دار", "ریاضی", 1, 600, 60,
            scheduledDate = "2026-11-24",
        )
        val legacyTuesday = StudySession(
            "legacy", "جلسه قدیمی", "علوم", 2, 630, 45,
        )

        assertTrue(PlannerOperations.hasOverlap(listOf(datedTuesdayWithStaleWeekday), legacyTuesday))
        assertTrue(PlannerOperations.hasOverlap(listOf(legacyTuesday), datedTuesdayWithStaleWeekday))
    }

    @Test
    fun malformedDatedSessionDoesNotCreateFalseLegacyOverlap() {
        val malformedDated = StudySession(
            "bad-date", "جلسه معیوب", "ریاضی", 1, 600, 60,
            scheduledDate = "2026-02-30",
        )
        val legacyMonday = StudySession(
            "legacy", "جلسه قدیمی", "علوم", 1, 630, 45,
        )
        assertFalse(PlannerOperations.hasOverlap(listOf(malformedDated), legacyMonday))
    }

    @Test
    fun invalidPersistedTimeRangeCannotOverflowOrBlockValidSession() {
        val invalidPersisted = StudySession(
            "corrupt", "جلسه خراب", "ریاضی", 1, 600, Int.MAX_VALUE,
        )
        val validCandidate = StudySession(
            "candidate", "جلسه جدید", "علوم", 1, 610, 30,
        )
        assertFalse(PlannerOperations.hasOverlap(listOf(invalidPersisted), validCandidate))
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

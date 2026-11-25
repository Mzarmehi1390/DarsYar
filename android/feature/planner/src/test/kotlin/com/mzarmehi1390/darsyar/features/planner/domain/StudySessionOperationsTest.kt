package com.mzarmehi1390.darsyar.features.planner.domain

import com.mzarmehi1390.darsyar.features.planner.domain.models.StudySession
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class StudySessionOperationsTest {
    private fun session(id: String = "s1") = StudySession(
        id = id,
        title = "مطالعه",
        subject = "ریاضی",
        weekday = 1,
        startMinutes = 23 * 60,
        durationMinutes = 60,
        scheduledDate = "2026-11-23",
    )

    @Test
    fun toggleCompletionChangesOnlyMatchingSession() {
        val original = session()
        val other = session("s2")
        val changed = StudySessionOperations.toggleCompletion(listOf(original, other), "s1")

        assertTrue(changed[0].completed)
        assertFalse(changed[1].completed)
        assertFalse(original.completed)
    }

    @Test
    fun upsertReplacesExistingItemInPlaceOrAppendsNewItem() {
        val original = session()
        val replacement = original.copy(title = "نسخه جدید")
        val edited = StudySessionOperations.upsert(listOf(original), replacement)
        assertEquals(listOf(replacement), edited)

        val appended = StudySessionOperations.upsert(edited, session("s2"))
        assertEquals(listOf(replacement, session("s2")), appended)
    }

    @Test
    fun removeByIdLeavesOtherSessionsUntouched() {
        val first = session()
        val second = session("s2")
        assertEquals(listOf(second), StudySessionOperations.removeById(listOf(first, second), first.id))
    }

    @Test
    fun validatesEndOfDayBoundaryWithoutOverflow() {
        assertEquals(SessionValidation.Valid, StudySessionOperations.validate(session()))
        assertEquals(
            SessionValidation.CrossesMidnight,
            StudySessionOperations.validate(session().copy(durationMinutes = 61)),
        )
        assertEquals(
            SessionValidation.InvalidDuration,
            StudySessionOperations.validate(session().copy(durationMinutes = 0)),
        )
        assertEquals(
            SessionValidation.CrossesMidnight,
            StudySessionOperations.validate(session().copy(durationMinutes = Int.MAX_VALUE)),
        )
    }

    @Test
    fun validatesDateAndWeekday() {
        assertEquals(
            SessionValidation.InvalidDate,
            StudySessionOperations.validate(session().copy(scheduledDate = "23/11/2026")),
        )
        assertEquals(
            SessionValidation.InvalidWeekday,
            StudySessionOperations.validate(session().copy(weekday = 7)),
        )
        assertEquals(
            SessionValidation.WeekdayDoesNotMatchDate,
            StudySessionOperations.validate(session().copy(weekday = 2)),
        )
    }
}

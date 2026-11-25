package com.mzarmehi1390.darsyar.features.planner.domain

import com.mzarmehi1390.darsyar.features.planner.domain.models.StudySession
import com.mzarmehi1390.darsyar.features.planner.domain.models.StudyTask
import java.time.LocalDate
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class PlannerDayCopyOperationsTest {
    @Test
    fun copyDay_createsDatedIncompleteCopiesAndPreservesSourceRecords() {
        val targetDate = LocalDate.parse("2026-11-26")
        val datedSource = StudySession(
            id = "dated-source",
            title = "مرور فصل",
            subject = "علوم",
            weekday = 0, // The concrete date is authoritative for dated records.
            startMinutes = 10 * 60,
            durationMinutes = 45,
            completed = true,
            scheduledDate = "2026-11-24",
        )
        val legacySource = StudySession(
            id = "legacy-source",
            title = "حل تمرین",
            subject = "ریاضی",
            weekday = PlannerCalendar.weekdayForDate(LocalDate.parse("2026-11-24")),
            startMinutes = 9 * 60,
            durationMinutes = 30,
            completed = false,
        )
        val unrelated = legacySource.copy(id = "other-day", weekday = 6)
        val sources = listOf(datedSource, legacySource, unrelated)
        val generatedIds = mutableListOf<String>()

        val copied = PlannerOperations.copyDay(
            sessions = sources,
            sourceWeekday = PlannerCalendar.weekdayForDate(LocalDate.parse("2026-11-24")),
            targetDate = targetDate,
            createId = { source -> "copy-${source.id}".also(generatedIds::add) },
        )

        assertEquals(listOf("copy-legacy-source", "copy-dated-source"), copied.map { it.id })
        assertEquals(listOf("legacy-source", "dated-source"), generatedIds)
        assertEquals(listOf(9 * 60, 10 * 60), copied.map { it.startMinutes })
        assertTrue(copied.all { it.scheduledDate == PlannerCalendar.dateKey(targetDate) })
        assertTrue(copied.all { it.weekday == PlannerCalendar.weekdayForDate(targetDate) })
        assertTrue(copied.all { !it.completed })
        assertEquals(listOf(datedSource, legacySource, unrelated), sources)
        assertTrue(datedSource.completed)
    }

    @Test
    fun copyTaskToDate_generatesNewIdentityAndResetsCompletion() {
        val source = StudyTask(
            id = "task-source",
            title = "تمرین فصل دوم",
            subject = "ریاضی",
            done = true,
            dueDate = "2026-11-24",
        )
        val targetDate = LocalDate.parse("2026-11-26")

        val copied = PlannerOperations.copyTaskToDate(
            task = source,
            targetDate = targetDate,
            newId = "task-copy",
        )

        assertEquals("task-copy", copied.id)
        assertEquals(source.title, copied.title)
        assertEquals(source.subject, copied.subject)
        assertFalse(copied.done)
        assertEquals(PlannerCalendar.dateKey(targetDate), copied.dueDate)
        assertTrue(source.done)
        assertEquals("2026-11-24", source.dueDate)
    }
}

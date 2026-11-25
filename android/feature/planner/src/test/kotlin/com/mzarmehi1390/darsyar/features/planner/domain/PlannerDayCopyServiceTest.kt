package com.mzarmehi1390.darsyar.features.planner.domain

import com.mzarmehi1390.darsyar.features.planner.domain.models.StudySession
import java.time.LocalDate
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class PlannerDayCopyServiceTest {
    private val service = PlannerDayCopyService()
    private val sourceDate = LocalDate.parse("2026-11-24")
    private val targetDate = LocalDate.parse("2026-11-26")

    @Test
    fun createPlan_includesExactDateAndLegacyWeekdayButExcludesOtherOccurrences() {
        val dated = session("dated", scheduledDate = "2026-11-24", weekday = 0)
        val legacy = session("legacy", scheduledDate = null, weekday = 2).copy(startMinutes = 8 * 60)
        val otherDate = session("other-date", scheduledDate = "2026-11-25", weekday = 2)
        val malformed = session("malformed", scheduledDate = "not-a-date", weekday = 2)
        val otherWeekday = session("other-weekday", scheduledDate = null, weekday = 3)
        val input = listOf(dated, legacy, otherDate, malformed, otherWeekday)

        val plan = service.createPlan(input, sourceDate, targetDate) { "copy-${it.id}" }

        assertEquals(listOf("legacy", "dated"), plan.sourceSessions.map { it.id })
        assertEquals(listOf("copy-legacy", "copy-dated"), plan.copiedSessions.map { it.id })
        assertTrue(plan.copiedSessions.all { it.scheduledDate == "2026-11-26" })
        assertTrue(plan.copiedSessions.all { it.weekday == 4 })
        assertTrue(plan.copiedSessions.all { !it.completed })
        assertEquals(input, input.toList())
        assertTrue(dated.completed)
    }

    @Test
    fun createPlan_rejectsSameSourceAndTargetDate() {
        val error = runCatching {
            service.createPlan(emptyList(), sourceDate, sourceDate) { "unused" }
        }.exceptionOrNull()

        assertTrue(error is IllegalArgumentException)
    }

    @Test
    fun createPlan_usesNewIdentityAndKeepsSessionContent() {
        val source = session("source", scheduledDate = "2026-11-24", weekday = 2, completed = true)

        val copy = service.createPlan(listOf(source), sourceDate, targetDate) { "fresh-id" }
            .copiedSessions.single()

        assertEquals("fresh-id", copy.id)
        assertEquals(source.title, copy.title)
        assertEquals(source.subject, copy.subject)
        assertEquals(source.startMinutes, copy.startMinutes)
        assertEquals(source.durationMinutes, copy.durationMinutes)
        assertFalse(copy.completed)
        assertTrue(source.completed)
    }

    private fun session(
        id: String,
        scheduledDate: String?,
        weekday: Int,
        completed: Boolean = false,
    ) = StudySession(
        id = id,
        title = "مطالعه $id",
        subject = "ریاضی",
        weekday = weekday,
        startMinutes = 9 * 60,
        durationMinutes = 45,
        completed = completed,
        scheduledDate = scheduledDate,
    )
}

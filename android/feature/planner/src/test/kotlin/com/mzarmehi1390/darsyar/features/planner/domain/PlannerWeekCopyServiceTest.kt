package com.mzarmehi1390.darsyar.features.planner.domain

import com.mzarmehi1390.darsyar.features.planner.domain.models.StudySession
import com.mzarmehi1390.darsyar.features.planner.domain.models.StudyTask
import java.time.LocalDate
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Test

class PlannerWeekCopyServiceTest {
    @Test
    fun createNextWeekPlan_shiftsDatesAndResetsCompletionWithoutMutatingSources() {
        val session = StudySession("s", "مرور", "علوم", 2, 540, 60, true, "2026-11-24")
        val task = StudyTask("t", "تمرین", "ریاضی", true, "2026-11-25")
        val plan = PlannerWeekCopyService().createNextWeekPlan(
            listOf(session), listOf(task), LocalDate.parse("2026-11-21"),
            { "new-${it.id}" }, { "new-${it.id}" },
        )
        assertEquals(LocalDate.parse("2026-11-28"), plan.targetWeekStart)
        assertEquals("2026-12-01", plan.copiedSessions.single().scheduledDate)
        assertEquals("2026-12-02", plan.copiedTasks.single().dueDate)
        assertFalse(plan.copiedSessions.single().completed)
        assertFalse(plan.copiedTasks.single().done)
        assertEquals(session, plan.sourceSessions.single())
        assertEquals(task, plan.sourceTasks.single())
    }

    @Test
    fun createNextWeekPlan_copiesLegacyRecurringSessionsButIgnoresUndatedTasks() {
        val plan = PlannerWeekCopyService().createNextWeekPlan(
            listOf(StudySession("s", "هفتگی", "علوم", 2, 540, 30)),
            listOf(StudyTask("t", "بدون سررسید", "عمومی")),
            LocalDate.parse("2026-11-21"),
            { "new-${it.id}" }, { "new-${it.id}" },
        )
        val copiedSession = plan.copiedSessions.single()
        assertEquals("new-s", copiedSession.id)
        assertEquals("2026-12-01", copiedSession.scheduledDate)
        assertEquals(2, copiedSession.weekday)
        assertFalse(copiedSession.completed)
        assertEquals(emptyList<StudyTask>(), plan.copiedTasks)
    }
    @Test
    fun createNextWeekPlan_resolvesLegacyWeekdaySessionsIntoConcreteTargetDates() {
        val legacyTuesday = StudySession("legacy-tue", "مطالعه هفتگی", "علوم", 2, 540, 45, true)
        val legacySaturday = StudySession("legacy-sat", "مرور هفتگی", "ریاضی", 6, 600, 30)
        val malformed = StudySession("malformed", "داده خراب", "عمومی", 2, 700, 20, false, "not-a-date")
        val outsideWeek = StudySession("outside", "هفته دیگر", "علوم", 2, 800, 20, false, "2026-11-30")

        val plan = PlannerWeekCopyService().createNextWeekPlan(
            sessions = listOf(legacyTuesday, malformed, outsideWeek, legacySaturday),
            tasks = emptyList(),
            sourceWeekStart = LocalDate.parse("2026-11-21"),
            createSessionId = { "copy-${it.id}" },
            createTaskId = { "copy-${it.id}" },
        )

        assertEquals(listOf("legacy-tue", "legacy-sat"), plan.sourceSessions.map { it.id })
        assertEquals(listOf("2026-12-01", "2026-11-28"), plan.copiedSessions.map { it.scheduledDate })
        assertEquals(listOf(2, 6), plan.copiedSessions.map { it.weekday })
        assertEquals(listOf(false, false), plan.copiedSessions.map { it.completed })
        assertEquals(listOf("copy-legacy-tue", "copy-legacy-sat"), plan.copiedSessions.map { it.id })
    }

    @Test
    fun createNextWeekPlan_doesNotTreatMalformedDatedSessionAsLegacy() {
        val malformed = StudySession("malformed", "داده خراب", "علوم", 2, 540, 45, false, "24/11/2026")

        val plan = PlannerWeekCopyService().createNextWeekPlan(
            sessions = listOf(malformed),
            tasks = emptyList(),
            sourceWeekStart = LocalDate.parse("2026-11-21"),
            createSessionId = { "copy-${it.id}" },
            createTaskId = { "copy-${it.id}" },
        )

        assertEquals(emptyList<StudySession>(), plan.sourceSessions)
        assertEquals(emptyList<StudySession>(), plan.copiedSessions)
    }

}

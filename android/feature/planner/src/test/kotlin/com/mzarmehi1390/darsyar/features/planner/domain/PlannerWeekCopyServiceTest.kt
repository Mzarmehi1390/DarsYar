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
    fun createNextWeekPlan_ignoresUndatedRecurringItems() {
        val plan = PlannerWeekCopyService().createNextWeekPlan(
            listOf(StudySession("s", "هفتگی", "علوم", 2, 540, 30)),
            listOf(StudyTask("t", "بدون سررسید", "عمومی")),
            LocalDate.parse("2026-11-21"),
            { "new-${it.id}" }, { "new-${it.id}" },
        )
        assertEquals(emptyList<StudySession>(), plan.copiedSessions)
        assertEquals(emptyList<StudyTask>(), plan.copiedTasks)
    }
}

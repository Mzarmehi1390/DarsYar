package com.mzarmehi1390.darsyar.features.dashboard.domain

import com.mzarmehi1390.darsyar.features.planner.domain.models.StudyTask
import org.junit.Assert.assertEquals
import org.junit.Assert.assertSame
import org.junit.Assert.assertThrows
import org.junit.Test

class DashboardTaskSummaryTest {
    @Test
    fun emptyTasksProduceZeroProgressAndNoPendingPreview() {
        val summary = DashboardTaskSummary.from(emptyList())
        assertEquals(0, summary.totalCount)
        assertEquals(0, summary.completedCount)
        assertEquals(0, summary.remainingCount)
        assertEquals(0f, summary.progress)
        assertEquals(emptyList<StudyTask>(), summary.pendingTasks)
    }

    @Test
    fun aggregatesCountsAndKeepsOnlyFirstThreeIncompleteTasksInSourceOrder() {
        val tasks = listOf(
            task("done-1", done = true),
            task("pending-1"),
            task("pending-2"),
            task("done-2", done = true),
            task("pending-3"),
            task("pending-4"),
        )

        val summary = DashboardTaskSummary.from(tasks)

        assertEquals(6, summary.totalCount)
        assertEquals(2, summary.completedCount)
        assertEquals(4, summary.remainingCount)
        assertEquals(2f / 6f, summary.progress)
        assertEquals(listOf("pending-1", "pending-2", "pending-3"), summary.pendingTasks.map { it.id })
        assertSame(tasks[1], summary.pendingTasks[0])
    }

    @Test
    fun zeroPendingLimitStillComputesCounts() {
        val summary = DashboardTaskSummary.from(listOf(task("done", true), task("pending")), pendingLimit = 0)
        assertEquals(2, summary.totalCount)
        assertEquals(1, summary.completedCount)
        assertEquals(emptyList<StudyTask>(), summary.pendingTasks)
    }

    @Test
    fun negativePendingLimitIsRejected() {
        assertThrows(IllegalArgumentException::class.java) {
            DashboardTaskSummary.from(emptyList(), pendingLimit = -1)
        }
    }

    private fun task(id: String, done: Boolean = false) = StudyTask(
        id = id,
        title = id,
        subject = "عمومی",
        done = done,
        dueDate = null,
    )
}

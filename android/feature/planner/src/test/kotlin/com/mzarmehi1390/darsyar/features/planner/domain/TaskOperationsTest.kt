package com.mzarmehi1390.darsyar.features.planner.domain

import com.mzarmehi1390.darsyar.features.planner.domain.models.StudyTask
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import java.time.LocalDate
import org.junit.Test

class TaskOperationsTest {
    @Test
    fun creatingTaskNormalizesEmptySubjectAndStartsIncomplete() {
        val created = TaskOperations.upsert(
            tasks = emptyList(),
            title = "تمرین",
            subject = "",
            dueDate = "2026-11-24",
            existingId = null,
            createId = { "new-task" },
        ).single()

        assertEquals("عمومی", created.subject)
        assertFalse(created.done)
        assertEquals("2026-11-24", created.dueDate)
    }

    @Test
    fun editingTaskPreservesCompletionState() {
        val existing = StudyTask("t1", "Old", "Math", done = true, dueDate = "2026-11-23")
        val updated = TaskOperations.upsert(
            tasks = listOf(existing),
            title = "New",
            subject = "Science",
            dueDate = null,
            existingId = "t1",
            createId = { error("ID generator must not be called for an edit") },
        ).single()

        assertEquals("New", updated.title)
        assertEquals("Science", updated.subject)
        assertTrue(updated.done)
        assertEquals(null, updated.dueDate)
    }

    @Test
    fun filterSearchesTitleAndSubjectCaseInsensitively() {
        val tasks = listOf(
            StudyTask("1", "تمرین فصل اول", "ریاضی"),
            StudyTask("2", "مرور واژگان", "زبان"),
            StudyTask("3", "آزمون", "ریاضی"),
        )

        assertEquals(
            listOf("1", "3"),
            TaskOperations.filter(
                tasks = tasks,
                query = "ریاضی",
                today = LocalDate.parse("2026-11-26"),
            ).map(StudyTask::id),
        )
        assertEquals(
            listOf("2"),
            TaskOperations.filter(
                tasks = tasks,
                query = "  واژگان  ",
                today = LocalDate.parse("2026-11-26"),
            ).map(StudyTask::id),
        )
    }

    @Test
    fun overdueFilterExcludesCompletedUndatedAndMalformedTasks() {
        val tasks = listOf(
            StudyTask("overdue", "قدیمی", "علوم", dueDate = "2026-11-25"),
            StudyTask("today", "امروز", "علوم", dueDate = "2026-11-26"),
            StudyTask("future", "آینده", "علوم", dueDate = "2026-11-27"),
            StudyTask("done", "تمام‌شده", "علوم", done = true, dueDate = "2026-11-20"),
            StudyTask("undated", "بدون تاریخ", "علوم"),
            StudyTask("invalid", "تاریخ خراب", "علوم", dueDate = "2026-02-31"),
        )

        assertEquals(
            listOf("overdue"),
            TaskOperations.filter(
                tasks = tasks,
                status = TaskStatusFilter.OVERDUE,
                today = LocalDate.parse("2026-11-26"),
            ).map(StudyTask::id),
        )
    }

    @Test
    fun statusFiltersPreserveOriginalOrderAndDoNotMutateInput() {
        val tasks = listOf(
            StudyTask("done-1", "A", "Math", done = true),
            StudyTask("active-1", "B", "Math"),
            StudyTask("done-2", "C", "Math", done = true),
        )

        assertEquals(
            listOf("active-1"),
            TaskOperations.filter(tasks, status = TaskStatusFilter.ACTIVE, today = LocalDate.now()).map(StudyTask::id),
        )
        assertEquals(listOf("done-1", "done-2"), TaskOperations.filter(
            tasks, status = TaskStatusFilter.COMPLETED, today = LocalDate.now(),
        ).map(StudyTask::id))
        assertEquals(3, tasks.size)
    }

    @Test
    fun overdueFilterExcludesTasksDueTodayAndCompletedTasks() {
        val tasks = listOf(
            StudyTask("yesterday", "دیروز", "علوم", dueDate = "2026-11-25"),
            StudyTask("today", "امروز", "علوم", dueDate = "2026-11-26"),
            StudyTask("completed", "تکمیل‌شده", "علوم", done = true, dueDate = "2026-11-20"),
        )

        assertEquals(
            listOf("yesterday"),
            TaskOperations.filter(
                tasks = tasks,
                status = TaskStatusFilter.OVERDUE,
                today = LocalDate.parse("2026-11-26"),
            ).map(StudyTask::id),
        )
    }

    @Test
    fun blankSearchReturnsAllTasksAndWhitespaceOnlySearchIsIgnored() {
        val tasks = listOf(
            StudyTask("one", "ریاضی", "عمومی"),
            StudyTask("two", "علوم", "طبیعی"),
        )

        assertEquals(
            listOf("one", "two"),
            TaskOperations.filter(tasks, query = "   ", today = LocalDate.parse("2026-11-26"))
                .map(StudyTask::id),
        )
    }

    @Test
    fun unknownEditDoesNotInsertOrChangeAnything() {
        val existing = StudyTask("t1", "Old", "Math")
        val result = TaskOperations.upsert(
            tasks = listOf(existing),
            title = "New",
            subject = "Science",
            dueDate = null,
            existingId = "missing",
            createId = { "unused" },
        )

        assertEquals(listOf(existing), result)
    }
}

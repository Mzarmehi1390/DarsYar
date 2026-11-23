package com.mzarmehi1390.darsyar.features.planner.domain

import com.mzarmehi1390.darsyar.features.planner.domain.models.StudyTask
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
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

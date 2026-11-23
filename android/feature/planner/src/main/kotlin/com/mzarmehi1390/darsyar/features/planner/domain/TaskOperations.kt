package com.mzarmehi1390.darsyar.features.planner.domain

import com.mzarmehi1390.darsyar.features.planner.domain.models.StudyTask

object TaskOperations {
    fun completedCount(tasks: Iterable<StudyTask>): Int = tasks.count(StudyTask::done)

    fun toggleCompletion(task: StudyTask): StudyTask = task.copy(done = !task.done)

    fun removeById(tasks: Iterable<StudyTask>, id: String): List<StudyTask> =
        tasks.filterNot { it.id == id }

    /** Editing preserves completion state; new tasks always start incomplete. */
    fun upsert(
        tasks: Iterable<StudyTask>,
        title: String,
        subject: String,
        dueDate: String?,
        existingId: String?,
        createId: () -> String,
    ): List<StudyTask> {
        val normalizedSubject = subject.ifEmpty { "عمومی" }
        val current = tasks.toList()
        if (existingId == null) {
            return current + StudyTask(
                id = createId(),
                title = title,
                subject = normalizedSubject,
                done = false,
                dueDate = dueDate,
            )
        }
        val index = current.indexOfFirst { it.id == existingId }
        if (index < 0) return current
        return current.toMutableList().also { updated ->
            updated[index] = updated[index].copy(
                title = title,
                subject = normalizedSubject,
                dueDate = dueDate,
            )
        }
    }
}

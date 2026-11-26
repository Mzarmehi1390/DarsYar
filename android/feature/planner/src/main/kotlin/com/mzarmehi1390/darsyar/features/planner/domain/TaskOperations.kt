package com.mzarmehi1390.darsyar.features.planner.domain

import com.mzarmehi1390.darsyar.features.planner.domain.models.StudyTask

enum class TaskStatusFilter { ALL, ACTIVE, COMPLETED, OVERDUE }

object TaskOperations {
    /**
     * Filters without mutating the source collection and preserves its display order.
     * A task is overdue only when it is incomplete and has a valid date before [today].
     * Malformed legacy dates remain visible in non-overdue filters instead of vanishing.
     */
    fun filter(
        tasks: Iterable<StudyTask>,
        query: String = "",
        status: TaskStatusFilter = TaskStatusFilter.ALL,
        today: java.time.LocalDate,
    ): List<StudyTask> {
        val normalizedQuery = query.trim()
        return tasks.filter { task ->
            val matchesQuery = normalizedQuery.isEmpty() ||
                task.title.contains(normalizedQuery, ignoreCase = true) ||
                task.subject.contains(normalizedQuery, ignoreCase = true)
            val dueDate = PlannerCalendar.parseDateKey(task.dueDate)
            val matchesStatus = when (status) {
                TaskStatusFilter.ALL -> true
                TaskStatusFilter.ACTIVE -> !task.done
                TaskStatusFilter.COMPLETED -> task.done
                TaskStatusFilter.OVERDUE -> !task.done && dueDate?.isBefore(today) == true
            }
            matchesQuery && matchesStatus
        }
    }
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

package com.mzarmehi1390.darsyar.features.dashboard.domain

import com.mzarmehi1390.darsyar.features.planner.domain.models.StudyTask

/** Immutable aggregates for the dashboard, computed in one bounded pass. */
data class DashboardTaskSummary private constructor(
    val totalCount: Int,
    val completedCount: Int,
    val pendingTasks: List<StudyTask>,
) {
    val remainingCount: Int get() = totalCount - completedCount
    val progress: Float get() = if (totalCount == 0) 0f else completedCount.toFloat() / totalCount

    companion object {
        fun from(tasks: Iterable<StudyTask>, pendingLimit: Int = DEFAULT_PENDING_LIMIT): DashboardTaskSummary {
            require(pendingLimit >= 0) { "pendingLimit must not be negative." }
            var total = 0
            var completed = 0
            val pending = ArrayList<StudyTask>(pendingLimit)
            for (task in tasks) {
                total++
                if (task.done) {
                    completed++
                } else if (pending.size < pendingLimit) {
                    pending += task
                }
            }
            return DashboardTaskSummary(total, completed, pending.toList())
        }

        const val DEFAULT_PENDING_LIMIT = 3
    }
}

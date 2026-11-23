package com.mzarmehi1390.darsyar.features.planner.domain

import com.mzarmehi1390.darsyar.features.planner.domain.models.StudySession
import com.mzarmehi1390.darsyar.features.planner.domain.models.StudyTask
import java.time.LocalDate

class PlannerWeekCopyService {
    fun createNextWeekPlan(
        sessions: Iterable<StudySession>,
        tasks: Iterable<StudyTask>,
        sourceWeekStart: LocalDate,
        createSessionId: (StudySession) -> String,
        createTaskId: (StudyTask) -> String,
    ): PlannerWeekCopyPlan {
        val sourceStart = PlannerCalendar.startOfWeek(sourceWeekStart)
        val targetStart = sourceStart.plusDays(7)
        val sourceSessions = sessions.filter { item ->
            val date = PlannerCalendar.parseDateKey(item.scheduledDate)
            date != null && PlannerCalendar.isInWeek(date, sourceStart)
        }
        val sourceTasks = tasks.filter { item ->
            val date = PlannerCalendar.parseDateKey(item.dueDate)
            date != null && PlannerCalendar.isInWeek(date, sourceStart)
        }

        val copiedSessions = sourceSessions.map { source ->
            val sourceDate = requireNotNull(PlannerCalendar.parseDateKey(source.scheduledDate))
            source.copy(
                id = createSessionId(source),
                completed = false,
                scheduledDate = PlannerCalendar.dateKey(sourceDate.plusDays(7)),
            )
        }
        val copiedTasks = sourceTasks.map { source ->
            val sourceDate = requireNotNull(PlannerCalendar.parseDateKey(source.dueDate))
            source.copy(
                id = createTaskId(source),
                done = false,
                dueDate = PlannerCalendar.dateKey(sourceDate.plusDays(7)),
            )
        }

        return PlannerWeekCopyPlan(
            sourceWeekStart = sourceStart,
            targetWeekStart = targetStart,
            sourceSessions = sourceSessions,
            sourceTasks = sourceTasks,
            copiedSessions = copiedSessions,
            copiedTasks = copiedTasks,
        )
    }
}

data class PlannerWeekCopyPlan(
    val sourceWeekStart: LocalDate,
    val targetWeekStart: LocalDate,
    val sourceSessions: List<StudySession>,
    val sourceTasks: List<StudyTask>,
    val copiedSessions: List<StudySession>,
    val copiedTasks: List<StudyTask>,
)

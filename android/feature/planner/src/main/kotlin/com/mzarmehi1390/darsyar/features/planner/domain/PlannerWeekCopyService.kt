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
        // Resolve legacy weekday-only sessions against this concrete source week.
        // A non-null malformed date is deliberately excluded instead of falling back
        // to the redundant weekday field.
        val sourceOccurrences = sessions.mapNotNull { session ->
            val occurrenceDate = when {
                session.scheduledDate != null -> {
                    PlannerCalendar.parseDateKey(session.scheduledDate)
                        ?.takeIf { PlannerCalendar.isInWeek(it, sourceStart) }
                }
                session.weekday in 0..6 -> PlannerCalendar.dateForWeekday(sourceStart, session.weekday)
                else -> null
            }
            occurrenceDate?.let { session to it }
        }
        val sourceSessions = sourceOccurrences.map { (session, _) -> session }
        val sourceTasks = tasks.filter { item ->
            val date = PlannerCalendar.parseDateKey(item.dueDate)
            date != null && PlannerCalendar.isInWeek(date, sourceStart)
        }

        val copiedSessions = sourceOccurrences.map { (source, sourceDate) ->
            source.copy(
                id = createSessionId(source),
                weekday = PlannerCalendar.weekdayForDate(sourceDate.plusDays(7)),
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

sealed interface PlannerWeekCopyResult {
    data class Copied(val sessionCount: Int, val taskCount: Int) : PlannerWeekCopyResult
    data object TargetWeekNotEmpty : PlannerWeekCopyResult
    data object SessionConflict : PlannerWeekCopyResult
    data object IdCollision : PlannerWeekCopyResult
    data object SourceChanged : PlannerWeekCopyResult
    data object InvalidPlan : PlannerWeekCopyResult
}

data class PlannerWeekCopyPlan(
    val sourceWeekStart: LocalDate,
    val targetWeekStart: LocalDate,
    val sourceSessions: List<StudySession>,
    val sourceTasks: List<StudyTask>,
    val copiedSessions: List<StudySession>,
    val copiedTasks: List<StudyTask>,
)

package com.mzarmehi1390.darsyar.features.planner.domain

import com.mzarmehi1390.darsyar.features.planner.domain.models.StudySession

/** Pure scheduling mutations; callers persist the returned immutable collection. */
object StudySessionOperations {
    fun toggleCompletion(sessions: Iterable<StudySession>, id: String): List<StudySession> =
        sessions.map { session ->
            if (session.id == id) session.copy(completed = !session.completed) else session
        }

    fun upsert(
        sessions: Iterable<StudySession>,
        candidate: StudySession,
    ): List<StudySession> {
        val current = sessions.toList()
        val index = current.indexOfFirst { it.id == candidate.id }
        if (index < 0) return current + candidate
        return current.toMutableList().also { it[index] = candidate }
    }

    fun removeById(sessions: Iterable<StudySession>, id: String): List<StudySession> =
        sessions.filterNot { it.id == id }

    fun validate(candidate: StudySession): SessionValidation {
        if (candidate.id.isBlank()) return SessionValidation.InvalidId
        if (candidate.title.isBlank()) return SessionValidation.EmptyTitle
        if (candidate.subject.isBlank()) return SessionValidation.EmptySubject
        if (candidate.weekday !in 0..6) return SessionValidation.InvalidWeekday
        if (candidate.startMinutes !in 0 until 24 * 60) return SessionValidation.InvalidStartTime
        if (candidate.durationMinutes <= 0) return SessionValidation.InvalidDuration
        // Subtraction avoids Int overflow for untrusted or corrupted duration values.
        if (candidate.durationMinutes > 24 * 60 - candidate.startMinutes) {
            return SessionValidation.CrossesMidnight
        }
        val date = candidate.scheduledDate
        if (date != null && PlannerCalendar.parseDateKey(date) == null) {
            return SessionValidation.InvalidDate
        }
        return SessionValidation.Valid
    }
}

sealed interface SessionValidation {
    data object Valid : SessionValidation
    data object InvalidId : SessionValidation
    data object EmptyTitle : SessionValidation
    data object EmptySubject : SessionValidation
    data object InvalidWeekday : SessionValidation
    data object InvalidStartTime : SessionValidation
    data object InvalidDuration : SessionValidation
    data object CrossesMidnight : SessionValidation
    data object InvalidDate : SessionValidation
}

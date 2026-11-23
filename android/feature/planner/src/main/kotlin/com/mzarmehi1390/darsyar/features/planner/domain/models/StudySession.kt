package com.mzarmehi1390.darsyar.features.planner.domain.models

/** One planned study occurrence; dates are local calendar dates, not instants. */
data class StudySession(
    val id: String,
    val title: String,
    val subject: String,
    /** Sunday = 0 ... Saturday = 6, retained for legacy records. */
    val weekday: Int,
    val startMinutes: Int,
    val durationMinutes: Int,
    val completed: Boolean = false,
    /** ISO local calendar date (yyyy-MM-dd); null for legacy weekday-only records. */
    val scheduledDate: String? = null,
)

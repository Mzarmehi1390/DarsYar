package com.mzarmehi1390.darsyar.features.exams.domain

/** Validates and converts the hour/minute/second duration used by exam setup. */
object ExamDurationOperations {
    const val MAX_DURATION_SECONDS = 24 * 60 * 60

    fun toSeconds(hours: Int, minutes: Int, seconds: Int): Int? {
        if (hours !in 0..24 || minutes !in 0..59 || seconds !in 0..59) return null
        if (hours == 24 && (minutes != 0 || seconds != 0)) return null
        val total = hours * 3_600 + minutes * 60 + seconds
        return total.takeIf { it in 1..MAX_DURATION_SECONDS }
    }
}

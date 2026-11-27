@file:SuppressLint("NewApi")

package com.mzarmehi1390.darsyar.core.common

import android.annotation.SuppressLint

import java.time.LocalDate

/**
 * Jalali (Persian / Shamsi) calendar date used only at the presentation boundary.
 *
 * Storage, Room entities, backup payloads and domain models remain Gregorian ISO
 * date keys. Convert at the UI layer so Persian users see familiar year/month/day
 * numbers without changing persistence contracts.
 *
 * Algorithm follows the well-tested Borkowski / civil Persian calendar conversion
 * used across Iranian open-source libraries for the practical range 1900–2100.
 */
data class JalaliDate(
    val year: Int,
    val month: Int,
    val day: Int,
) {
    init {
        require(month in 1..12) { "Jalali month must be 1..12, was $month" }
        require(day in 1..31) { "Jalali day must be 1..31, was $day" }
    }

    /** Formatted as YYYY/MM/DD with Western digits (caller applies PersianDigits). */
    fun toDisplayString(): String =
        "%04d/%02d/%02d".format(year, month, day)

    companion object {
        private val GREGORIAN_DAY_COUNTS =
            intArrayOf(0, 31, 59, 90, 120, 151, 181, 212, 243, 273, 304, 334)

        /**
         * Convert a Gregorian [LocalDate] to Jalali.
         * Accurate for civil use in the range roughly 1900–2100.
         */
        fun fromGregorian(date: LocalDate): JalaliDate =
            fromGregorian(date.year, date.monthValue, date.dayOfMonth)

        fun fromGregorian(gy: Int, gm: Int, gd: Int): JalaliDate {
            require(gm in 1..12) { "Gregorian month must be 1..12" }
            require(gd in 1..31) { "Gregorian day must be 1..31" }

            val gy2 = if (gm > 2) gy + 1 else gy
            var days = 355666 +
                365 * gy +
                (gy2 + 3) / 4 -
                (gy2 + 99) / 100 +
                (gy2 + 399) / 400 +
                gd +
                GREGORIAN_DAY_COUNTS[gm - 1]

            var jy = -1595 + 33 * (days / 12053)
            days %= 12053
            jy += 4 * (days / 1461)
            days %= 1461
            if (days > 365) {
                jy += (days - 1) / 365
                days = (days - 1) % 365
            }

            val jm: Int
            val jd: Int
            if (days < 186) {
                jm = 1 + days / 31
                jd = 1 + days % 31
            } else {
                jm = 7 + (days - 186) / 30
                jd = 1 + (days - 186) % 30
            }
            return JalaliDate(jy, jm, jd)
        }

        /**
         * Best-effort parse of an ISO date key (yyyy-MM-dd) into Jalali display form.
         * Returns the original string when parsing fails so UI never crashes.
         */
        fun formatIsoDateKey(value: String): String =
            runCatching {
                val date = LocalDate.parse(value)
                fromGregorian(date).toDisplayString()
            }.getOrDefault(value)
    }
}

package com.mzarmehi1390.darsyar.core.common

import org.junit.Assert.assertEquals
import org.junit.Assert.assertThrows
import org.junit.Test
import java.time.LocalDate

class JalaliDateTest {
    @Test
    fun convertsKnownGregorianAnchorsToExpectedJalali() {
        assertEquals(JalaliDate(1405, 1, 1), JalaliDate.fromGregorian(2026, 3, 21))
        assertEquals(JalaliDate(1405, 8, 5), JalaliDate.fromGregorian(2026, 10, 27))
        assertEquals(JalaliDate(1404, 12, 29), JalaliDate.fromGregorian(2026, 3, 20))
    }

    @Test
    fun convertsViaLocalDate() {
        val jalali = JalaliDate.fromGregorian(LocalDate.of(2026, 11, 27))
        assertEquals(JalaliDate(1405, 9, 6), jalali)
    }

    @Test
    fun convertsJalaliDatesBackToGregorian() {
        assertEquals(LocalDate.of(2026, 3, 21), JalaliDate.toGregorian(JalaliDate(1405, 1, 1)))
        assertEquals(LocalDate.of(2026, 10, 27), JalaliDate.toGregorian(JalaliDate(1405, 8, 5)))
        assertEquals(LocalDate.of(2026, 3, 20), JalaliDate.toGregorian(JalaliDate(1404, 12, 29)))
    }

    @Test
    fun supportsEsfandTwentyNinthAndThirtiethOnlyInLeapYear() {
        assertEquals(LocalDate.of(2025, 3, 20), JalaliDate.toGregorian(JalaliDate(1403, 12, 30)))
        assertThrows(IllegalArgumentException::class.java) {
            JalaliDate.toGregorian(JalaliDate(1404, 12, 30))
        }
    }

    @Test
    fun rejectsInvalidGregorianAndJalaliDates() {
        assertThrows(java.time.DateTimeException::class.java) {
            JalaliDate.fromGregorian(2026, 2, 30)
        }
        assertThrows(IllegalArgumentException::class.java) {
            JalaliDate.toGregorian(JalaliDate(1405, 7, 31))
        }
    }

    @Test
    fun formatIsoDateKeyUsesJalaliLayoutAndFallsBackOnMalformedInput() {
        assertEquals("1405/08/05", JalaliDate.formatIsoDateKey("2026-10-27"))
        assertEquals("1405/01/01", JalaliDate.formatIsoDateKey("2026-03-21"))
        assertEquals("not-a-date", JalaliDate.formatIsoDateKey("not-a-date"))
    }

    @Test
    fun everyDayRoundTripsAcrossRepresentativeJalaliYears() {
        for (year in 1390..1410) {
            for (month in 1..12) {
                val firstDay = JalaliDate.toGregorian(JalaliDate(year, month, 1))
                val nextMonth = if (month == 12) {
                    JalaliDate(year + 1, 1, 1)
                } else {
                    JalaliDate(year, month + 1, 1)
                }
                val nextMonthStart = JalaliDate.toGregorian(nextMonth)
                val monthLength = (nextMonthStart.toEpochDay() - firstDay.toEpochDay()).toInt()

                for (day in 1..monthLength) {
                    val gregorian = firstDay.plusDays((day - 1).toLong())
                    assertEquals(
                        "Round-trip failed for Jalali $year/$month/$day",
                        JalaliDate(year, month, day),
                        JalaliDate.fromGregorian(gregorian),
                    )
                }
            }
        }
    }

    @Test
    fun displayStringIsZeroPadded() {
        assertEquals("1405/01/01", JalaliDate(1405, 1, 1).toDisplayString())
        assertEquals("1405/12/09", JalaliDate(1405, 12, 9).toDisplayString())
    }
}

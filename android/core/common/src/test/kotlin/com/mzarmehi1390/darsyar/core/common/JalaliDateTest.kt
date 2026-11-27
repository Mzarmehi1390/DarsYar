package com.mzarmehi1390.darsyar.core.common

import org.junit.Assert.assertEquals
import org.junit.Test
import java.time.LocalDate

class JalaliDateTest {
    @Test
    fun convertsKnownGregorianAnchorsToExpectedJalali() {
        // 2026-03-21 is Nowruz 1405
        assertEquals(JalaliDate(1405, 1, 1), JalaliDate.fromGregorian(2026, 3, 21))
        // Mid-year sample
        assertEquals(JalaliDate(1405, 8, 5), JalaliDate.fromGregorian(2026, 10, 27))
        // Year-end sample (Esfand)
        assertEquals(JalaliDate(1404, 12, 29), JalaliDate.fromGregorian(2026, 3, 20))
    }

    @Test
    fun convertsViaLocalDate() {
        val date = LocalDate.of(2026, 11, 27)
        val jalali = JalaliDate.fromGregorian(date)
        assertEquals(1405, jalali.year)
        assertEquals(9, jalali.month) // Azar
        assertEquals(6, jalali.day)
    }

    @Test
    fun formatIsoDateKeyUsesJalaliLayout() {
        assertEquals("1405/08/05", JalaliDate.formatIsoDateKey("2026-10-27"))
        assertEquals("1405/01/01", JalaliDate.formatIsoDateKey("2026-03-21"))
    }

    @Test
    fun formatIsoDateKeyFallsBackOnMalformedInput() {
        assertEquals("not-a-date", JalaliDate.formatIsoDateKey("not-a-date"))
    }

    @Test
    fun displayStringIsZeroPadded() {
        assertEquals("1405/01/01", JalaliDate(1405, 1, 1).toDisplayString())
        assertEquals("1405/12/09", JalaliDate(1405, 12, 9).toDisplayString())
    }
}

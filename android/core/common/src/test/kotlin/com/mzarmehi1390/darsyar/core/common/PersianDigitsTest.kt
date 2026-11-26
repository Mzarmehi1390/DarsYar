package com.mzarmehi1390.darsyar.core.common

import org.junit.Assert.assertEquals
import org.junit.Test

class PersianDigitsTest {
    @Test
    fun formatsWesternDigitsAsPersianDigits() {
        assertEquals("۱۴۰۵/۰۸/۰۵", PersianDigits.toPersianDigits("1405/08/05"))
    }

    @Test
    fun normalizesPersianAndArabicIndicDigitsForParsing() {
        assertEquals("2026-11-26", PersianDigits.toLatinDigits("۲۰۲۶-١١-٢٦"))
    }

    @Test
    fun leavesNonDigitCharactersUnchanged() {
        assertEquals("ریاضی · ۱۲:۳۰", PersianDigits.toPersianDigits("ریاضی · 12:30"))
    }

    @Test
    fun recognizesAllSupportedDecimalDigitSetsWithoutChangingTheirGlyphs() {
        val input = "09۰۹٠٩"
        assertEquals(input, input.filter(PersianDigits::isSupportedDigit))
        assertEquals("۰۹", "۰۹:ab".filter(PersianDigits::isSupportedDigit))
        assertEquals(false, PersianDigits.isSupportedDigit('x'))
    }

    @Test
    fun integerFormattingUsesPersianDigits() {
        assertEquals("۱۲۳۴", PersianDigits.format(1234))
        assertEquals("۹۰۰۰۰۰۰۰۰۰", PersianDigits.format(9_000_000_000L))
    }
}

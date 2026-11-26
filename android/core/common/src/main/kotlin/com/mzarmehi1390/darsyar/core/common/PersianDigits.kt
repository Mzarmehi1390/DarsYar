package com.mzarmehi1390.darsyar.core.common

/**
 * Converts between Western, Persian, and Arabic-Indic decimal digits.
 *
 * Keep persisted values and machine-readable dates in their canonical Latin
 * representation; use [format] only at the presentation boundary.
 */
object PersianDigits {
    private const val PERSIAN_ZERO = '\u06F0'
    private const val ARABIC_INDIC_ZERO = '\u0660'

    fun toPersianDigits(value: String): String = buildString(value.length) {
        value.forEach { character ->
            append(
                when (character) {
                    in '0'..'9' -> PERSIAN_ZERO + (character - '0')
                    in ARABIC_INDIC_ZERO..(ARABIC_INDIC_ZERO + 9) ->
                        PERSIAN_ZERO + (character - ARABIC_INDIC_ZERO)
                    else -> character
                },
            )
        }
    }

    fun toLatinDigits(value: String): String = buildString(value.length) {
        value.forEach { character ->
            append(
                when (character) {
                    in PERSIAN_ZERO..(PERSIAN_ZERO + 9) -> '0' + (character - PERSIAN_ZERO)
                    in ARABIC_INDIC_ZERO..(ARABIC_INDIC_ZERO + 9) ->
                        '0' + (character - ARABIC_INDIC_ZERO)
                    else -> character
                },
            )
        }
    }

    fun format(value: Int): String = toPersianDigits(value.toString())
    fun format(value: Long): String = toPersianDigits(value.toString())
}

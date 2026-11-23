package com.mzarmehi1390.darsyar.core.common

fun interface AppClock {
    /** Returns Unix epoch milliseconds, independent of local timezone. */
    fun nowEpochMillis(): Long
}

object SystemAppClock : AppClock {
    override fun nowEpochMillis(): Long = System.currentTimeMillis()
}

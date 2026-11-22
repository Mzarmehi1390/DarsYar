package com.mzarmehi1390.darsyar.core.common

import java.time.Instant

fun interface AppClock {
    fun now(): Instant
}

object SystemAppClock : AppClock {
    override fun now(): Instant = Instant.now()
}

package com.mzarmehi1390.darsyar.core.database

import android.content.Context
import androidx.room.Room

object DarsYarDatabaseFactory {
    fun create(context: Context): DarsYarDatabase =
        Room.databaseBuilder(
            context.applicationContext,
            DarsYarDatabase::class.java,
            DarsYarDatabase.DATABASE_NAME,
        )
            .build()
}

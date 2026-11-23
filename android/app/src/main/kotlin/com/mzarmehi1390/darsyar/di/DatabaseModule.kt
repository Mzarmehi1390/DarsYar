package com.mzarmehi1390.darsyar.di

import android.content.Context
import androidx.room.Room
import com.mzarmehi1390.darsyar.core.database.DarsYarDatabase
import com.mzarmehi1390.darsyar.core.database.MIGRATION_1_2
import dagger.Module
import dagger.Provides
import dagger.hilt.InstallIn
import dagger.hilt.android.qualifiers.ApplicationContext
import dagger.hilt.components.SingletonComponent
import javax.inject.Singleton

@Module
@InstallIn(SingletonComponent::class)
object DatabaseModule {
    @Provides
    @Singleton
    fun provideDatabase(
        @ApplicationContext context: Context,
    ): DarsYarDatabase = Room.databaseBuilder(
        context,
        DarsYarDatabase::class.java,
        DarsYarDatabase.DATABASE_NAME,
    )
        .addMigrations(MIGRATION_1_2)
        .build()
}

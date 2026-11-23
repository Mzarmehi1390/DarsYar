package com.mzarmehi1390.darsyar.di

import android.content.Context
import com.mzarmehi1390.darsyar.core.datastore.DarsYarPreferencesRepository
import dagger.Module
import dagger.Provides
import dagger.hilt.InstallIn
import dagger.hilt.android.qualifiers.ApplicationContext
import dagger.hilt.components.SingletonComponent
import javax.inject.Singleton

@Module
@InstallIn(SingletonComponent::class)
object PreferencesModule {
    @Provides
    @Singleton
    fun providePreferencesRepository(
        @ApplicationContext context: Context,
    ): DarsYarPreferencesRepository = DarsYarPreferencesRepository(context)
}

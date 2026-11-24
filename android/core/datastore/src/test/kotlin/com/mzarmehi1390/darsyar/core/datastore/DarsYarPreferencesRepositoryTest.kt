package com.mzarmehi1390.darsyar.core.datastore

import android.content.Context
import androidx.test.core.app.ApplicationProvider
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.runBlocking
import org.junit.Assert.assertEquals
import org.junit.Assert.assertThrows
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35])
class DarsYarPreferencesRepositoryTest {

    private val context: Context
        get() = ApplicationProvider.getApplicationContext()

    @Test
    fun defaultsAreUsedWhenNoPreferencesHaveBeenSaved() = runBlocking {
        val preferences = DarsYarPreferencesRepository(context).preferences.first()

        assertEquals(DarsYarPreferences(), preferences)
    }

    @Test
    fun themeAndAnimationPreferencesRemainSavedAcrossRepositoryInstances() = runBlocking {
        val repository = DarsYarPreferencesRepository(context)
        repository.setThemeMode("dark")
        repository.setAnimationsEnabled(false)

        val restored = DarsYarPreferencesRepository(context).preferences.first()

        assertEquals("dark", restored.themeMode)
        assertEquals(false, restored.animationsEnabled)
    }

    @Test
    fun legacyFlutterAppearancePreferencesAreMigrated() = runBlocking {
        context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            .edit()
            .putString("flutter.darsyar.themeMode", "light")
            .putBoolean("flutter.darsyar.animationsEnabled", false)
            .commit()

        val migrated = DarsYarPreferencesRepository(context).preferences.first()

        assertEquals("light", migrated.themeMode)
        assertEquals(false, migrated.animationsEnabled)
    }

    @Test
    fun unsupportedThemeModesAreRejected() {
        val repository = DarsYarPreferencesRepository(context)

        assertThrows(IllegalArgumentException::class.java) {
            runBlocking { repository.setThemeMode("sepia") }
        }
    }
}

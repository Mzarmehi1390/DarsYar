package com.mzarmehi1390.darsyar.core.datastore

import android.content.Context
import androidx.datastore.preferences.core.emptyPreferences
import androidx.test.core.app.ApplicationProvider
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.runBlocking
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
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
    fun legacyFlutterAppearancePreferencesAreMigratedWithoutOverwritingCurrentValues() {
        val legacy = legacyPreferences()
        legacy.edit()
            .putString("flutter.darsyar.themeMode", "light")
            .putBoolean("flutter.darsyar.animationsEnabled", false)
            .commit()

        val appearance = readLegacyAppearancePreferences(legacy)
        val migrated = migrateLegacyAppearancePreferences(
            legacyThemeMode = appearance.themeMode,
            legacyAnimationsEnabled = appearance.animationsEnabled,
            current = emptyPreferences(),
        )

        assertEquals("light", migrated.asMap().entries.first { it.key.name == "theme_mode" }.value)
        assertEquals(false, migrated.asMap().entries.first { it.key.name == "animations_enabled" }.value)
    }

    @Test
    fun existingDataStoreValuesTakePrecedenceOverLegacyValues() {
        val legacy = legacyPreferences()
        legacy.edit()
            .putString("flutter.darsyar.themeMode", "light")
            .putBoolean("flutter.darsyar.animationsEnabled", false)
            .commit()

        val current = androidx.datastore.preferences.core.mutablePreferencesOf(
            androidx.datastore.preferences.core.stringPreferencesKey("theme_mode") to "dark",
            androidx.datastore.preferences.core.booleanPreferencesKey("animations_enabled") to true,
        )
        val appearance = readLegacyAppearancePreferences(legacy)
        val migrated = migrateLegacyAppearancePreferences(
            legacyThemeMode = appearance.themeMode,
            legacyAnimationsEnabled = appearance.animationsEnabled,
            current = current,
        )

        assertEquals("dark", migrated.asMap().entries.first { it.key.name == "theme_mode" }.value)
        assertEquals(true, migrated.asMap().entries.first { it.key.name == "animations_enabled" }.value)
    }

    @Test
    fun wrongTypedLegacyAppearanceValuesAreIgnoredInsteadOfThrowing() {
        val legacy = legacyPreferences()
        legacy.edit()
            .putInt("flutter.darsyar.themeMode", 1)
            .putString("flutter.darsyar.animationsEnabled", "false")
            .commit()

        val appearance = readLegacyAppearancePreferences(legacy)

        assertNull(appearance.themeMode)
        assertNull(appearance.animationsEnabled)

        val migrated = migrateLegacyAppearancePreferences(
            legacyThemeMode = appearance.themeMode,
            legacyAnimationsEnabled = appearance.animationsEnabled,
            current = emptyPreferences(),
        )
        assertFalse(migrated.asMap().containsKey(androidx.datastore.preferences.core.stringPreferencesKey("theme_mode")))
        assertFalse(migrated.asMap().containsKey(androidx.datastore.preferences.core.booleanPreferencesKey("animations_enabled")))
    }

    @Test
    fun unsupportedThemeModesAreRejected() {
        val repository = DarsYarPreferencesRepository(context)

        assertThrows(IllegalArgumentException::class.java) {
            runBlocking { repository.setThemeMode("sepia") }
        }
    }

    private fun legacyPreferences() =
        context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE).also {
            it.edit().clear().commit()
        }
}

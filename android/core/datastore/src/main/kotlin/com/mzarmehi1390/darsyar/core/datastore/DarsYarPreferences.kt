package com.mzarmehi1390.darsyar.core.datastore

import android.content.Context
import androidx.datastore.core.DataStore
import androidx.datastore.preferences.core.Preferences
import androidx.datastore.preferences.core.booleanPreferencesKey
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.emptyPreferences
import androidx.datastore.preferences.core.stringPreferencesKey
import androidx.datastore.preferences.core.mutablePreferencesOf
import androidx.datastore.preferences.preferencesDataStore
import androidx.datastore.migrations.SharedPreferencesMigration
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.catch
import kotlinx.coroutines.flow.map
import java.io.IOException

private const val LEGACY_PREFERENCES_FILE = "FlutterSharedPreferences"
private const val LEGACY_THEME_KEY = "flutter.darsyar.themeMode"
private const val LEGACY_ANIMATIONS_KEY = "flutter.darsyar.animationsEnabled"

private val themeModeKey = stringPreferencesKey("theme_mode")
private val animationsEnabledKey = booleanPreferencesKey("animations_enabled")

private val Context.darsYarPreferencesDataStore: DataStore<Preferences> by preferencesDataStore(
    name = "darsyar_preferences",
    produceMigrations = { context ->
        listOf(
            SharedPreferencesMigration(
                context = context,
                sharedPreferencesName = LEGACY_PREFERENCES_FILE,
                keysToMigrate = setOf(LEGACY_THEME_KEY, LEGACY_ANIMATIONS_KEY),
                migrate = { legacy, current ->
                    val migrated = mutablePreferencesOf()
                    current[themeModeKey]?.let { migrated[themeModeKey] = it }
                    current[animationsEnabledKey]?.let { migrated[animationsEnabledKey] = it }
                    if (!migrated.contains(themeModeKey)) {
                        when (legacy.getString(LEGACY_THEME_KEY, null)) {
                            "light", "dark", "system" ->
                                migrated[themeModeKey] = legacy.getString(LEGACY_THEME_KEY, "system") ?: "system"
                            else -> Unit
                        }
                    }
                    if (!migrated.contains(animationsEnabledKey) && legacy.contains(LEGACY_ANIMATIONS_KEY)) {
                        migrated[animationsEnabledKey] = legacy.getBoolean(LEGACY_ANIMATIONS_KEY, true)
                    }
                    migrated
                },
            ),
        )
    },
)

data class DarsYarPreferences(
    val themeMode: String = "system",
    val animationsEnabled: Boolean = true,
)

class DarsYarPreferencesRepository(context: Context) {
    private val store = context.applicationContext.darsYarPreferencesDataStore

    val preferences: Flow<DarsYarPreferences> = store.data
        .catch { error ->
            if (error is IOException) emit(emptyPreferences()) else throw error
        }
        .map { values ->
            DarsYarPreferences(
                themeMode = values[themeModeKey]?.takeIf { it in setOf("light", "dark", "system") } ?: "system",
                animationsEnabled = values[animationsEnabledKey] ?: true,
            )
        }

    suspend fun setThemeMode(mode: String) {
        require(mode == "light" || mode == "dark" || mode == "system") {
            "Unsupported theme mode: $mode"
        }
        store.edit { it[themeModeKey] = mode }
    }

    suspend fun setAnimationsEnabled(enabled: Boolean) {
        store.edit { it[animationsEnabledKey] = enabled }
    }
}

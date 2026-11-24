package com.mzarmehi1390.darsyar.core.designsystem

import androidx.compose.animation.animateContentSize
import androidx.compose.animation.core.snap
import androidx.compose.animation.core.spring
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.compositionLocalOf
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalLayoutDirection
import androidx.compose.ui.unit.LayoutDirection
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.material3.Typography

private val LightColors = lightColorScheme(
    primary = Color(0xFF087F5B),
    onPrimary = Color.White,
    secondary = Color(0xFF557DA8),
    background = Color(0xFFEAF0F6),
    surface = Color(0xFFF4F7FA),
    onSurface = Color(0xFF172536),
    onSurfaceVariant = Color(0xFF536579),
)

private val DarkColors = darkColorScheme(
    primary = Color(0xFF79D7AE),
    onPrimary = Color(0xFF082C20),
    secondary = Color(0xFF9BC4E8),
    background = Color(0xFF0B1422),
    surface = Color(0xFF192A3D),
    onSurface = Color(0xFFEAF3FC),
    onSurfaceVariant = Color(0xFFB2C1D0),
)

/** App-wide motion preference consumed by size-changing Compose components. */
val LocalDarsYarAnimationsEnabled = compositionLocalOf { true }

/**
 * Animates content-size changes when motion is enabled and applies changes immediately
 * when the user has disabled animations.
 */
@Composable
fun Modifier.darsYarAnimateContentSize(): Modifier {
    val animationsEnabled = LocalDarsYarAnimationsEnabled.current
    return animateContentSize(
        animationSpec = if (animationsEnabled) spring() else snap(),
    )
}

@Composable
fun DarsYarTheme(
    darkTheme: Boolean = isSystemInDarkTheme(),
    animationsEnabled: Boolean = true,
    content: @Composable () -> Unit,
) {
    CompositionLocalProvider(
        LocalLayoutDirection provides LayoutDirection.Rtl,
        LocalDarsYarAnimationsEnabled provides animationsEnabled,
    ) {
        MaterialTheme(
            colorScheme = if (darkTheme) DarkColors else LightColors,
            typography = Typography(),
            content = content,
        )
    }
}

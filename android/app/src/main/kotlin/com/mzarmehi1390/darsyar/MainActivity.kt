package com.mzarmehi1390.darsyar

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Button
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.mzarmehi1390.darsyar.core.designsystem.DarsYarTheme
import com.mzarmehi1390.darsyar.data.AppStartupCoordinator
import com.mzarmehi1390.darsyar.data.AppStartupState
import dagger.hilt.android.AndroidEntryPoint
import javax.inject.Inject

@AndroidEntryPoint
class MainActivity : ComponentActivity() {
    @Inject
    lateinit var startupCoordinator: AppStartupCoordinator

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        setContent {
            DarsYarTheme {
                val startupState by startupCoordinator.state.collectAsStateWithLifecycle()
                var retryAttempt by remember { mutableStateOf(0) }

                LaunchedEffect(startupCoordinator, retryAttempt) {
                    startupCoordinator.ensureReady()
                }

                Surface(modifier = Modifier.fillMaxSize()) {
                    when (startupState) {
                        AppStartupState.NotStarted,
                        AppStartupState.Migrating -> StartupLoadingContent()
                        AppStartupState.Ready -> NativeHomePlaceholder()
                        is AppStartupState.Failed -> StartupErrorContent(
                            onRetry = { retryAttempt++ },
                        )
                    }
                }
            }
        }
    }
}

@androidx.compose.runtime.Composable
private fun NativeHomePlaceholder() {
    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(24.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center,
    ) {
        Text(
            text = "درس‌یار",
            style = MaterialTheme.typography.headlineLarge,
            fontWeight = FontWeight.Bold,
        )
        Text(
            text = "زیرساخت نسخه بومی اندروید",
            modifier = Modifier.padding(top = 8.dp),
            style = MaterialTheme.typography.bodyLarge,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
    }
}

@androidx.compose.runtime.Composable
private fun StartupLoadingContent() {
    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(24.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center,
    ) {
        CircularProgressIndicator()
        Text(
            text = "در حال آماده‌سازی اطلاعات درس‌یار…",
            modifier = Modifier.padding(top = 20.dp),
            style = MaterialTheme.typography.bodyLarge,
        )
    }
}

@androidx.compose.runtime.Composable
private fun StartupErrorContent(onRetry: () -> Unit) {
    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(24.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center,
    ) {
        Text(
            text = "آماده‌سازی اطلاعات انجام نشد",
            style = MaterialTheme.typography.titleLarge,
            fontWeight = FontWeight.SemiBold,
        )
        Text(
            text = "اطلاعات قبلی دست‌نخورده باقی مانده‌اند. دوباره تلاش کنید.",
            modifier = Modifier.padding(top = 8.dp),
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
        Button(
            onClick = onRetry,
            modifier = Modifier.padding(top = 20.dp),
        ) {
            Text("تلاش دوباره")
        }
    }
}

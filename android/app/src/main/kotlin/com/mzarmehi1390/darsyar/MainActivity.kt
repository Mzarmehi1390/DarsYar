package com.mzarmehi1390.darsyar

import android.net.Uri
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.NavigationBar
import androidx.compose.material3.NavigationBarItem
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.navigation.NavGraph.Companion.findStartDestination
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.currentBackStackEntryAsState
import androidx.navigation.compose.rememberNavController
import com.mzarmehi1390.darsyar.core.designsystem.DarsYarTheme
import com.mzarmehi1390.darsyar.data.AppStartupCoordinator
import com.mzarmehi1390.darsyar.data.AppStartupState
import com.mzarmehi1390.darsyar.data.DarsYarBackupService
import com.mzarmehi1390.darsyar.data.DarsYarBackupSummary
import com.mzarmehi1390.darsyar.features.exams.presentation.ExamViewModel
import com.mzarmehi1390.darsyar.features.exams.presentation.ExamsScreen
import com.mzarmehi1390.darsyar.features.planner.presentation.PlannerScreen
import com.mzarmehi1390.darsyar.features.planner.presentation.PlannerViewModel
import dagger.hilt.android.AndroidEntryPoint
import kotlinx.coroutines.launch
import javax.inject.Inject

@AndroidEntryPoint
class MainActivity : ComponentActivity() {
    @Inject lateinit var startupCoordinator: AppStartupCoordinator
    @Inject lateinit var backupService: DarsYarBackupService

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        setContent {
            DarsYarTheme {
                val startupState by startupCoordinator.state.collectAsStateWithLifecycle()
                var retryAttempt by remember { mutableStateOf(0) }
                LaunchedEffect(startupCoordinator, retryAttempt) { startupCoordinator.ensureReady() }
                Surface(modifier = Modifier.fillMaxSize()) {
                    when (startupState) {
                        AppStartupState.NotStarted, AppStartupState.Migrating -> StartupLoadingContent()
                        AppStartupState.Ready -> NativeAppNavigation(backupService)
                        is AppStartupState.Failed -> StartupErrorContent(onRetry = { retryAttempt++ })
                    }
                }
            }
        }
    }
}

@Composable
private fun NativeAppNavigation(backupService: DarsYarBackupService) {
    val navController = rememberNavController()
    val backStackEntry by navController.currentBackStackEntryAsState()
    val currentRoute = backStackEntry?.destination?.route ?: "home"
    val destinations = listOf(
        AppDestination("home", "خانه", "⌂"),
        AppDestination("planner", "برنامه‌ریز", "▦"),
        AppDestination("exams", "آزمون‌ها", "✓"),
        AppDestination("settings", "تنظیمات", "⚙"),
    )
    Scaffold(bottomBar = {
        NavigationBar {
            destinations.forEach { destination ->
                NavigationBarItem(
                    selected = currentRoute == destination.route,
                    onClick = {
                        navController.navigate(destination.route) {
                            popUpTo(navController.graph.findStartDestination().id) { saveState = true }
                            launchSingleTop = true
                            restoreState = true
                        }
                    },
                    icon = { Text(destination.symbol, style = MaterialTheme.typography.titleLarge) },
                    label = { Text(destination.label) },
                )
            }
        }
    }) { padding ->
        NavHost(navController, startDestination = "home", modifier = Modifier.padding(padding)) {
            composable("home") {
                HomeScreen(
                    onPlanner = { navController.navigate("planner") },
                    onExams = { navController.navigate("exams") },
                    onSettings = { navController.navigate("settings") },
                )
            }
            composable("planner") {
                val viewModel: PlannerViewModel = hiltViewModel()
                PlannerScreen(viewModel)
            }
            composable("exams") {
                val viewModel: ExamViewModel = hiltViewModel()
                ExamsScreen(viewModel)
            }
            composable("settings") { BackupSettingsScreen(backupService) }
        }
    }
}

private data class AppDestination(val route: String, val label: String, val symbol: String)

@Composable
private fun HomeScreen(onPlanner: () -> Unit, onExams: () -> Unit, onSettings: () -> Unit) {
    Column(Modifier.fillMaxSize().padding(24.dp), verticalArrangement = Arrangement.spacedBy(16.dp)) {
        Text("درس‌یار", style = MaterialTheme.typography.headlineLarge, fontWeight = FontWeight.Bold)
        Text("فضای متمرکز برای برنامه‌ریزی مطالعه و پیگیری آزمون‌ها.", color = MaterialTheme.colorScheme.onSurfaceVariant)
        Button(onClick = onPlanner) { Text("رفتن به برنامه‌ریز") }
        Button(onClick = onExams) { Text("مدیریت آزمون‌ها") }
        OutlinedButton(onClick = onSettings) { Text("تنظیمات و پشتیبان‌گیری") }
    }
}

@Composable
private fun BackupSettingsScreen(backupService: DarsYarBackupService) {
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    var busy by remember { mutableStateOf(false) }
    var statusMessage by remember { mutableStateOf<String?>(null) }
    var pendingBackup by remember { mutableStateOf<String?>(null) }
    var pendingSummary by remember { mutableStateOf<DarsYarBackupSummary?>(null) }

    val exportLauncher = rememberLauncherForActivityResult(ActivityResultContracts.CreateDocument("application/json")) { uri: Uri? ->
        if (uri != null) scope.launch {
            busy = true
            statusMessage = null
            try {
                val json = backupService.exportBackup()
                val output = context.contentResolver.openOutputStream(uri) ?: error("امکان نوشتن فایل انتخاب‌شده وجود ندارد.")
                output.bufferedWriter(Charsets.UTF_8).use { it.write(json) }
                statusMessage = "نسخهٔ پشتیبان با موفقیت ذخیره شد."
            } catch (exception: Exception) {
                statusMessage = exception.localizedMessage?.takeIf { it.isNotBlank() } ?: "ذخیرهٔ نسخهٔ پشتیبان انجام نشد."
            } finally { busy = false }
        }
    }

    val importLauncher = rememberLauncherForActivityResult(ActivityResultContracts.OpenDocument()) { uri: Uri? ->
        if (uri != null) scope.launch {
            busy = true
            statusMessage = null
            try {
                val input = context.contentResolver.openInputStream(uri) ?: error("امکان خواندن فایل انتخاب‌شده وجود ندارد.")
                val json = input.bufferedReader(Charsets.UTF_8).use { it.readText() }
                val summary = backupService.validateBackup(json)
                pendingBackup = json
                pendingSummary = summary
            } catch (exception: Exception) {
                statusMessage = exception.localizedMessage?.takeIf { it.isNotBlank() } ?: "فایل انتخاب‌شده معتبر نیست."
            } finally { busy = false }
        }
    }

    if (pendingBackup != null && pendingSummary != null) {
        val summary = pendingSummary!!
        AlertDialog(
            onDismissRequest = { pendingBackup = null; pendingSummary = null },
            title = { Text("بازیابی نسخهٔ پشتیبان؟") },
            text = {
                Text("این فایل شامل ${summary.taskCount} کار، ${summary.studySessionCount} جلسهٔ مطالعه، " +
                    "${summary.examCount} آزمون و ${summary.resultCount} نتیجه است. " +
                    "با ادامه، اطلاعات فعلی برنامه با اطلاعات این فایل جایگزین می‌شود.")
            },
            confirmButton = {
                TextButton(enabled = !busy, onClick = {
                    val raw = pendingBackup ?: return@TextButton
                    pendingBackup = null
                    pendingSummary = null
                    scope.launch {
                        busy = true
                        statusMessage = null
                        try {
                            backupService.restoreBackup(raw)
                            statusMessage = "اطلاعات با موفقیت بازیابی شد."
                        } catch (exception: Exception) {
                            statusMessage = exception.localizedMessage?.takeIf { it.isNotBlank() } ?: "بازیابی نسخهٔ پشتیبان انجام نشد."
                        } finally { busy = false }
                    }
                }) { Text("جایگزینی و بازیابی") }
            },
            dismissButton = {
                TextButton(enabled = !busy, onClick = { pendingBackup = null; pendingSummary = null }) { Text("انصراف") }
            },
        )
    }

    Column(Modifier.fillMaxSize().padding(24.dp), verticalArrangement = Arrangement.spacedBy(16.dp)) {
        Text("تنظیمات", style = MaterialTheme.typography.headlineLarge, fontWeight = FontWeight.Bold)
        Text("پشتیبان‌گیری و بازیابی", style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.SemiBold)
        Text(
            "از کارها، جلسات مطالعه، آزمون‌ها و نتایج خود یک فایل JSON بسازید. برای انتقال اطلاعات به دستگاه دیگر، همین فایل را بازیابی کنید.",
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
        Button(onClick = { exportLauncher.launch("darsyar-backup.json") }, enabled = !busy, modifier = Modifier.fillMaxWidth()) {
            Text("ذخیرهٔ نسخهٔ پشتیبان")
        }
        OutlinedButton(onClick = { importLauncher.launch(arrayOf("application/json")) }, enabled = !busy, modifier = Modifier.fillMaxWidth()) {
            Text("انتخاب فایل برای بازیابی")
        }
        if (busy) Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.Center, verticalAlignment = Alignment.CenterVertically) {
            CircularProgressIndicator()
            Text("در حال پردازش…", modifier = Modifier.padding(start = 8.dp))
        }
        statusMessage?.let { Text(it, color = MaterialTheme.colorScheme.primary, style = MaterialTheme.typography.bodyMedium) }
        Text(
            "فایل فقط با انتخاب خودتان از طریق پنجرهٔ امن اندروید خوانده یا ذخیره می‌شود؛ برنامه به مجوز دسترسی گسترده به حافظه نیاز ندارد.",
            style = MaterialTheme.typography.bodySmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
    }
}

@Composable
private fun StartupLoadingContent() {
    Column(Modifier.fillMaxSize().padding(24.dp), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.Center) {
        CircularProgressIndicator()
        Text("در حال آماده‌سازی اطلاعات درس‌یار…", modifier = Modifier.padding(top = 20.dp), style = MaterialTheme.typography.bodyLarge)
    }
}

@Composable
private fun StartupErrorContent(onRetry: () -> Unit) {
    Column(Modifier.fillMaxSize().padding(24.dp), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.Center) {
        Text("آماده‌سازی اطلاعات انجام نشد", style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.SemiBold)
        Text("اطلاعات قبلی دست‌نخورده باقی مانده‌اند. دوباره تلاش کنید.", modifier = Modifier.padding(top = 8.dp), style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
        Button(onClick = onRetry, modifier = Modifier.padding(top = 20.dp)) { Text("تلاش دوباره") }
    }
}

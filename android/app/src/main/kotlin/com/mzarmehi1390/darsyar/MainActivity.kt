package com.mzarmehi1390.darsyar

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Button
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.NavigationBar
import androidx.compose.material3.NavigationBarItem
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
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
import com.mzarmehi1390.darsyar.features.exams.presentation.ExamViewModel
import com.mzarmehi1390.darsyar.features.exams.presentation.ExamsScreen
import com.mzarmehi1390.darsyar.features.planner.presentation.PlannerScreen
import com.mzarmehi1390.darsyar.features.planner.presentation.PlannerViewModel
import com.mzarmehi1390.darsyar.data.AppBackupSettingsGateway
import com.mzarmehi1390.darsyar.features.settings.presentation.BackupSettingsScreen
import dagger.hilt.android.AndroidEntryPoint
import javax.inject.Inject

@AndroidEntryPoint
class MainActivity : ComponentActivity() {
    @Inject lateinit var startupCoordinator: AppStartupCoordinator
    @Inject lateinit var backupSettingsGateway: AppBackupSettingsGateway

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
                        AppStartupState.Ready -> NativeAppNavigation(backupSettingsGateway)
                        is AppStartupState.Failed -> StartupErrorContent(onRetry = { retryAttempt++ })
                    }
                }
            }
        }
    }
}

@Composable
private fun NativeAppNavigation(backupSettingsGateway: AppBackupSettingsGateway) {
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
            composable("settings") { BackupSettingsScreen(backupSettingsGateway) }
        }
    }
}

private data class AppDestination(val route: String, val label: String, val symbol: String)

@Composable
private fun HomeScreen(onPlanner: () -> Unit, onExams: () -> Unit, onSettings: () -> Unit) {
    val plannerViewModel: PlannerViewModel = hiltViewModel()
    val plannerState by plannerViewModel.uiState.collectAsStateWithLifecycle()
    val tasks = plannerState.tasks
    val completedCount = tasks.count { it.done }
    val pendingTasks = tasks.filterNot { it.done }.take(3)
    val progress = if (tasks.isEmpty()) 0f else completedCount.toFloat() / tasks.size

    Column(
        Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(24.dp),
        verticalArrangement = Arrangement.spacedBy(18.dp),
    ) {
        Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
            Text("درس‌یار", style = MaterialTheme.typography.headlineLarge, fontWeight = FontWeight.Bold)
            Text("نمای کلی برنامهٔ مطالعه و کارهای پیشِ رو", color = MaterialTheme.colorScheme.onSurfaceVariant)
        }

        Card(
            modifier = Modifier.fillMaxWidth(),
            colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceContainerHigh),
        ) {
            Column(Modifier.fillMaxWidth().padding(18.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
                Text("پیشرفت کارها", style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.SemiBold)
                Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween, verticalAlignment = Alignment.CenterVertically) {
                    Text("$completedCount از ${tasks.size} کار انجام‌شده")
                    Text(
                        if (tasks.isEmpty()) "—" else "${(progress * 100).toInt()}٪",
                        color = MaterialTheme.colorScheme.primary,
                        fontWeight = FontWeight.Bold,
                    )
                }
                LinearProgressIndicator(progress = progress, modifier = Modifier.fillMaxWidth())
                if (plannerState.isLoading) {
                    Text("در حال دریافت اطلاعات…", color = MaterialTheme.colorScheme.onSurfaceVariant)
                } else if (plannerState.errorMessage != null) {
                    Text(plannerState.errorMessage ?: "", color = MaterialTheme.colorScheme.error, style = MaterialTheme.typography.bodySmall)
                } else if (tasks.isEmpty()) {
                    Text("هنوز کاری ثبت نکرده‌ای. از برنامه‌ریز اولین کار خودت را اضافه کن.", color = MaterialTheme.colorScheme.onSurfaceVariant)
                } else {
                    Text("${tasks.size - completedCount} کار باقی مانده است.", color = MaterialTheme.colorScheme.onSurfaceVariant)
                }
            }
        }

        Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
            Text("کارهای پیشِ رو", style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.SemiBold)
            when {
                plannerState.isLoading -> Text("در حال بارگذاری کارها…", color = MaterialTheme.colorScheme.onSurfaceVariant)
                pendingTasks.isEmpty() -> Text(
                    if (tasks.isEmpty()) "با افزودن کار در برنامه‌ریز، آن‌ها را اینجا دنبال کن."
                    else "عالی است؛ فعلاً کار ناتمامی نداری.",
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
                else -> pendingTasks.forEach { task ->
                    Card(
                        modifier = Modifier.fillMaxWidth(),
                        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant),
                    ) {
                        Column(Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 12.dp), verticalArrangement = Arrangement.spacedBy(4.dp)) {
                            Text(task.title, fontWeight = FontWeight.SemiBold)
                            Text(
                                task.dueDate?.let { "${task.subject} · سررسید: $it" } ?: task.subject,
                                style = MaterialTheme.typography.bodySmall,
                                color = MaterialTheme.colorScheme.onSurfaceVariant,
                            )
                        }
                    }
                }
            }
        }

        Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
            Text("دسترسی سریع", style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.SemiBold)
            Button(onClick = onPlanner, modifier = Modifier.fillMaxWidth()) { Text("رفتن به برنامه‌ریز") }
            OutlinedButton(onClick = onExams, modifier = Modifier.fillMaxWidth()) { Text("مدیریت آزمون‌ها") }
            OutlinedButton(onClick = onSettings, modifier = Modifier.fillMaxWidth()) { Text("تنظیمات و پشتیبان‌گیری") }
        }
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

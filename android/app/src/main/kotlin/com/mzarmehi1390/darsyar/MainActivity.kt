package com.mzarmehi1390.darsyar

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Button
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.NavigationBar
import androidx.compose.material3.NavigationBarItem
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
import androidx.navigation.hasRoute
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.currentBackStackEntryAsState
import androidx.navigation.compose.rememberNavController
import com.mzarmehi1390.darsyar.core.designsystem.DarsYarTheme
import com.mzarmehi1390.darsyar.core.datastore.DarsYarPreferences
import com.mzarmehi1390.darsyar.core.datastore.DarsYarPreferencesRepository
import com.mzarmehi1390.darsyar.data.AppBackupSettingsGateway
import com.mzarmehi1390.darsyar.data.AppStartupCoordinator
import com.mzarmehi1390.darsyar.data.AppStartupState
import com.mzarmehi1390.darsyar.features.dashboard.presentation.DashboardScreen
import com.mzarmehi1390.darsyar.features.exams.presentation.ExamViewModel
import com.mzarmehi1390.darsyar.features.exams.presentation.ExamsScreen
import com.mzarmehi1390.darsyar.features.planner.presentation.PlannerScreen
import com.mzarmehi1390.darsyar.features.planner.presentation.PlannerViewModel
import com.mzarmehi1390.darsyar.features.settings.presentation.BackupSettingsScreen
import com.mzarmehi1390.darsyar.features.statistics.presentation.StatisticsScreen
import dagger.hilt.android.AndroidEntryPoint
import javax.inject.Inject
import kotlinx.serialization.Serializable

@AndroidEntryPoint
class MainActivity : ComponentActivity() {
    @Inject lateinit var startupCoordinator: AppStartupCoordinator
    @Inject lateinit var preferencesRepository: DarsYarPreferencesRepository
    @Inject lateinit var backupSettingsGateway: AppBackupSettingsGateway

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        setContent {
            val preferences by preferencesRepository.preferences.collectAsStateWithLifecycle(initialValue = DarsYarPreferences())
            val darkTheme = when (preferences.themeMode) {
                "light" -> false
                "dark" -> true
                else -> isSystemInDarkTheme()
            }
            DarsYarTheme(darkTheme = darkTheme, animationsEnabled = preferences.animationsEnabled) {
                val startupState by startupCoordinator.state.collectAsStateWithLifecycle()
                var retryAttempt by remember { mutableStateOf(0) }
                LaunchedEffect(startupCoordinator, retryAttempt) { startupCoordinator.ensureReady() }
                Surface(modifier = Modifier.fillMaxSize()) {
                    when (startupState) {
                        AppStartupState.NotStarted, AppStartupState.Migrating -> StartupLoadingContent()
                        AppStartupState.Ready -> NativeAppNavigation(backupSettingsGateway, preferencesRepository)
                        is AppStartupState.Failed -> StartupErrorContent(onRetry = { retryAttempt++ })
                    }
                }
            }
        }
    }
}

@Serializable
private data object HomeRoute

@Serializable
private data object PlannerRoute

@Serializable
private data object ExamsRoute

@Serializable
private data object StatisticsRoute

@Serializable
private data object SettingsRoute

@Composable
private fun NativeAppNavigation(
    backupSettingsGateway: AppBackupSettingsGateway,
    preferencesRepository: DarsYarPreferencesRepository,
) {
    val navController = rememberNavController()
    val backStackEntry by navController.currentBackStackEntryAsState()
    val currentDestination = backStackEntry?.destination

    fun navigateHome() {
        navController.navigate(HomeRoute) {
            popUpTo(navController.graph.findStartDestination().id) { saveState = true }
            launchSingleTop = true
            restoreState = true
        }
    }
    fun navigatePlanner() {
        navController.navigate(PlannerRoute) {
            popUpTo(navController.graph.findStartDestination().id) { saveState = true }
            launchSingleTop = true
            restoreState = true
        }
    }
    fun navigateExams() {
        navController.navigate(ExamsRoute) {
            popUpTo(navController.graph.findStartDestination().id) { saveState = true }
            launchSingleTop = true
            restoreState = true
        }
    }
    fun navigateStatistics() {
        navController.navigate(StatisticsRoute) {
            popUpTo(navController.graph.findStartDestination().id) { saveState = true }
            launchSingleTop = true
            restoreState = true
        }
    }
    fun navigateSettings() {
        navController.navigate(SettingsRoute) {
            popUpTo(navController.graph.findStartDestination().id) { saveState = true }
            launchSingleTop = true
            restoreState = true
        }
    }

    val destinations = listOf(
        AppDestination("خانه", "⌂", currentDestination?.hasRoute<HomeRoute>() == true, ::navigateHome),
        AppDestination("برنامه‌ریز", "▦", currentDestination?.hasRoute<PlannerRoute>() == true, ::navigatePlanner),
        AppDestination("آزمون‌ها", "✓", currentDestination?.hasRoute<ExamsRoute>() == true, ::navigateExams),
        AppDestination("آمار", "▤", currentDestination?.hasRoute<StatisticsRoute>() == true, ::navigateStatistics),
        AppDestination("تنظیمات", "⚙", currentDestination?.hasRoute<SettingsRoute>() == true, ::navigateSettings),
    )
    Scaffold(bottomBar = {
        NavigationBar {
            destinations.forEach { destination ->
                NavigationBarItem(
                    selected = destination.selected,
                    onClick = destination.onClick,
                    icon = { Text(destination.symbol, style = MaterialTheme.typography.titleLarge) },
                    label = { Text(destination.label) },
                )
            }
        }
    }) { padding ->
        NavHost(navController, startDestination = HomeRoute, modifier = Modifier.padding(padding)) {
            composable<HomeRoute> {
                val plannerViewModel: PlannerViewModel = hiltViewModel()
                val plannerState by plannerViewModel.uiState.collectAsStateWithLifecycle()
                DashboardScreen(
                    state = plannerState,
                    onPlanner = ::navigatePlanner,
                    onExams = ::navigateExams,
                    onToggleTask = plannerViewModel::toggleTask,
                    onSaveTask = plannerViewModel::saveTask,
                    onDeleteTask = plannerViewModel::deleteTask,
                )
            }
            composable<PlannerRoute> {
                val viewModel: PlannerViewModel = hiltViewModel()
                PlannerScreen(viewModel)
            }
            composable<ExamsRoute> {
                val viewModel: ExamViewModel = hiltViewModel()
                ExamsScreen(viewModel)
            }
            composable<StatisticsRoute> {
                val plannerViewModel: PlannerViewModel = hiltViewModel()
                val plannerState by plannerViewModel.uiState.collectAsStateWithLifecycle()
                StatisticsScreen(sessions = plannerState.sessions, tasks = plannerState.tasks)
            }
            composable<SettingsRoute> { BackupSettingsScreen(backupSettingsGateway, preferencesRepository) }
        }
    }
}

private data class AppDestination(
    val label: String,
    val symbol: String,
    val selected: Boolean,
    val onClick: () -> Unit,
)

@Composable
private fun StartupLoadingContent() {
    Column(Modifier.fillMaxSize().padding(24.dp), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = androidx.compose.foundation.layout.Arrangement.Center) {
        CircularProgressIndicator()
        Text("در حال آماده‌سازی اطلاعات درس‌یار…", modifier = Modifier.padding(top = 20.dp), style = MaterialTheme.typography.bodyLarge)
    }
}

@Composable
private fun StartupErrorContent(onRetry: () -> Unit) {
    Column(Modifier.fillMaxSize().padding(24.dp), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = androidx.compose.foundation.layout.Arrangement.Center) {
        Text("آماده‌سازی اطلاعات انجام نشد", style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.SemiBold)
        Text("اطلاعات قبلی دست‌نخورده باقی مانده‌اند. دوباره تلاش کنید.", modifier = Modifier.padding(top = 8.dp), style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
        Button(onClick = onRetry, modifier = Modifier.padding(top = 20.dp)) { Text("تلاش دوباره") }
    }
}

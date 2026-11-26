package com.mzarmehi1390.darsyar.features.dashboard.presentation

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Scaffold
import androidx.compose.material3.SnackbarHost
import androidx.compose.material3.SnackbarHostState
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.mzarmehi1390.darsyar.core.common.PersianDigits
import com.mzarmehi1390.darsyar.features.dashboard.domain.DashboardTaskSummary
import com.mzarmehi1390.darsyar.features.planner.domain.models.StudyTask
import com.mzarmehi1390.darsyar.features.planner.presentation.PlannerActionResult
import com.mzarmehi1390.darsyar.features.planner.presentation.PlannerTaskCard
import com.mzarmehi1390.darsyar.features.planner.presentation.PlannerUiState
import com.mzarmehi1390.darsyar.features.planner.presentation.TaskEditorDialog
import com.mzarmehi1390.darsyar.features.planner.presentation.toUserMessage
import kotlinx.coroutines.launch
import java.time.LocalDate

@Composable
fun DashboardScreen(
    state: PlannerUiState,
    onPlanner: () -> Unit,
    onExams: () -> Unit,
    onToggleTask: (StudyTask) -> Unit,
    onSaveTask: (StudyTask, (PlannerActionResult) -> Unit) -> Unit,
    onDeleteTask: (String, (PlannerActionResult) -> Unit) -> Unit,
) {
    val tasks = state.tasks
    val errorMessage = state.errorMessage
    // One bounded pass computes every dashboard aggregate; the pending preview
    // never materializes more than three task references.
    val summary = remember(tasks) { DashboardTaskSummary.from(tasks) }
    val completedCount = summary.completedCount
    val pendingTasks = summary.pendingTasks
    val progress = summary.progress
    val snackbar = remember { SnackbarHostState() }
    val scope = rememberCoroutineScope()
    var editingTask by remember { mutableStateOf<StudyTask?>(null) }
    var showTaskEditor by remember { mutableStateOf(false) }
    var deletingTask by remember { mutableStateOf<StudyTask?>(null) }

    Scaffold(snackbarHost = { SnackbarHost(snackbar) }) { padding ->
        Box(Modifier.fillMaxSize().padding(padding)) {
            LazyColumn(
                modifier = Modifier.fillMaxSize(),
                contentPadding = androidx.compose.foundation.layout.PaddingValues(24.dp),
                verticalArrangement = Arrangement.spacedBy(18.dp),
            ) {
                item {
                    Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
                        Text("درس‌یار", style = MaterialTheme.typography.headlineLarge, fontWeight = FontWeight.Bold)
                        Text("برنامه‌ریزی هوشمند برای یادگیری بهتر", color = MaterialTheme.colorScheme.onSurfaceVariant)
                    }
                }
                item {
                    Card(
                        modifier = Modifier.fillMaxWidth(),
                        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceContainerHigh),
                    ) {
                        Column(Modifier.fillMaxWidth().padding(18.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
                            Text("تمرکز امروز · پیشرفت کارها", style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.SemiBold)
                            Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween, verticalAlignment = Alignment.CenterVertically) {
                                Text("${PersianDigits.format(completedCount)} از ${PersianDigits.format(summary.totalCount)} کار انجام‌شده")
                                Text(if (tasks.isEmpty()) "—" else "${PersianDigits.format((progress * 100).toInt())}٪", color = MaterialTheme.colorScheme.primary, fontWeight = FontWeight.Bold)
                            }
                            LinearProgressIndicator(progress = { progress }, modifier = Modifier.fillMaxWidth())
                            when {
                                state.isLoading -> Text("در حال دریافت اطلاعات…", color = MaterialTheme.colorScheme.onSurfaceVariant)
                                errorMessage != null -> Text(errorMessage, color = MaterialTheme.colorScheme.error, style = MaterialTheme.typography.bodySmall)
                                tasks.isEmpty() -> Text("هنوز کاری ثبت نکرده‌ای. از برنامه‌ریز اولین کار خودت را اضافه کن.", color = MaterialTheme.colorScheme.onSurfaceVariant)
                                else -> Text("${PersianDigits.format(summary.remainingCount)} کار باقی مانده است.", color = MaterialTheme.colorScheme.onSurfaceVariant)
                            }
                        }
                    }
                }
                item {
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        verticalAlignment = Alignment.CenterVertically,
                    ) {
                        Text("کارهای پیشِ رو", style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.SemiBold)
                        Spacer(Modifier.weight(1f))
                        TextButton(onClick = onPlanner) { Text("مشاهده همه") }
                    }
                }
                if (state.isLoading) {
                    item { Text("در حال بارگذاری کارها…", color = MaterialTheme.colorScheme.onSurfaceVariant) }
                } else if (pendingTasks.isEmpty()) {
                    item {
                        Text(
                            if (tasks.isEmpty()) "با افزودن کار در برنامه‌ریز، آن‌ها را اینجا دنبال کن."
                            else "عالی است؛ فعلاً کار ناتمامی نداری.",
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                        )
                    }
                } else {
                    items(pendingTasks, key = StudyTask::id) { task ->
                        PlannerTaskCard(
                            task = task,
                            onToggle = { onToggleTask(task) },
                            onEdit = { editingTask = task; showTaskEditor = true },
                            onDelete = { deletingTask = task },
                        )
                    }
                }
                item {
                    Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                        Text("دسترسی سریع", style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.SemiBold)
                        Row(
                            modifier = Modifier.fillMaxWidth(),
                            horizontalArrangement = Arrangement.spacedBy(10.dp),
                        ) {
                            Button(onClick = onPlanner, modifier = Modifier.weight(1f)) { Text("برنامه‌ریزی درسی") }
                            OutlinedButton(onClick = onExams, modifier = Modifier.weight(1f)) { Text("پاسخ‌برگ آزمون") }
                        }
                    }
                }
            }
        }
    }

    if (showTaskEditor) {
        TaskEditorDialog(
            task = editingTask,
            initialDueDate = LocalDate.now(),
            onDismiss = { showTaskEditor = false },
            onSave = { task ->
                onSaveTask(task) { result ->
                    scope.launch { snackbar.showSnackbar(result.toUserMessage()) }
                    if (result is PlannerActionResult.Success) showTaskEditor = false
                }
            },
        )
    }

    deletingTask?.let { task ->
        AlertDialog(
            onDismissRequest = { deletingTask = null },
            title = { Text("حذف وظیفه") },
            text = { Text("آیا از حذف «${task.title}» مطمئن هستی؟") },
            confirmButton = {
                TextButton(
                    onClick = {
                        deletingTask = null
                        onDeleteTask(task.id) { result ->
                            scope.launch { snackbar.showSnackbar(result.toUserMessage()) }
                        }
                    },
                ) { Text("حذف", color = MaterialTheme.colorScheme.error) }
            },
            dismissButton = { TextButton(onClick = { deletingTask = null }) { Text("انصراف") } },
        )
    }
}

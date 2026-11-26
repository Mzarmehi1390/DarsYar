package com.mzarmehi1390.darsyar.features.dashboard.presentation

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.Checkbox
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.mzarmehi1390.darsyar.features.planner.domain.models.StudyTask
import com.mzarmehi1390.darsyar.features.planner.presentation.PlannerUiState

@Composable
fun DashboardScreen(
    state: PlannerUiState,
    onPlanner: () -> Unit,
    onExams: () -> Unit,
    onSettings: () -> Unit,
    onToggleTask: (StudyTask) -> Unit,
) {
    val tasks = state.tasks
    val errorMessage = state.errorMessage
    val completedCount = tasks.count(StudyTask::done)
    val pendingTasks = tasks.asSequence().filterNot(StudyTask::done).take(3).toList()
    val progress = if (tasks.isEmpty()) 0f else completedCount.toFloat() / tasks.size

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
                    Text("پیشرفت کارها", style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.SemiBold)
                    Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween, verticalAlignment = Alignment.CenterVertically) {
                        Text("$completedCount از ${tasks.size} کار انجام‌شده")
                        Text(if (tasks.isEmpty()) "—" else "${(progress * 100).toInt()}٪", color = MaterialTheme.colorScheme.primary, fontWeight = FontWeight.Bold)
                    }
                    LinearProgressIndicator(progress = { progress }, modifier = Modifier.fillMaxWidth())
                    when {
                        state.isLoading -> Text("در حال دریافت اطلاعات…", color = MaterialTheme.colorScheme.onSurfaceVariant)
                        errorMessage != null -> Text(errorMessage, color = MaterialTheme.colorScheme.error, style = MaterialTheme.typography.bodySmall)
                        tasks.isEmpty() -> Text("هنوز کاری ثبت نکرده‌ای. از برنامه‌ریز اولین کار خودت را اضافه کن.", color = MaterialTheme.colorScheme.onSurfaceVariant)
                        else -> Text("${tasks.size - completedCount} کار باقی مانده است.", color = MaterialTheme.colorScheme.onSurfaceVariant)
                    }
                }
            }
        }
        item {
            Text("کارهای پیشِ رو", style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.SemiBold)
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
                Card(
                    modifier = Modifier.fillMaxWidth(),
                    colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant),
                ) {
                    Row(
                        modifier = Modifier.fillMaxWidth().padding(start = 12.dp, end = 16.dp, top = 8.dp, bottom = 8.dp),
                        verticalAlignment = Alignment.CenterVertically,
                    ) {
                        Checkbox(checked = task.done, onCheckedChange = { onToggleTask(task) })
                        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(4.dp)) {
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
        item {
            Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                Text("دسترسی سریع", style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.SemiBold)
                Button(onClick = onPlanner, modifier = Modifier.fillMaxWidth()) { Text("رفتن به برنامه‌ریز") }
                OutlinedButton(onClick = onExams, modifier = Modifier.fillMaxWidth()) { Text("مدیریت آزمون‌ها") }
                OutlinedButton(onClick = onSettings, modifier = Modifier.fillMaxWidth()) { Text("تنظیمات و پشتیبان‌گیری") }
            }
        }
    }
}

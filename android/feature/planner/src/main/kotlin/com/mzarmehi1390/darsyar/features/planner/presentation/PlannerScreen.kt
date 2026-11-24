package com.mzarmehi1390.darsyar.features.planner.presentation

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.DatePicker
import androidx.compose.material3.DatePickerDialog
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.SnackbarHost
import androidx.compose.material3.SnackbarHostState
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.rememberDatePickerState
import androidx.compose.runtime.Composable
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.mzarmehi1390.darsyar.features.planner.domain.models.StudyTask
import kotlinx.coroutines.launch
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneOffset
import java.util.UUID

@Composable
fun PlannerScreen(viewModel: PlannerViewModel) {
    val state by viewModel.uiState.collectAsStateWithLifecycle()
    val snackbar = remember { SnackbarHostState() }
    val scope = rememberCoroutineScope()
    var showTaskEditor by remember { mutableStateOf(false) }
    var editingTask by remember { mutableStateOf<StudyTask?>(null) }

    Scaffold(
        snackbarHost = { SnackbarHost(snackbar) },
        floatingActionButton = {
            Button(onClick = {
                editingTask = null
                showTaskEditor = true
            }) { Text("افزودن کار") }
        },
    ) { contentPadding ->
        Column(
            modifier = Modifier.fillMaxSize().padding(contentPadding).padding(horizontal = 20.dp, vertical = 16.dp),
            verticalArrangement = Arrangement.spacedBy(16.dp),
        ) {
            Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
                Text("برنامه‌ریز", style = MaterialTheme.typography.headlineMedium, fontWeight = FontWeight.Bold)
                Text("کارها و جلسات مطالعه‌ات را در یک نگاه مدیریت کن.", color = MaterialTheme.colorScheme.onSurfaceVariant)
            }
            state.errorMessage?.let { message ->
                Card(colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.errorContainer)) {
                    Text(message, modifier = Modifier.padding(12.dp), color = MaterialTheme.colorScheme.onErrorContainer)
                }
            }
            if (state.isLoading) {
                Column(Modifier.fillMaxWidth().weight(1f), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.Center) {
                    CircularProgressIndicator()
                }
            } else {
                LazyColumn(modifier = Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(10.dp)) {
                    item { SectionHeading(title = "کارهای من", detail = "${state.tasks.count { !it.done }} کار باقی‌مانده") }
                    if (state.tasks.isEmpty()) {
                        item { EmptyPlannerCard("هنوز کاری ثبت نکرده‌ای. با دکمهٔ افزودن کار شروع کن.") }
                    } else {
                        items(state.tasks, key = { it.id }) { task ->
                            TaskCard(
                                task = task,
                                onToggle = {
                                    viewModel.toggleTask(task) { result ->
                                        if (result !is PlannerActionResult.Success) scope.launch { snackbar.showSnackbar(result.toMessage()) }
                                    }
                                },
                                onEdit = {
                                    editingTask = task
                                    showTaskEditor = true
                                },
                                onDelete = {
                                    viewModel.deleteTask(task.id) { result ->
                                        if (result !is PlannerActionResult.Success) scope.launch { snackbar.showSnackbar(result.toMessage()) }
                                    }
                                },
                            )
                        }
                    }
                    item { SectionHeading(title = "جلسات مطالعه", detail = "${state.sessions.size} جلسهٔ برنامه‌ریزی‌شده") }
                    if (state.sessions.isEmpty()) {
                        item { EmptyPlannerCard("جلسه‌ای برای نمایش وجود ندارد.") }
                    } else {
                        items(state.sessions.sortedWith(compareBy({ it.weekday }, { it.startMinutes })), key = { it.id }) { session ->
                            Card {
                                Row(Modifier.fillMaxWidth().padding(14.dp), verticalAlignment = Alignment.CenterVertically) {
                                    Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(3.dp)) {
                                        Text(session.title, fontWeight = FontWeight.SemiBold)
                                        Text("${session.subject} · ${weekdayName(session.weekday)}", style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                                        Text("${formatTime(session.startMinutes)} · ${session.durationMinutes} دقیقه", style = MaterialTheme.typography.bodySmall)
                                    }
                                    TextButton(onClick = {
                                        viewModel.toggleSession(session) { result ->
                                            if (result !is PlannerActionResult.Success) scope.launch { snackbar.showSnackbar(result.toMessage()) }
                                        }
                                    }) { Text(if (session.completed) "انجام شد" else "انجام نشده") }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    if (showTaskEditor) {
        TaskEditorDialog(
            task = editingTask,
            onDismiss = { showTaskEditor = false },
            onSave = { task ->
                viewModel.saveTask(task) { result ->
                    scope.launch { snackbar.showSnackbar(result.toMessage()) }
                    if (result is PlannerActionResult.Success) showTaskEditor = false
                }
            },
        )
    }
}

@Composable
private fun SectionHeading(title: String, detail: String) {
    Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween, verticalAlignment = Alignment.CenterVertically) {
        Text(title, style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.Bold)
        Text(detail, style = MaterialTheme.typography.labelMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
    }
}

@Composable
private fun TaskCard(task: StudyTask, onToggle: () -> Unit, onEdit: () -> Unit, onDelete: () -> Unit) {
    Card {
        Row(Modifier.fillMaxWidth().padding(horizontal = 14.dp, vertical = 10.dp), verticalAlignment = Alignment.CenterVertically) {
            Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(3.dp)) {
                Text(task.title, fontWeight = FontWeight.SemiBold, color = if (task.done) MaterialTheme.colorScheme.onSurfaceVariant else MaterialTheme.colorScheme.onSurface)
                Text(task.subject, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                Text(task.dueDate?.let { "سررسید: ${formatDueDate(it)}" } ?: "بدون تاریخ سررسید", style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
            }
            TextButton(onClick = onEdit) { Text("ویرایش") }
            TextButton(onClick = onToggle) { Text(if (task.done) "بازگردانی" else "انجام شد") }
            TextButton(onClick = onDelete) { Text("حذف", color = MaterialTheme.colorScheme.error) }
        }
    }
}

@Composable
private fun EmptyPlannerCard(message: String) {
    Card(colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant)) {
        Text(message, modifier = Modifier.fillMaxWidth().padding(16.dp), color = MaterialTheme.colorScheme.onSurfaceVariant)
    }
}

@Composable
private fun TaskEditorDialog(task: StudyTask?, onDismiss: () -> Unit, onSave: (StudyTask) -> Unit) {
    var title by remember(task?.id) { mutableStateOf(task?.title.orEmpty()) }
    var subject by remember(task?.id) { mutableStateOf(task?.subject.orEmpty()) }
    var dueDate by remember(task?.id) { mutableStateOf(task?.dueDate) }
    var showDatePicker by remember { mutableStateOf(false) }
    val pickerState = rememberDatePickerState(
        initialSelectedDateMillis = dueDate?.let { date ->
            runCatching { LocalDate.parse(date).atStartOfDay(ZoneOffset.UTC).toInstant().toEpochMilli() }.getOrNull()
        },
    )

    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text(if (task == null) "کار جدید" else "ویرایش کار") },
        text = {
            Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                OutlinedTextField(value = title, onValueChange = { title = it }, label = { Text("عنوان کار") }, singleLine = true)
                OutlinedTextField(value = subject, onValueChange = { subject = it }, label = { Text("درس") }, singleLine = true)
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Column(Modifier.weight(1f)) {
                        Text("تاریخ سررسید", style = MaterialTheme.typography.labelLarge)
                        Text(dueDate?.let(::formatDueDate) ?: "تاریخی انتخاب نشده", style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                    }
                    TextButton(onClick = { showDatePicker = true }) { Text("انتخاب تاریخ") }
                    if (dueDate != null) TextButton(onClick = { dueDate = null }) { Text("پاک‌کردن") }
                }
            }
        },
        confirmButton = {
            Button(
                onClick = {
                    onSave(StudyTask(
                        id = task?.id ?: UUID.randomUUID().toString(),
                        title = title.trim(),
                        subject = subject.trim(),
                        done = task?.done ?: false,
                        dueDate = dueDate,
                    ))
                },
                enabled = title.isNotBlank() && subject.isNotBlank(),
            ) { Text("ذخیره") }
        },
        dismissButton = { TextButton(onClick = onDismiss) { Text("انصراف") } },
    )

    if (showDatePicker) {
        DatePickerDialog(
            onDismissRequest = { showDatePicker = false },
            confirmButton = {
                TextButton(onClick = {
                    dueDate = pickerState.selectedDateMillis?.let { millis ->
                        Instant.ofEpochMilli(millis).atZone(ZoneOffset.UTC).toLocalDate().toString()
                    }
                    showDatePicker = false
                }, enabled = pickerState.selectedDateMillis != null) { Text("تأیید") }
            },
            dismissButton = { TextButton(onClick = { showDatePicker = false }) { Text("انصراف") } },
        ) { DatePicker(state = pickerState) }
    }
}

private fun weekdayName(day: Int): String = listOf("یکشنبه", "دوشنبه", "سه‌شنبه", "چهارشنبه", "پنجشنبه", "جمعه", "شنبه").getOrElse(day) { "روز نامشخص" }
private fun formatTime(minutes: Int): String = "%02d:%02d".format(minutes / 60, minutes % 60)
private fun formatDueDate(value: String): String = runCatching {
    val date = LocalDate.parse(value)
    "%04d/%02d/%02d".format(date.year, date.monthValue, date.dayOfMonth)
}.getOrDefault(value)

private fun PlannerActionResult.toMessage(): String = when (this) {
    PlannerActionResult.Success -> "عملیات با موفقیت انجام شد"
    is PlannerActionResult.Invalid -> reason
    is PlannerActionResult.Failure -> cause.message ?: "عملیات ناموفق بود"
}

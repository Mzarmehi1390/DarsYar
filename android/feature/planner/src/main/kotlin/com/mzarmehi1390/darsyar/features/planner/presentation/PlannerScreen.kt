package com.mzarmehi1390.darsyar.features.planner.presentation

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.DatePicker
import androidx.compose.material3.DatePickerDialog
import androidx.compose.material3.FilterChip
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
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
import androidx.compose.runtime.key
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.mzarmehi1390.darsyar.core.designsystem.darsYarAnimateContentSize
import com.mzarmehi1390.darsyar.features.planner.domain.PlannerCalendar
import com.mzarmehi1390.darsyar.features.planner.domain.PlannerSummary
import com.mzarmehi1390.darsyar.features.planner.domain.models.StudySession
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
    var showSessionEditor by remember { mutableStateOf(false) }
    var showWeekCopyConfirmation by remember { mutableStateOf(false) }
    var isCopyingWeek by remember { mutableStateOf(false) }
    var editingSession by remember { mutableStateOf<StudySession?>(null) }
    var weekStart by remember { mutableStateOf(PlannerCalendar.startOfWeek(LocalDate.now())) }
    var selectedDate by remember { mutableStateOf(LocalDate.now()) }
    val weekDates = remember(weekStart) { PlannerCalendar.days(weekStart) }
    val weeklySessions = state.sessions.filter { session ->
        val date = PlannerCalendar.parseDateKey(session.scheduledDate)
        date == null || PlannerCalendar.isInWeek(date, weekStart)
    }
    val weeklySummary = remember(weeklySessions) { PlannerSummary.fromSessions(weeklySessions) }
    val selectedDaySessions = state.sessions.filter { session ->
        val date = PlannerCalendar.parseDateKey(session.scheduledDate)
        if (date != null) date == selectedDate
        else session.weekday == PlannerCalendar.weekdayForDate(selectedDate)
    }.sortedBy(StudySession::startMinutes)

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
                Card(modifier = Modifier.darsYarAnimateContentSize(), colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.errorContainer)) {
                    Text(message, modifier = Modifier.padding(12.dp), color = MaterialTheme.colorScheme.onErrorContainer)
                }
            }
            if (state.isLoading) {
                Column(Modifier.fillMaxWidth().weight(1f), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.Center) {
                    CircularProgressIndicator()
                }
            } else {
                LazyColumn(modifier = Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(10.dp)) {
                    item {
                        Row(
                            modifier = Modifier.fillMaxWidth(),
                            horizontalArrangement = Arrangement.SpaceBetween,
                            verticalAlignment = Alignment.CenterVertically,
                        ) {
                            TextButton(onClick = {
                                weekStart = weekStart.minusDays(7)
                                selectedDate = weekStart
                            }) { Text("هفتهٔ قبل") }
                            Column(horizontalAlignment = Alignment.CenterHorizontally) {
                                Text("نمای هفتگی", fontWeight = FontWeight.Bold)
                                Text(
                                    "${formatDueDate(weekStart.toString())} تا ${formatDueDate(weekStart.plusDays(6).toString())}",
                                    style = MaterialTheme.typography.labelSmall,
                                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                                )
                            }
                            TextButton(onClick = {
                                weekStart = weekStart.plusDays(7)
                                selectedDate = weekStart
                            }) { Text("هفتهٔ بعد") }
                        }
                    }
                    item {
                        val datedSessionCount = weeklySessions.count { it.scheduledDate != null }
                        val datedTaskCount = state.tasks.count { task ->
                            PlannerCalendar.parseDateKey(task.dueDate)?.let { PlannerCalendar.isInWeek(it, weekStart) } == true
                        }
                        TextButton(
                            enabled = !isCopyingWeek && datedSessionCount + datedTaskCount > 0,
                            onClick = { showWeekCopyConfirmation = true },
                        ) { Text(if (isCopyingWeek) "در حال کپی…" else "کپی برنامه به هفتهٔ بعد") }
                    }
                    item {
                        LazyRow(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                            items(weekDates, key = { it.toString() }) { date ->
                                val day = PlannerCalendar.weekdayForDate(date)
                                val count = state.sessions.count { session ->
                                    val sessionDate = PlannerCalendar.parseDateKey(session.scheduledDate)
                                    if (sessionDate != null) sessionDate == date else session.weekday == day
                                }
                                FilterChip(
                                    selected = selectedDate == date,
                                    onClick = { selectedDate = date },
                                    label = {
                                        Column(horizontalAlignment = Alignment.CenterHorizontally) {
                                            Text(weekdayName(day))
                                            Text("${date.dayOfMonth} · ${count} جلسه", style = MaterialTheme.typography.labelSmall)
                                        }
                                    },
                                )
                            }
                        }
                    }
                    item { WeeklyPlannerReport(summary = weeklySummary) }
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
                    item {
                        Row(
                            modifier = Modifier.fillMaxWidth(),
                            horizontalArrangement = Arrangement.SpaceBetween,
                            verticalAlignment = Alignment.CenterVertically,
                        ) {
                            Column(modifier = Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
                                Text(
                                    weekdayName(PlannerCalendar.weekdayForDate(selectedDate)),
                                    style = MaterialTheme.typography.titleLarge,
                                    fontWeight = FontWeight.Bold,
                                )
                                Text(
                                    formatDueDate(selectedDate.toString()),
                                    style = MaterialTheme.typography.labelMedium,
                                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                                )
                            }
                            TextButton(onClick = {
                                editingSession = null
                                showSessionEditor = true
                            }) { Text("افزودن جلسه") }
                        }
                    }
                    if (selectedDaySessions.isEmpty()) {
                        item { EmptyPlannerCard("برای این روز جلسه‌ای ثبت نشده است. از «افزودن جلسه» برنامه‌ریزی کن.") }
                    } else {
                        items(selectedDaySessions, key = { it.id }) { session ->
                            SessionCard(
                                session = session,
                                onToggle = {
                                    viewModel.toggleSession(session) { result ->
                                        if (result !is PlannerActionResult.Success) scope.launch { snackbar.showSnackbar(result.toMessage()) }
                                    }
                                },
                                onEdit = {
                                    editingSession = session
                                    showSessionEditor = true
                                },
                                onDelete = {
                                    viewModel.deleteSession(session.id) { result ->
                                        scope.launch { snackbar.showSnackbar(result.toMessage()) }
                                    }
                                },
                            )
                        }
                    }
                }
            }
        }
    }

    if (showWeekCopyConfirmation) {
        val datedSessionCount = weeklySessions.count { it.scheduledDate != null }
        val datedTaskCount = state.tasks.count { task ->
            PlannerCalendar.parseDateKey(task.dueDate)?.let { PlannerCalendar.isInWeek(it, weekStart) } == true
        }
        AlertDialog(
            onDismissRequest = { if (!isCopyingWeek) showWeekCopyConfirmation = false },
            title = { Text("کپی برنامهٔ هفتگی") },
            text = {
                Text(
                    "$datedSessionCount جلسه و $datedTaskCount کار به هفتهٔ " +
                        "${formatDueDate(weekStart.plusDays(7).toString())} کپی می‌شود. " +
                        "وضعیت انجام‌شدن در نسخهٔ جدید بازنشانی می‌شود و برنامهٔ موجود هفتهٔ مقصد جایگزین نخواهد شد."
                )
            },
            confirmButton = {
                Button(
                    enabled = !isCopyingWeek,
                    onClick = {
                        isCopyingWeek = true
                        showWeekCopyConfirmation = false
                        viewModel.copyWeekToNext(weekStart) { result ->
                            isCopyingWeek = false
                            scope.launch { snackbar.showSnackbar(result.toMessage()) }
                            if (result == PlannerActionResult.Success) {
                                weekStart = weekStart.plusDays(7)
                                selectedDate = weekStart
                            }
                        }
                    },
                ) { Text("تأیید کپی") }
            },
            dismissButton = {
                TextButton(enabled = !isCopyingWeek, onClick = { showWeekCopyConfirmation = false }) {
                    Text("انصراف")
                }
            },
        )
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

    if (showSessionEditor) {
        SessionEditorDialog(
            session = editingSession,
            onDismiss = { showSessionEditor = false },
            onSave = { session ->
                viewModel.saveSession(session) { result ->
                    scope.launch { snackbar.showSnackbar(result.toMessage()) }
                    if (result is PlannerActionResult.Success) showSessionEditor = false
                }
            },
        )
    }
}

@Composable
private fun WeeklyPlannerReport(summary: PlannerSummary) {
    val progress = summary.completion.toFloat().coerceIn(0f, 1f)
    Card(
        modifier = Modifier.fillMaxWidth().darsYarAnimateContentSize(),
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.secondaryContainer),
    ) {
        Column(
            Modifier.fillMaxWidth().padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            Text("گزارش هفتگی مطالعه", style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.Bold)
            Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                WeeklyMetric("برنامه‌ریزی‌شده", summary.plannedMinutes, Modifier.weight(1f))
                WeeklyMetric("تکمیل‌شده", summary.completedMinutes, Modifier.weight(1f))
                Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
                    Text(if (summary.plannedMinutes == 0) "—" else "${(progress * 100).toInt()}٪", style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.Bold, color = MaterialTheme.colorScheme.primary)
                    Text("پیشرفت", style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.onSecondaryContainer)
                }
            }
            androidx.compose.material3.LinearProgressIndicator(
                progress = progress,
                modifier = Modifier.fillMaxWidth(),
                color = MaterialTheme.colorScheme.primary,
                trackColor = MaterialTheme.colorScheme.surfaceVariant,
            )
            Text(
                if (summary.totalSessionCount == 0) "برای دیدن گزارش، جلسهٔ مطالعه اضافه کن."
                else "${summary.completedSessionCount} از ${summary.totalSessionCount} جلسه تکمیل شده است.",
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSecondaryContainer,
            )
        }
    }
}

@Composable
private fun WeeklyMetric(label: String, minutes: Int, modifier: Modifier = Modifier) {
    Column(modifier, verticalArrangement = Arrangement.spacedBy(2.dp)) {
        Text(minutes.toString(), style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.Bold, color = MaterialTheme.colorScheme.primary)
        Text("دقیقه", style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.onSecondaryContainer)
        Text(label, style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.onSecondaryContainer)
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
    var actionsExpanded by remember(task.id) { mutableStateOf(false) }
    Card(modifier = Modifier.darsYarAnimateContentSize()) {
        Row(Modifier.fillMaxWidth().padding(horizontal = 14.dp, vertical = 10.dp), verticalAlignment = Alignment.CenterVertically) {
            Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(3.dp)) {
                Text(task.title, fontWeight = FontWeight.SemiBold, color = if (task.done) MaterialTheme.colorScheme.onSurfaceVariant else MaterialTheme.colorScheme.onSurface)
                Text(task.subject, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                Text(task.dueDate?.let { "سررسید: ${formatDueDate(it)}" } ?: "بدون تاریخ سررسید", style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
            }
            Column(horizontalAlignment = Alignment.End) {
                TextButton(onClick = { actionsExpanded = true }) { Text("عملیات") }
                DropdownMenu(expanded = actionsExpanded, onDismissRequest = { actionsExpanded = false }) {
                    DropdownMenuItem(text = { Text("ویرایش") }, onClick = { actionsExpanded = false; onEdit() })
                    DropdownMenuItem(text = { Text(if (task.done) "بازگردانی" else "انجام شد") }, onClick = { actionsExpanded = false; onToggle() })
                    DropdownMenuItem(text = { Text("حذف", color = MaterialTheme.colorScheme.error) }, onClick = { actionsExpanded = false; onDelete() })
                }
            }
        }
    }
}

@Composable
private fun SessionCard(
    session: StudySession,
    onToggle: () -> Unit,
    onEdit: () -> Unit,
    onDelete: () -> Unit,
) {
    var actionsExpanded by remember(session.id) { mutableStateOf(false) }
    Card(modifier = Modifier.darsYarAnimateContentSize()) {
        Row(Modifier.fillMaxWidth().padding(14.dp), verticalAlignment = Alignment.CenterVertically) {
            Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(3.dp)) {
                Text(session.title, fontWeight = FontWeight.SemiBold)
                Text(
                    "${session.subject} · ${session.scheduledDate?.let(::formatDueDate) ?: weekdayName(session.weekday)}",
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
                Text("${formatTime(session.startMinutes)} · ${session.durationMinutes} دقیقه", style = MaterialTheme.typography.bodySmall)
            }
            Column(horizontalAlignment = Alignment.End) {
                TextButton(onClick = onToggle) { Text(if (session.completed) "انجام شد" else "انجام نشده") }
                TextButton(onClick = { actionsExpanded = true }) { Text("عملیات") }
                DropdownMenu(expanded = actionsExpanded, onDismissRequest = { actionsExpanded = false }) {
                    DropdownMenuItem(text = { Text("ویرایش") }, onClick = { actionsExpanded = false; onEdit() })
                    DropdownMenuItem(text = { Text("حذف", color = MaterialTheme.colorScheme.error) }, onClick = { actionsExpanded = false; onDelete() })
                }
            }
        }
    }
}

@Composable
private fun EmptyPlannerCard(message: String) {
    Card(modifier = Modifier.darsYarAnimateContentSize(), colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant)) {
        Text(message, modifier = Modifier.fillMaxWidth().padding(16.dp), color = MaterialTheme.colorScheme.onSurfaceVariant)
    }
}

@Composable
private fun TaskEditorDialog(task: StudyTask?, onDismiss: () -> Unit, onSave: (StudyTask) -> Unit) {
    var title by remember(task?.id) { mutableStateOf(task?.title.orEmpty()) }
    var subject by remember(task?.id) { mutableStateOf(task?.subject.orEmpty()) }
    var dueDate by remember(task?.id) { mutableStateOf(task?.dueDate) }
    var showDatePicker by remember { mutableStateOf(false) }
    val pickerState = key(dueDate) {
        rememberDatePickerState(
            initialSelectedDateMillis = dueDate?.let { date ->
                runCatching { LocalDate.parse(date).atStartOfDay(ZoneOffset.UTC).toInstant().toEpochMilli() }.getOrNull()
            },
        )
    }

    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text(if (task == null) "کار جدید" else "ویرایش کار") },
        text = {
            Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                OutlinedTextField(value = title, onValueChange = { title = it }, label = { Text("عنوان کار") }, singleLine = true)
                OutlinedTextField(value = subject, onValueChange = { subject = it }, label = { Text("درس (اختیاری)") }, singleLine = true)
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
                enabled = title.isNotBlank(),
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

@Composable
private fun SessionEditorDialog(
    session: StudySession?,
    onDismiss: () -> Unit,
    onSave: (StudySession) -> Unit,
) {
    var title by remember(session?.id) { mutableStateOf(session?.title.orEmpty()) }
    var subject by remember(session?.id) { mutableStateOf(session?.subject.orEmpty()) }
    var weekday by remember(session?.id) {
        mutableStateOf(
            session?.scheduledDate?.let(PlannerCalendar::parseDateKey)?.let(PlannerCalendar::weekdayForDate)
                ?: session?.weekday
                ?: 0,
        )
    }
    var weekdayMenuExpanded by remember { mutableStateOf(false) }
    var startTime by remember(session?.id) { mutableStateOf(session?.startMinutes?.let(::formatTime) ?: "09:00") }
    var duration by remember(session?.id) { mutableStateOf(session?.durationMinutes?.toString() ?: "60") }
    var scheduledDate by remember(session?.id) { mutableStateOf(session?.scheduledDate) }
    var showDatePicker by remember { mutableStateOf(false) }
    val pickerState = key(scheduledDate) {
        rememberDatePickerState(
            initialSelectedDateMillis = scheduledDate?.let { date ->
                runCatching { LocalDate.parse(date).atStartOfDay(ZoneOffset.UTC).toInstant().toEpochMilli() }.getOrNull()
            },
        )
    }
    val parsedTime = parseTime(startTime)
    val parsedDuration = duration.toIntOrNull()
    val validTime = parsedTime != null && parsedDuration != null && parsedDuration > 0 &&
        parsedTime in 0 until 1440 && parsedDuration <= 1440 - parsedTime

    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text(if (session == null) "جلسهٔ جدید" else "ویرایش جلسه") },
        text = {
            Column(
                modifier = Modifier.fillMaxWidth().heightIn(max = 480.dp).verticalScroll(rememberScrollState()),
                verticalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                OutlinedTextField(value = title, onValueChange = { title = it }, label = { Text("عنوان جلسه") }, singleLine = true)
                OutlinedTextField(value = subject, onValueChange = { subject = it }, label = { Text("درس") }, singleLine = true)
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Column(Modifier.weight(1f)) {
                        Text("روز هفته", style = MaterialTheme.typography.labelLarge)
                        Text(weekdayName(weekday), style = MaterialTheme.typography.bodySmall)
                    }
                    TextButton(onClick = { weekdayMenuExpanded = true }) { Text("انتخاب روز") }
                    DropdownMenu(expanded = weekdayMenuExpanded, onDismissRequest = { weekdayMenuExpanded = false }) {
                        weekdayNames.forEachIndexed { index, name ->
                            DropdownMenuItem(
                                text = { Text(name) },
                                onClick = { weekday = index; weekdayMenuExpanded = false },
                            )
                        }
                    }
                }
                OutlinedTextField(
                    value = startTime,
                    onValueChange = { startTime = it.filter { char -> char.isDigit() || char == ':' }.take(5) },
                    label = { Text("زمان شروع (HH:mm)") },
                    singleLine = true,
                )
                OutlinedTextField(
                    value = duration,
                    onValueChange = { duration = it.filter(Char::isDigit).take(4) },
                    label = { Text("مدت (دقیقه)") },
                    singleLine = true,
                )
                Text(
                    scheduledDate?.let { "تاریخ مشخص: ${formatDueDate(it)}" } ?: "جلسهٔ هفتگی بر اساس روز انتخاب‌شده",
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
                Row(verticalAlignment = Alignment.CenterVertically) {
                    TextButton(onClick = { showDatePicker = true }) { Text("تعیین تاریخ") }
                    if (scheduledDate != null) TextButton(onClick = { scheduledDate = null }) { Text("حذف تاریخ") }
                }
                if (startTime.isNotBlank() && !validTime) {
                    Text("زمان یا مدت جلسه معتبر نیست.", color = MaterialTheme.colorScheme.error, style = MaterialTheme.typography.bodySmall)
                }
            }
        },
        confirmButton = {
            Button(
                enabled = title.isNotBlank() && subject.isNotBlank() && validTime,
                onClick = {
                    onSave(
                        StudySession(
                            id = session?.id ?: UUID.randomUUID().toString(),
                            title = title.trim(),
                            subject = subject.trim(),
                            weekday = weekday,
                            startMinutes = parsedTime!!,
                            durationMinutes = parsedDuration!!,
                            completed = session?.completed ?: false,
                            scheduledDate = scheduledDate,
                        ),
                    )
                },
            ) { Text("ذخیره") }
        },
        dismissButton = { TextButton(onClick = onDismiss) { Text("انصراف") } },
    )

    if (showDatePicker) {
        DatePickerDialog(
            onDismissRequest = { showDatePicker = false },
            confirmButton = {
                TextButton(
                    onClick = {
                        scheduledDate = pickerState.selectedDateMillis?.let { millis ->
                            Instant.ofEpochMilli(millis).atZone(ZoneOffset.UTC).toLocalDate().toString()
                        }
                        scheduledDate?.let(PlannerCalendar::parseDateKey)?.let(PlannerCalendar::weekdayForDate)?.let {
                            weekday = it
                        }
                        showDatePicker = false
                    },
                    enabled = pickerState.selectedDateMillis != null,
                ) { Text("تأیید") }
            },
            dismissButton = { TextButton(onClick = { showDatePicker = false }) { Text("انصراف") } },
        ) { DatePicker(state = pickerState) }
    }
}

private val weekdayNames = listOf("یکشنبه", "دوشنبه", "سه‌شنبه", "چهارشنبه", "پنجشنبه", "جمعه", "شنبه")
private fun weekdayName(day: Int): String = weekdayNames.getOrElse(day) { "روز نامشخص" }
private fun formatTime(minutes: Int): String = "%02d:%02d".format(minutes / 60, minutes % 60)
private fun parseTime(value: String): Int? {
    val parts = value.split(":")
    if (parts.size != 2) return null
    val hour = parts[0].toIntOrNull() ?: return null
    val minute = parts[1].toIntOrNull() ?: return null
    if (hour !in 0..23 || minute !in 0..59) return null
    return hour * 60 + minute
}
private fun formatDueDate(value: String): String = runCatching {
    val date = LocalDate.parse(value)
    "%04d/%02d/%02d".format(date.year, date.monthValue, date.dayOfMonth)
}.getOrDefault(value)

private fun PlannerActionResult.toMessage(): String = when (this) {
    PlannerActionResult.Success -> "عملیات با موفقیت انجام شد"
    is PlannerActionResult.Invalid -> reason
    is PlannerActionResult.Failure -> cause.message ?: "عملیات ناموفق بود"
}

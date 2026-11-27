package com.mzarmehi1390.darsyar.features.planner.presentation

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.DatePicker
import androidx.compose.material3.DatePickerDialog
import androidx.compose.material3.rememberDatePickerState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.key
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextDecoration
import androidx.compose.ui.unit.dp
import com.mzarmehi1390.darsyar.core.common.JalaliDate
import com.mzarmehi1390.darsyar.core.common.PersianDigits
import com.mzarmehi1390.darsyar.core.designsystem.darsYarAnimateContentSize
import com.mzarmehi1390.darsyar.features.planner.domain.models.StudyTask
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneOffset
import java.util.UUID

@Composable
fun PlannerTaskCard(task: StudyTask, onToggle: () -> Unit, onEdit: () -> Unit, onDelete: () -> Unit) {
    var actionsExpanded by remember(task.id) { mutableStateOf(false) }
    Card(modifier = Modifier.darsYarAnimateContentSize()) {
        Row(
            Modifier.fillMaxWidth().padding(horizontal = 14.dp, vertical = 10.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(3.dp)) {
                Text(
                    task.title,
                    fontWeight = FontWeight.SemiBold,
                    textDecoration = if (task.done) TextDecoration.LineThrough else null,
                    color = if (task.done) MaterialTheme.colorScheme.onSurfaceVariant else MaterialTheme.colorScheme.onSurface,
                )
                Text(task.subject, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                Text(
                    task.dueDate?.let { "سررسید: ${formatTaskDueDate(it)}" } ?: "بدون تاریخ سررسید",
                    style = MaterialTheme.typography.labelSmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
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
fun TaskEditorDialog(task: StudyTask?, initialDueDate: LocalDate, onDismiss: () -> Unit, onSave: (StudyTask) -> Unit) {
    var title by remember(task?.id) { mutableStateOf(task?.title.orEmpty()) }
    var subject by remember(task?.id) { mutableStateOf(task?.subject.orEmpty()) }
    var dueDate by remember(task?.id, initialDueDate) { mutableStateOf<String?>(task?.dueDate ?: initialDueDate.toString()) }
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
            Column(
                modifier = Modifier.fillMaxWidth().heightIn(max = 480.dp).verticalScroll(rememberScrollState()),
                verticalArrangement = Arrangement.spacedBy(10.dp),
            ) {
                OutlinedTextField(
                    value = title,
                    onValueChange = { title = it.take(100) },
                    label = { Text("عنوان کار") },
                    singleLine = true,
                )
                OutlinedTextField(
                    value = subject,
                    onValueChange = { subject = it.take(50) },
                    label = { Text("درس (اختیاری)") },
                    singleLine = true,
                )
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Column(Modifier.weight(1f)) {
                        Text("تاریخ سررسید", style = MaterialTheme.typography.labelLarge)
                        Text(
                            dueDate?.let(::formatTaskDueDate) ?: "تاریخی انتخاب نشده",
                            style = MaterialTheme.typography.bodySmall,
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                        )
                    }
                    TextButton(onClick = { showDatePicker = true }) { Text("انتخاب تاریخ") }
                    if (dueDate != null) TextButton(onClick = { dueDate = null }) { Text("پاک‌کردن") }
                }
            }
        },
        confirmButton = {
            Button(
                onClick = {
                    onSave(
                        StudyTask(
                            id = task?.id ?: UUID.randomUUID().toString(),
                            title = title.trim(),
                            subject = subject.trim(),
                            done = task?.done ?: false,
                            dueDate = dueDate,
                        ),
                    )
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
                TextButton(
                    onClick = {
                        dueDate = pickerState.selectedDateMillis?.let { millis ->
                            Instant.ofEpochMilli(millis).atZone(ZoneOffset.UTC).toLocalDate().toString()
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

private fun formatTaskDueDate(value: String): String =
    PersianDigits.toPersianDigits(JalaliDate.formatIsoDateKey(value))

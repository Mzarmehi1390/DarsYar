package com.mzarmehi1390.darsyar.features.exams.presentation

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
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.SnackbarHost
import androidx.compose.material3.SnackbarHostState
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.mzarmehi1390.darsyar.features.exams.domain.models.ExamSheet
import kotlinx.coroutines.launch
import java.util.UUID

@Composable
fun ExamsScreen(viewModel: ExamViewModel) {
    val state by viewModel.uiState.collectAsState()
    val snackbar = remember { SnackbarHostState() }
    val scope = rememberCoroutineScope()
    var showAddSheet by remember { mutableStateOf(false) }

    Scaffold(
        snackbarHost = { SnackbarHost(snackbar) },
        floatingActionButton = {
            Button(onClick = { showAddSheet = true }) { Text("برگهٔ جدید") }
        },
    ) { contentPadding ->
        Column(
            modifier = Modifier.fillMaxSize().padding(contentPadding).padding(horizontal = 20.dp, vertical = 16.dp),
            verticalArrangement = Arrangement.spacedBy(16.dp),
        ) {
            Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
                Text("آزمون‌ها", style = MaterialTheme.typography.headlineMedium, fontWeight = FontWeight.Bold)
                Text("برگه‌ها را مدیریت کن و نتیجهٔ آزمون‌هایت را نگه دار.", color = MaterialTheme.colorScheme.onSurfaceVariant)
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
                LazyColumn(
                    modifier = Modifier.weight(1f),
                    verticalArrangement = Arrangement.spacedBy(10.dp),
                ) {
                    item { Text("برگه‌های ذخیره‌شده", style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.Bold) }
                    if (state.sheets.isEmpty()) {
                        item { EmptyExamCard("هنوز برگه‌ای ثبت نشده است.") }
                    } else {
                        items(state.sheets, key = { it.id }) { sheet ->
                            Card {
                                Column(Modifier.fillMaxWidth().padding(14.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                                    Text(sheet.name, style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.SemiBold)
                                    Text("${sheet.questionCount} سؤال · ${sheet.answers.size} پاسخ ثبت‌شده · ${sheet.marked.size} سؤال علامت‌دار", style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                                    Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                                        Button(onClick = {
                                            viewModel.completeExam(sheet.id) { result ->
                                                scope.launch { snackbar.showSnackbar(result.toMessage()) }
                                            }
                                        }) { Text("ثبت نتیجه") }
                                        TextButton(
                                            onClick = {
                                                viewModel.deleteSheet(sheet.id) { result ->
                                                    scope.launch { snackbar.showSnackbar(result.toMessage()) }
                                                }
                                            },
                                            enabled = state.sheets.size > 1,
                                        ) { Text("حذف", color = MaterialTheme.colorScheme.error) }
                                    }
                                }
                            }
                        }
                    }
                    item {
                        Text("تاریخچهٔ نتایج", modifier = Modifier.padding(top = 8.dp), style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.Bold)
                    }
                    if (state.results.isEmpty()) {
                        item { EmptyExamCard("پس از ثبت نتیجه، کارنامه‌ها در این بخش نمایش داده می‌شوند.") }
                    } else {
                        items(state.results.sortedByDescending { it.completedAt }, key = { it.id }) { result ->
                            Card {
                                Column(Modifier.fillMaxWidth().padding(14.dp), verticalArrangement = Arrangement.spacedBy(4.dp)) {
                                    Text(result.examName, fontWeight = FontWeight.SemiBold)
                                    Text("${result.correct} درست · ${result.wrong} نادرست · ${result.unanswered} بی‌پاسخ", style = MaterialTheme.typography.bodySmall)
                                    Text(
                                        result.percentage?.let { "درصد: %.1f٪".format(it) } ?: "درصد قابل محاسبه نیست",
                                        color = MaterialTheme.colorScheme.primary,
                                        fontWeight = FontWeight.Bold,
                                    )
                                    Text(result.completedAt, style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    if (showAddSheet) {
        AddExamSheetDialog(
            onDismiss = { showAddSheet = false },
            onSave = { name, count ->
                viewModel.saveSheet(
                    ExamSheet(
                        id = UUID.randomUUID().toString(),
                        name = name.trim(),
                        questionCount = count,
                    ),
                ) { result ->
                    scope.launch { snackbar.showSnackbar(result.toMessage()) }
                }
                showAddSheet = false
            },
        )
    }
}

@Composable
private fun EmptyExamCard(message: String) {
    Card(colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant)) {
        Text(message, modifier = Modifier.fillMaxWidth().padding(16.dp), color = MaterialTheme.colorScheme.onSurfaceVariant)
    }
}

@Composable
private fun AddExamSheetDialog(onDismiss: () -> Unit, onSave: (String, Int) -> Unit) {
    var name by remember { mutableStateOf("") }
    var count by remember { mutableStateOf("20") }
    val parsedCount = count.toIntOrNull()
    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text("برگهٔ آزمون جدید") },
        text = {
            Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                OutlinedTextField(value = name, onValueChange = { name = it }, label = { Text("نام آزمون") }, singleLine = true)
                OutlinedTextField(value = count, onValueChange = { count = it.filter(Char::isDigit).take(3) }, label = { Text("تعداد سؤال") }, singleLine = true)
            }
        },
        confirmButton = {
            Button(onClick = { onSave(name, parsedCount ?: 0) }, enabled = name.isNotBlank() && parsedCount != null && parsedCount in 1..200) {
                Text("ذخیره")
            }
        },
        dismissButton = { TextButton(onClick = onDismiss) { Text("انصراف") } },
    )
}

private fun ExamActionResult.toMessage(): String = when (this) {
    ExamActionResult.Success -> "عملیات با موفقیت انجام شد"
    is ExamActionResult.Completed -> "نتیجهٔ آزمون ثبت شد"
    ExamActionResult.SheetNotFound -> "برگهٔ آزمون پیدا نشد"
    ExamActionResult.CannotDeleteLastSheet -> "آخرین برگهٔ آزمون قابل حذف نیست"
    is ExamActionResult.Invalid -> reason
    is ExamActionResult.Failure -> cause.message ?: "عملیات ناموفق بود"
}

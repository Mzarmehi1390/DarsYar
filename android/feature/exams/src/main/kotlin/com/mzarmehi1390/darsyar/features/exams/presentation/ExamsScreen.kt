package com.mzarmehi1390.darsyar.features.exams.presentation

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.lazy.LazyRow
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
import androidx.compose.material3.Checkbox
import androidx.compose.material3.RadioButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.SnackbarHost
import androidx.compose.material3.SnackbarHostState
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
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
import com.mzarmehi1390.darsyar.features.exams.domain.models.ExamSheet
import kotlinx.coroutines.launch
import java.util.UUID

@Composable
fun ExamsScreen(viewModel: ExamViewModel) {
    val state by viewModel.uiState.collectAsStateWithLifecycle()
    val snackbar = remember { SnackbarHostState() }
    val scope = rememberCoroutineScope()
    var showAddSheet by remember { mutableStateOf(false) }
    var takingSheet by remember { mutableStateOf<ExamSheet?>(null) }
    var answerKeySheet by remember { mutableStateOf<ExamSheet?>(null) }

    LaunchedEffect(state.activeExamId, state.isLoading) {
        val activeId = state.activeExamId
        if (!state.isLoading && activeId != null && takingSheet == null) {
            val activeSheet = state.sheets.firstOrNull { it.id == activeId }
            if (activeSheet == null) {
                viewModel.clearActiveExam(activeId)
            } else {
                takingSheet = activeSheet
            }
        }
    }

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
                    item {
                        state.activeExamId?.let { activeId ->
                            state.sheets.firstOrNull { it.id == activeId }?.let { activeSheet ->
                                Card(colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.primaryContainer)) {
                                    Column(Modifier.fillMaxWidth().padding(14.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
                                        Text("آزمون فعال", style = MaterialTheme.typography.labelLarge, color = MaterialTheme.colorScheme.onPrimaryContainer)
                                        Text(activeSheet.name, style = MaterialTheme.typography.titleMedium, color = MaterialTheme.colorScheme.onPrimaryContainer, fontWeight = FontWeight.Bold)
                                        Text("پاسخ‌های ثبت‌شده محفوظ‌اند؛ می‌توانی ادامه بدهی.", style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onPrimaryContainer)
                                        Button(onClick = { takingSheet = activeSheet }) { Text("بازگشت به آزمون") }
                                    }
                                }
                            }
                        }
                    }
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
                                            viewModel.startExam(sheet.id) { result ->
                                                if (result == ExamActionResult.Success) {
                                                    takingSheet = state.sheets.firstOrNull { it.id == sheet.id } ?: sheet
                                                } else {
                                                    scope.launch { snackbar.showSnackbar(result.toMessage()) }
                                                }
                                            }
                                        }) { Text(if (sheet.answers.isEmpty()) "شروع آزمون" else "ادامه آزمون") }
                                        TextButton(onClick = { answerKeySheet = sheet }) { Text("کلید پاسخ") }
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

    answerKeySheet?.let { sheet ->
        AnswerKeyDialog(
            sheet = sheet,
            onDismiss = { answerKeySheet = null },
            onSave = { updated ->
                viewModel.saveSheet(updated) { result ->
                    scope.launch { snackbar.showSnackbar(result.toMessage()) }
                }
                answerKeySheet = null
            },
        )
    }

    takingSheet?.let { sheet ->
        ExamTakingDialog(
            sheet = sheet,
            onDismiss = { takingSheet = null },
            onDraftChanged = { updated -> viewModel.saveSheet(updated) },
            onFinish = { updated ->
                viewModel.saveSheet(updated) { saveResult ->
                    if (saveResult == ExamActionResult.Success) {
                        viewModel.completeExam(updated.id) { result ->
                            scope.launch { snackbar.showSnackbar(result.toMessage()) }
                        }
                        takingSheet = null
                    } else {
                        scope.launch { snackbar.showSnackbar(saveResult.toMessage()) }
                    }
                }
            },
        )
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


@Composable
private fun ExamTakingDialog(
    sheet: ExamSheet,
    onDismiss: () -> Unit,
    onDraftChanged: (ExamSheet) -> Unit,
    onFinish: (ExamSheet) -> Unit,
) {
    var currentQuestion by remember(sheet.id) { mutableStateOf(1) }
    var answers by remember(sheet.id) { mutableStateOf(sheet.answers) }
    var marked by remember(sheet.id) { mutableStateOf(sheet.marked) }
    var showFinishConfirmation by remember { mutableStateOf(false) }

    val updatedSheet = sheet.copy(answers = answers, marked = marked)
    val answeredCount = answers.size
    val unansweredCount = (sheet.questionCount - answeredCount).coerceAtLeast(0)

    AlertDialog(
        onDismissRequest = onDismiss,
        title = {
            Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
                Text(sheet.name, style = MaterialTheme.typography.titleLarge)
                Text(
                    "${answeredCount} پاسخ ثبت‌شده · ${unansweredCount} بی‌پاسخ · ${marked.size} علامت‌دار",
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
        },
        text = {
            Column(
                modifier = Modifier.fillMaxWidth().heightIn(max = 520.dp),
                verticalArrangement = Arrangement.spacedBy(14.dp),
            ) {
                Text("انتخاب شمارهٔ سؤال", style = MaterialTheme.typography.labelLarge)
                LazyRow(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                    items(sheet.questionCount) { index ->
                        val number = index + 1
                        val isAnswered = answers.containsKey(number)
                        val isMarked = number in marked
                        val container = when {
                            number == currentQuestion -> MaterialTheme.colorScheme.primary
                            isMarked -> MaterialTheme.colorScheme.tertiaryContainer
                            isAnswered -> MaterialTheme.colorScheme.secondaryContainer
                            else -> MaterialTheme.colorScheme.surfaceVariant
                        }
                        val content = when {
                            number == currentQuestion -> MaterialTheme.colorScheme.onPrimary
                            isMarked -> MaterialTheme.colorScheme.onTertiaryContainer
                            isAnswered -> MaterialTheme.colorScheme.onSecondaryContainer
                            else -> MaterialTheme.colorScheme.onSurfaceVariant
                        }
                        androidx.compose.material3.FilledTonalButton(
                            onClick = { currentQuestion = number },
                            colors = androidx.compose.material3.ButtonDefaults.filledTonalButtonColors(
                                containerColor = container,
                                contentColor = content,
                            ),
                            contentPadding = androidx.compose.foundation.layout.PaddingValues(horizontal = 12.dp, vertical = 8.dp),
                        ) { Text(number.toString()) }
                    }
                }

                Card(colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant)) {
                    Column(
                        modifier = Modifier.fillMaxWidth().padding(14.dp),
                        verticalArrangement = Arrangement.spacedBy(10.dp),
                    ) {
                        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.SpaceBetween) {
                            Text("سؤال $currentQuestion از ${sheet.questionCount}", fontWeight = FontWeight.Bold)
                            TextButton(onClick = {
                                marked = if (currentQuestion in marked) marked - currentQuestion else marked + currentQuestion
                                onDraftChanged(sheet.copy(answers = answers, marked = marked))
                            }) {
                                Text(if (currentQuestion in marked) "حذف علامت" else "علامت برای بازگشت")
                            }
                        }
                        (0..3).forEach { option ->
                            val selected = answers[currentQuestion] == option
                            androidx.compose.material3.OutlinedButton(
                                onClick = {
                                    answers = answers + (currentQuestion to option)
                                    onDraftChanged(sheet.copy(answers = answers, marked = marked))
                                },
                                modifier = Modifier.fillMaxWidth(),
                                colors = androidx.compose.material3.ButtonDefaults.outlinedButtonColors(
                                    containerColor = if (selected) MaterialTheme.colorScheme.primaryContainer else MaterialTheme.colorScheme.surface,
                                    contentColor = if (selected) MaterialTheme.colorScheme.onPrimaryContainer else MaterialTheme.colorScheme.onSurface,
                                ),
                            ) {
                                Text(
                                    text = listOf("گزینهٔ ۱", "گزینهٔ ۲", "گزینهٔ ۳", "گزینهٔ ۴")[option],
                                    modifier = Modifier.fillMaxWidth(),
                                )
                            }
                        }
                        if (currentQuestion in answers) {
                            TextButton(onClick = {
                                answers = answers - currentQuestion
                                onDraftChanged(sheet.copy(answers = answers, marked = marked))
                            }) { Text("پاک‌کردن پاسخ") }
                        }
                    }
                }

                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    TextButton(
                        onClick = { currentQuestion = (currentQuestion - 1).coerceAtLeast(1) },
                        enabled = currentQuestion > 1,
                    ) { Text("سؤال قبلی") }
                    TextButton(
                        onClick = { currentQuestion = (currentQuestion + 1).coerceAtMost(sheet.questionCount) },
                        enabled = currentQuestion < sheet.questionCount,
                    ) { Text("سؤال بعدی") }
                }
            }
        },
        confirmButton = {
            Button(onClick = { showFinishConfirmation = true }) { Text("پایان و ثبت نتیجه") }
        },
        dismissButton = {
            TextButton(onClick = onDismiss) { Text("ذخیره و خروج") }
        },
    )

    if (showFinishConfirmation) {
        AlertDialog(
            onDismissRequest = { showFinishConfirmation = false },
            title = { Text("ثبت نهایی آزمون؟") },
            text = {
                Text(
                    "${answeredCount} پاسخ داده شده و ${unansweredCount} سؤال بی‌پاسخ باقی مانده است. پس از ثبت، نتیجه در تاریخچه ذخیره می‌شود.",
                )
            },
            confirmButton = {
                Button(onClick = {
                    showFinishConfirmation = false
                    onFinish(updatedSheet)
                }) { Text("ثبت نتیجه") }
            },
            dismissButton = {
                TextButton(onClick = { showFinishConfirmation = false }) { Text("بازگشت به آزمون") }
            },
        )
    }
}


@Composable
private fun AnswerKeyDialog(
    sheet: ExamSheet,
    onDismiss: () -> Unit,
    onSave: (ExamSheet) -> Unit,
) {
    var answerKey by remember(sheet.id) { mutableStateOf(sheet.answerKey) }
    var negativeMarking by remember(sheet.id) { mutableStateOf(sheet.negativeMarking) }

    AlertDialog(
        onDismissRequest = onDismiss,
        title = {
            Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
                Text("کلید پاسخ")
                Text(sheet.name, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
            }
        },
        text = {
            Column(
                modifier = Modifier.fillMaxWidth().heightIn(max = 520.dp),
                verticalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Checkbox(checked = negativeMarking, onCheckedChange = { negativeMarking = it })
                    Text("اعمال نمرهٔ منفی (هر ۳ غلط = ۱ درست)")
                }
                Text(
                    "${answerKey.size} پاسخ از ${sheet.questionCount} سؤال کلیدگذاری شده",
                    style = MaterialTheme.typography.labelMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
                LazyColumn(verticalArrangement = Arrangement.spacedBy(4.dp)) {
                    items(sheet.questionCount) { index ->
                        val question = index + 1
                        Card(colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant)) {
                            Column(Modifier.fillMaxWidth().padding(horizontal = 10.dp, vertical = 6.dp)) {
                                Row(
                                    modifier = Modifier.fillMaxWidth(),
                                    horizontalArrangement = Arrangement.SpaceBetween,
                                    verticalAlignment = Alignment.CenterVertically,
                                ) {
                                    Text("سؤال $question", fontWeight = FontWeight.SemiBold)
                                    TextButton(onClick = { answerKey = answerKey - question }) {
                                        Text("بدون کلید")
                                    }
                                }
                                Row(
                                    modifier = Modifier.fillMaxWidth(),
                                    horizontalArrangement = Arrangement.SpaceEvenly,
                                    verticalAlignment = Alignment.CenterVertically,
                                ) {
                                    (0..3).forEach { option ->
                                        Column(horizontalAlignment = Alignment.CenterHorizontally) {
                                            RadioButton(
                                                selected = answerKey[question] == option,
                                                onClick = { answerKey = answerKey + (question to option) },
                                            )
                                            Text(listOf("۱", "۲", "۳", "۴")[option], style = MaterialTheme.typography.labelSmall)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        },
        confirmButton = {
            Button(onClick = {
                onSave(sheet.copy(answerKey = answerKey, negativeMarking = negativeMarking))
            }) { Text("ذخیرهٔ کلید") }
        },
        dismissButton = { TextButton(onClick = onDismiss) { Text("انصراف") } },
    )
}

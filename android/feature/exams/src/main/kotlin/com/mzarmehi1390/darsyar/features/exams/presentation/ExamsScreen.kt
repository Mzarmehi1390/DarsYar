package com.mzarmehi1390.darsyar.features.exams.presentation

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.ui.draw.clip
import androidx.compose.foundation.background
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
import com.mzarmehi1390.darsyar.core.designsystem.darsYarAnimateContentSize
import com.mzarmehi1390.darsyar.features.exams.domain.ExamPercentageCalculator
import com.mzarmehi1390.darsyar.features.exams.domain.ExamSheetOperations
import com.mzarmehi1390.darsyar.features.exams.domain.ExamHistoryAnalytics
import com.mzarmehi1390.darsyar.features.exams.domain.ExamHistorySummary
import com.mzarmehi1390.darsyar.features.exams.domain.ExamTakingState
import com.mzarmehi1390.darsyar.features.exams.domain.models.ExamResult
import com.mzarmehi1390.darsyar.features.exams.domain.models.ExamSheet
import kotlinx.coroutines.launch
import kotlinx.coroutines.delay
import java.util.UUID
import java.time.Instant
import java.time.ZoneId
import java.time.format.DateTimeFormatter

@Composable
fun ExamsScreen(viewModel: ExamViewModel) {
    val state by viewModel.uiState.collectAsStateWithLifecycle()
    val snackbar = remember { SnackbarHostState() }
    val scope = rememberCoroutineScope()
    var showAddSheet by remember { mutableStateOf(false) }
    var takingSheet by remember { mutableStateOf<ExamSheet?>(null) }
    var answerKeySheet by remember { mutableStateOf<ExamSheet?>(null) }
    var historicalResult by remember { mutableStateOf<ExamResult?>(null) }
    var renameSheet by remember { mutableStateOf<ExamSheet?>(null) }
    val historySummary = remember(state.results) { ExamHistoryAnalytics.summarize(state.results) }

    LaunchedEffect(takingSheet?.id, state.takingState.isTaking) {
        if (takingSheet != null && state.takingState.isTaking) {
            while (true) {
                delay(1_000)
                viewModel.refreshTimer()
            }
        }
    }

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
                Card(modifier = Modifier.darsYarAnimateContentSize(), colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.errorContainer)) {
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
                                Card(modifier = Modifier.darsYarAnimateContentSize(), colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.primaryContainer)) {
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
                            Card(modifier = Modifier.darsYarAnimateContentSize()) {
                                Column(Modifier.fillMaxWidth().padding(14.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                                    Row(
                                        modifier = Modifier.fillMaxWidth(),
                                        horizontalArrangement = Arrangement.SpaceBetween,
                                        verticalAlignment = Alignment.CenterVertically,
                                    ) {
                                        Text(
                                            sheet.name,
                                            modifier = Modifier.weight(1f),
                                            style = MaterialTheme.typography.titleMedium,
                                            fontWeight = FontWeight.SemiBold,
                                        )
                                        TextButton(onClick = { renameSheet = sheet }) {
                                            Text("تغییر نام")
                                        }
                                    }
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
                    if (state.results.isNotEmpty()) {
                        item(key = "exam-history-summary") { ExamHistorySummaryCard(historySummary) }
                    }
                    if (state.results.isEmpty()) {
                        item { EmptyExamCard("پس از ثبت نتیجه، کارنامه‌ها در این بخش نمایش داده می‌شوند.") }
                    } else {
                        items(
                            state.results.sortedByDescending { historyTimestamp(it.completedAt) },
                            key = { it.id },
                        ) { result ->
                            ExamHistoryResultCard(
                                result = result,
                                onEditAnswerKey = { historicalResult = result },
                            )
                        }
                    }
                    item { ExamPercentageCalculatorCard() }
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

    historicalResult?.let { result ->
        val historySheet = remember(result.id, result.answerKey, result.negativeMarking) {
            ExamSheet(
                id = "history-${result.id}",
                name = result.examName,
                questionCount = result.questionCount,
                negativeMarking = result.negativeMarking,
                answers = result.answers,
                answerKey = result.answerKey,
            )
        }
        AnswerKeyDialog(
            sheet = historySheet,
            onDismiss = { historicalResult = null },
            onSave = { updated ->
                viewModel.updateHistoricalAnswerKey(
                    resultId = result.id,
                    answerKey = updated.answerKey,
                    negativeMarking = updated.negativeMarking,
                ) { action ->
                    scope.launch {
                        snackbar.showSnackbar(
                            if (action == ExamActionResult.Success) {
                                "کلید ذخیره شد و درصد نتیجه دوباره محاسبه شد"
                            } else action.toMessage(),
                        )
                    }
                }
                historicalResult = null
            },
        )
    }

    takingSheet?.let { sheet ->
        ExamTakingDialog(
            sheet = sheet,
            takingState = state.takingState,
            onPause = viewModel::pauseExam,
            onResume = viewModel::resumeExam,
            onQuestionSelected = viewModel::selectQuestion,
            onDismiss = { takingSheet = null },
            onDraftChanged = { updated -> viewModel.saveSheet(updated) },
            onFinish = { updated ->
                viewModel.saveSheet(updated) { saveResult ->
                    if (saveResult == ExamActionResult.Success) {
                        viewModel.completeExam(updated.id) { result ->
                            scope.launch { snackbar.showSnackbar(result.toMessage()) }
                            if (result is ExamActionResult.Completed) {
                                takingSheet = null
                            }
                        }
                    } else {
                        scope.launch { snackbar.showSnackbar(saveResult.toMessage()) }
                    }
                }
            },
        )
    }

    renameSheet?.let { sheet ->
        RenameExamDialog(
            sheet = sheet,
            onDismiss = { renameSheet = null },
            onSave = { name ->
                val updated = runCatching { ExamSheetOperations.rename(sheet, name) }.getOrNull()
                if (updated == null) {
                    scope.launch { snackbar.showSnackbar("نام آزمون نمی‌تواند خالی باشد") }
                } else {
                    viewModel.saveSheet(updated) { result ->
                        scope.launch {
                            snackbar.showSnackbar(
                                if (result == ExamActionResult.Success) "نام آزمون و نتایج مرتبط به‌روزرسانی شدند"
                                else result.toMessage(),
                            )
                            if (result == ExamActionResult.Success) renameSheet = null
                        }
                    }
                }
            },
        )
    }

    if (showAddSheet) {
        AddExamSheetDialog(
            onDismiss = { showAddSheet = false },
            onSave = { name, count, durationMinutes, negativeMarking, configureAnswerKey ->
                val createdSheet = ExamSheet(
                    id = UUID.randomUUID().toString(),
                    name = name.trim(),
                    questionCount = count,
                    durationSeconds = durationMinutes * 60,
                    negativeMarking = negativeMarking,
                )
                viewModel.saveSheet(createdSheet) { result ->
                    scope.launch {
                        snackbar.showSnackbar(result.toMessage())
                        if (result == ExamActionResult.Success && configureAnswerKey) {
                            answerKeySheet = createdSheet
                        }
                    }
                }
                showAddSheet = false
            },
        )
    }
}



private val historyDateFormatter: DateTimeFormatter =
    DateTimeFormatter.ofPattern("yyyy/MM/dd HH:mm").withZone(ZoneId.systemDefault())

private fun historyTimestamp(value: String): Long =
    runCatching { Instant.parse(value).toEpochMilli() }.getOrDefault(0L)

private fun formatHistoryDate(value: String): String =
    runCatching { historyDateFormatter.format(Instant.parse(value)) }.getOrElse { value }

@Composable
private fun RenameExamDialog(
    sheet: ExamSheet,
    onDismiss: () -> Unit,
    onSave: (String) -> Unit,
) {
    var name by remember(sheet.id) { mutableStateOf(sheet.name) }
    val normalizedName = name.trim()
    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text("تغییر نام پاسخ‌برگ") },
        text = {
            OutlinedTextField(
                value = name,
                onValueChange = { name = it },
                modifier = Modifier.fillMaxWidth(),
                label = { Text("نام آزمون") },
                singleLine = true,
                supportingText = { Text("نام جدید در نتایج مرتبط نیز هماهنگ می‌شود") },
            )
        },
        confirmButton = {
            Button(
                onClick = { onSave(normalizedName) },
                enabled = normalizedName.isNotEmpty() && normalizedName != sheet.name,
            ) { Text("ذخیرهٔ نام") }
        },
        dismissButton = { TextButton(onClick = onDismiss) { Text("انصراف") } },
    )
}


@Composable
private fun ExamHistoryResultCard(
    result: ExamResult,
    onEditAnswerKey: () -> Unit,
) {
    val hasScore = result.percentage != null
    Card(modifier = Modifier.fillMaxWidth().darsYarAnimateContentSize()) {
        Column(
            modifier = Modifier.fillMaxWidth().padding(14.dp),
            verticalArrangement = Arrangement.spacedBy(9.dp),
        ) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Text(
                    result.examName,
                    modifier = Modifier.weight(1f),
                    style = MaterialTheme.typography.titleMedium,
                    fontWeight = FontWeight.SemiBold,
                )
                Text(
                    result.percentage?.let { "%.1f٪".format(it) } ?: "بدون کلید",
                    color = if (hasScore) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.onSurfaceVariant,
                    fontWeight = FontWeight.Bold,
                )
            }
            Text(
                formatHistoryDate(result.completedAt),
                style = MaterialTheme.typography.labelSmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                HistoryMetric("تعداد سؤال", result.questionCount.toString(), Modifier.weight(1f))
                HistoryMetric("کلیدگذاری‌شده", "${result.keyedQuestions}/${result.questionCount}", Modifier.weight(1f))
                HistoryMetric("نمره منفی", if (result.negativeMarking) "فعال" else "خاموش", Modifier.weight(1f))
            }
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                HistoryMetric("درست", result.correct.toString(), Modifier.weight(1f))
                HistoryMetric("غلط", result.wrong.toString(), Modifier.weight(1f))
                HistoryMetric("بی‌پاسخ", result.unanswered.toString(), Modifier.weight(1f))
            }
            TextButton(
                onClick = onEditAnswerKey,
                modifier = Modifier.align(Alignment.Start),
            ) {
                Text(
                    if (hasScore) "ویرایش کلید و محاسبهٔ مجدد"
                    else "ثبت کلید و محاسبهٔ درصد",
                )
            }
        }
    }
}

@Composable
private fun ExamHistorySummaryCard(summary: ExamHistorySummary) {
    Card(modifier = Modifier.fillMaxWidth().darsYarAnimateContentSize()) {
        Column(
            modifier = Modifier.fillMaxWidth().padding(14.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            Text("خلاصهٔ عملکرد", style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.Bold)
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                HistoryMetric("تعداد آزمون", summary.attemptCount.toString(), Modifier.weight(1f))
                HistoryMetric("میانگین درصد", summary.averagePercentage?.let { "%.1f٪".format(it) } ?: "—", Modifier.weight(1f))
                HistoryMetric("بهترین درصد", summary.bestPercentage?.let { "%.1f٪".format(it) } ?: "—", Modifier.weight(1f))
            }
            if (summary.recentTrend.isNotEmpty()) {
                Text("روند ۷ نتیجهٔ قابل محاسبه", style = MaterialTheme.typography.labelLarge, color = MaterialTheme.colorScheme.onSurfaceVariant)
                Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                    summary.recentTrend.forEachIndexed { index, value ->
                        Row(
                            modifier = Modifier.fillMaxWidth(),
                            horizontalArrangement = Arrangement.spacedBy(10.dp),
                            verticalAlignment = Alignment.CenterVertically,
                        ) {
                            Text(
                                (index + 1).toString(),
                                modifier = Modifier.width(22.dp),
                                style = MaterialTheme.typography.labelMedium,
                                color = MaterialTheme.colorScheme.onSurfaceVariant,
                            )
                            Box(
                                modifier = Modifier.weight(1f).height(12.dp)
                                    .clip(RoundedCornerShape(8.dp))
                                    .background(MaterialTheme.colorScheme.surfaceVariant),
                            ) {
                                Box(
                                    modifier = Modifier.fillMaxWidth(
                                        (value / 100.0).coerceIn(0.0, 1.0).toFloat(),
                                    )
                                        .height(12.dp)
                                        .clip(RoundedCornerShape(8.dp))
                                        .background(MaterialTheme.colorScheme.primary),
                                )
                            }
                            Text(
                                "${value.toInt()}٪",
                                modifier = Modifier.width(46.dp),
                                style = MaterialTheme.typography.labelMedium,
                                fontWeight = FontWeight.Bold,
                                textAlign = androidx.compose.ui.text.style.TextAlign.End,
                            )
                        }
                    }
                }
            }
            if (summary.scoredAttemptCount < summary.attemptCount) {
                Text(
                    "${summary.attemptCount - summary.scoredAttemptCount} نتیجه بدون کلید پاسخ، از میانگین کنار گذاشته شده است.",
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
        }
    }
}

@Composable
private fun HistoryMetric(label: String, value: String, modifier: Modifier = Modifier) {
    Column(
        modifier = modifier.clip(RoundedCornerShape(12.dp))
            .background(MaterialTheme.colorScheme.surfaceVariant)
            .padding(10.dp),
        verticalArrangement = Arrangement.spacedBy(4.dp),
    ) {
        Text(label, style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
        Text(value, style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.Bold, color = MaterialTheme.colorScheme.onSurface)
    }
}

@Composable
private fun EmptyExamCard(message: String) {
    Card(modifier = Modifier.darsYarAnimateContentSize(), colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant)) {
        Text(message, modifier = Modifier.fillMaxWidth().padding(16.dp), color = MaterialTheme.colorScheme.onSurfaceVariant)
    }
}

@Composable
private fun AddExamSheetDialog(
    onDismiss: () -> Unit,
    onSave: (name: String, questionCount: Int, durationMinutes: Int, negativeMarking: Boolean, configureAnswerKey: Boolean) -> Unit,
) {
    var name by remember { mutableStateOf("") }
    var count by remember { mutableStateOf("20") }
    var durationMinutes by remember { mutableStateOf("30") }
    var negativeMarking by remember { mutableStateOf(false) }
    var configureAnswerKey by remember { mutableStateOf(true) }
    val parsedCount = count.toIntOrNull()
    val parsedDuration = durationMinutes.toIntOrNull()

    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text("برگهٔ آزمون جدید") },
        text = {
            Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                OutlinedTextField(
                    value = name,
                    onValueChange = { name = it },
                    label = { Text("نام آزمون") },
                    singleLine = true,
                )
                OutlinedTextField(
                    value = count,
                    onValueChange = { count = it.filter(Char::isDigit).take(3) },
                    label = { Text("تعداد سؤال") },
                    singleLine = true,
                )
                OutlinedTextField(
                    value = durationMinutes,
                    onValueChange = { durationMinutes = it.filter(Char::isDigit).take(4) },
                    label = { Text("مدت آزمون (دقیقه)") },
                    supportingText = { Text("از ۱ تا ۱۴۴۰ دقیقه") },
                    singleLine = true,
                )
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Checkbox(
                        checked = negativeMarking,
                        onCheckedChange = { negativeMarking = it },
                    )
                    Text("اعمال نمرهٔ منفی")
                }
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Checkbox(
                        checked = configureAnswerKey,
                        onCheckedChange = { configureAnswerKey = it },
                    )
                    Text("ورود کلید پاسخ پس از ساخت")
                }
            }
        },
        confirmButton = {
            Button(
                onClick = {
                    onSave(name, parsedCount ?: 0, parsedDuration ?: 0, negativeMarking, configureAnswerKey)
                },
                enabled = name.isNotBlank() &&
                    parsedCount != null && parsedCount in 1..200 &&
                    parsedDuration != null && parsedDuration in 1..1440,
            ) {
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
    takingState: ExamTakingState,
    onPause: () -> Unit,
    onResume: () -> Unit,
    onQuestionSelected: (Int) -> Unit,
    onDismiss: () -> Unit,
    onDraftChanged: (ExamSheet) -> Unit,
    onFinish: (ExamSheet) -> Unit,
) {
    var currentQuestion by remember(sheet.id) { mutableStateOf(takingState.currentQuestionNumber) }
    var answers by remember(sheet.id) { mutableStateOf(sheet.answers) }
    var marked by remember(sheet.id) { mutableStateOf(sheet.marked) }
    var showFinishConfirmation by remember { mutableStateOf(false) }

    val updatedSheet = sheet.copy(answers = answers, marked = marked)
    val answeredCount = answers.size
    val unansweredCount = (sheet.questionCount - answeredCount).coerceAtLeast(0)

    LaunchedEffect(takingState.currentQuestionNumber) {
        currentQuestion = takingState.currentQuestionNumber.coerceIn(1, sheet.questionCount)
    }

    fun selectQuestion(number: Int) {
        val selected = number.coerceIn(1, sheet.questionCount)
        currentQuestion = selected
        onQuestionSelected(selected)
    }

    LaunchedEffect(takingState.isFinishing, takingState.remainingSeconds) {
        // Expiry is submitted automatically by the ViewModel; only manual finish asks for confirmation.
        if (takingState.isFinishing && takingState.remainingSeconds > 0) {
            showFinishConfirmation = true
        } else if (takingState.remainingSeconds == 0) {
            showFinishConfirmation = false
        }
    }

    AlertDialog(
        onDismissRequest = onDismiss,
        title = {
            Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
                Text(sheet.name, style = MaterialTheme.typography.titleLarge)
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    val totalSeconds = takingState.remainingSeconds.coerceAtLeast(0)
                    val minutes = totalSeconds / 60
                    val seconds = totalSeconds % 60
                    Text(
                        "زمان باقی‌مانده: %02d:%02d".format(minutes, seconds),
                        color = if (totalSeconds <= 60) MaterialTheme.colorScheme.error else MaterialTheme.colorScheme.primary,
                        fontWeight = FontWeight.Bold,
                    )
                    TextButton(onClick = if (takingState.isTaking) onPause else onResume) {
                        Text(if (takingState.isTaking) "توقف موقت" else "ادامهٔ زمان")
                    }
                }
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
                            onClick = { selectQuestion(number) },
                            colors = androidx.compose.material3.ButtonDefaults.filledTonalButtonColors(
                                containerColor = container,
                                contentColor = content,
                            ),
                            contentPadding = androidx.compose.foundation.layout.PaddingValues(horizontal = 12.dp, vertical = 8.dp),
                        ) { Text(number.toString()) }
                    }
                }

                Card(modifier = Modifier.darsYarAnimateContentSize(), colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant)) {
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
                                    val updated = ExamSheetOperations.setAnswer(
                                        updatedSheet,
                                        question = currentQuestion,
                                        answer = option,
                                    )
                                    answers = updated.answers
                                    marked = updated.marked
                                    onDraftChanged(updated)
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
                                val updated = ExamSheetOperations.setAnswer(
                                    updatedSheet,
                                    question = currentQuestion,
                                    answer = null,
                                    marked = currentQuestion in marked,
                                )
                                answers = updated.answers
                                marked = updated.marked
                                onDraftChanged(updated)
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
                        onClick = { selectQuestion(currentQuestion - 1) },
                        enabled = currentQuestion > 1,
                    ) { Text("سؤال قبلی") }
                    TextButton(
                        onClick = { selectQuestion(currentQuestion + 1) },
                        enabled = currentQuestion < sheet.questionCount,
                    ) { Text("سؤال بعدی") }
                }
            }
        },
        confirmButton = {
            if (takingState.isFinishing && takingState.remainingSeconds == 0) {
                Button(
                    onClick = { onFinish(updatedSheet) },
                    enabled = !takingState.isSavingResult,
                ) {
                    Text(if (takingState.isSavingResult) "در حال ثبت نتیجه..." else "تلاش دوباره برای ثبت نتیجه")
                }
            } else {
                Button(onClick = { showFinishConfirmation = true }) { Text("پایان و ثبت نتیجه") }
            }
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
                        Card(modifier = Modifier.darsYarAnimateContentSize(), colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant)) {
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


@Composable
private fun ExamPercentageCalculatorCard() {
    var correct by remember { mutableStateOf("0") }
    var wrong by remember { mutableStateOf("0") }
    var unanswered by remember { mutableStateOf("0") }

    fun parseCount(value: String): Int = value.fold(0) { total, char ->
        total * 10 + (char.digitToIntOrNull() ?: 0)
    }

    fun sanitize(value: String): String = value.filter { it.digitToIntOrNull() != null }.take(3)

    val correctCount = parseCount(correct)
    val wrongCount = parseCount(wrong)
    val unansweredCount = parseCount(unanswered)
    val result = ExamPercentageCalculator.calculate(correctCount, wrongCount, unansweredCount)
    val valid = result.withoutPenalty != null

    Card(modifier = Modifier.fillMaxWidth().darsYarAnimateContentSize()) {
        Column(
            modifier = Modifier.fillMaxWidth().padding(14.dp),
            verticalArrangement = Arrangement.spacedBy(10.dp),
        ) {
            Text("ماشین‌حساب درصد آزمون", style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.Bold)
            Text(
                "تعداد پاسخ‌های درست، غلط و بی‌پاسخ را وارد کن؛ مجموع باید بین ۱ تا ۲۰۰ باشد.",
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                OutlinedTextField(
                    value = correct,
                    onValueChange = { correct = sanitize(it) },
                    modifier = Modifier.weight(1f),
                    label = { Text("درست") },
                    singleLine = true,
                )
                OutlinedTextField(
                    value = wrong,
                    onValueChange = { wrong = sanitize(it) },
                    modifier = Modifier.weight(1f),
                    label = { Text("غلط") },
                    singleLine = true,
                )
                OutlinedTextField(
                    value = unanswered,
                    onValueChange = { unanswered = sanitize(it) },
                    modifier = Modifier.weight(1f),
                    label = { Text("بی‌پاسخ") },
                    singleLine = true,
                )
            }
            if (!valid) {
                Text(
                    "مجموع تعدادها باید حداقل ۱ و حداکثر ۲۰۰ باشد.",
                    color = MaterialTheme.colorScheme.error,
                    style = MaterialTheme.typography.bodySmall,
                )
            }
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text("بدون نمرهٔ منفی", modifier = Modifier.weight(1f), style = MaterialTheme.typography.bodyMedium)
                Text(
                    result.withoutPenalty?.let { "%.1f٪".format(it) } ?: "—",
                    color = MaterialTheme.colorScheme.primary,
                    fontWeight = FontWeight.Bold,
                )
            }
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text("با نمرهٔ منفی (هر ۳ غلط = ۱ درست)", modifier = Modifier.weight(1f), style = MaterialTheme.typography.bodyMedium)
                Text(
                    result.withPenalty?.let { "%.1f٪".format(it) } ?: "—",
                    color = MaterialTheme.colorScheme.primary,
                    fontWeight = FontWeight.Bold,
                )
            }
        }
    }
}

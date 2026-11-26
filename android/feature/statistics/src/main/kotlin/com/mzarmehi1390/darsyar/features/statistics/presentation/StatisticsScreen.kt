package com.mzarmehi1390.darsyar.features.statistics.presentation

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.drawscope.DrawScope
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.mzarmehi1390.darsyar.core.common.PersianDigits
import com.mzarmehi1390.darsyar.features.planner.domain.models.StudySession
import com.mzarmehi1390.darsyar.features.planner.domain.models.StudyTask
import com.mzarmehi1390.darsyar.features.statistics.domain.DailyStudyTotal
import com.mzarmehi1390.darsyar.features.statistics.domain.StudyStatistics
import java.time.LocalDate

@Composable
fun StatisticsScreen(
    sessions: List<StudySession>,
    tasks: List<StudyTask>,
    today: LocalDate = LocalDate.now(),
) {
    val statistics = remember(sessions, tasks, today) {
        StudyStatistics.calculate(sessions, tasks, today)
    }
    val colors = MaterialTheme.colorScheme
    Column(
        modifier = Modifier.fillMaxSize().padding(horizontal = 20.dp, vertical = 16.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp),
    ) {
        Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
            Text("آمار مطالعه", style = MaterialTheme.typography.headlineMedium, fontWeight = FontWeight.Bold)
            Text("گزارش عملکرد هفتهٔ جاری", color = colors.onSurfaceVariant)
        }
        Row(horizontalArrangement = Arrangement.spacedBy(12.dp), modifier = Modifier.fillMaxWidth()) {
            MetricCard("زمان برنامه‌ریزی", statistics.totalPlannedMinutes.toHourMinuteLabel(), Modifier.weight(1f))
            MetricCard("زمان مطالعه‌شده", statistics.totalCompletedMinutes.toHourMinuteLabel(), Modifier.weight(1f))
        }
        Card(
            modifier = Modifier.fillMaxWidth(),
            colors = CardDefaults.cardColors(containerColor = colors.surfaceContainerHigh),
            shape = RoundedCornerShape(24.dp),
        ) {
            Column(Modifier.fillMaxWidth().padding(18.dp), verticalArrangement = Arrangement.spacedBy(14.dp)) {
                Text("روند هفتگی مطالعه", style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.SemiBold)
                Row(horizontalArrangement = Arrangement.spacedBy(16.dp)) {
                    LegendDot(colors.primary.copy(alpha = 0.35f), "برنامه‌ریزی‌شده")
                    LegendDot(colors.tertiary, "تکمیل‌شده")
                }
                Canvas(Modifier.fillMaxWidth().height(184.dp)) {
                    drawWeeklyBars(statistics.dailyTotals, colors.primary.copy(alpha = 0.22f), colors.tertiary, colors.outlineVariant)
                }
                Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                    statistics.dailyTotals.forEach { day ->
                        Text(day.date.dayOfWeek.persianShortName(), style = MaterialTheme.typography.labelSmall, color = colors.onSurfaceVariant)
                    }
                }
            }
        }
        Card(
            modifier = Modifier.fillMaxWidth(),
            colors = CardDefaults.cardColors(containerColor = colors.surfaceContainerHigh),
            shape = RoundedCornerShape(24.dp),
        ) {
            Column(Modifier.fillMaxWidth().padding(18.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
                Text("پیشرفت", style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.SemiBold)
                ProgressLine("تکمیل جلسات", statistics.completion, "${PersianDigits.format(statistics.totalCompletedMinutes)} از ${PersianDigits.format(statistics.totalPlannedMinutes)} دقیقه")
                ProgressLine("انجام وظایف", statistics.taskCompletion, "${PersianDigits.format(statistics.completedTaskCount)} از ${PersianDigits.format(statistics.totalTaskCount)} وظیفه")
            }
        }
        Text("آمار بر اساس جلسات ذخیره‌شده و وضعیت فعلی وظایف محاسبه می‌شود.", style = MaterialTheme.typography.bodySmall, color = colors.onSurfaceVariant)
    }
}

@Composable
private fun MetricCard(title: String, value: String, modifier: Modifier = Modifier) {
    Card(modifier, colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceContainerHigh), shape = RoundedCornerShape(20.dp)) {
        Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
            Text(title, style = MaterialTheme.typography.labelMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
            Text(value, style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.Bold, color = MaterialTheme.colorScheme.primary)
        }
    }
}

@Composable
private fun LegendDot(color: androidx.compose.ui.graphics.Color, label: String) {
    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
        Canvas(Modifier.size(9.dp)) { drawCircle(color = color, radius = size.minDimension / 2) }
        Text(label, style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
    }
}

@Composable
private fun ProgressLine(label: String, value: Double, detail: String) {
    val trackColor = MaterialTheme.colorScheme.surfaceVariant
    val progressColor = MaterialTheme.colorScheme.primary
    Column(verticalArrangement = Arrangement.spacedBy(7.dp)) {
        Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
            Text(label, fontWeight = FontWeight.Medium)
            Text("${PersianDigits.format((value * 100).toInt())}٪", color = progressColor, fontWeight = FontWeight.Bold)
        }
        Canvas(Modifier.fillMaxWidth().height(8.dp)) {
            drawRoundRect(color = trackColor, cornerRadius = CornerRadius(size.height / 2))
            drawRoundRect(
                color = progressColor,
                size = Size(size.width * value.toFloat().coerceIn(0f, 1f), size.height),
                cornerRadius = CornerRadius(size.height / 2),
            )
        }
        Text(detail, style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
    }
}

private fun DrawScope.drawWeeklyBars(
    dailyTotals: List<DailyStudyTotal>,
    plannedColor: androidx.compose.ui.graphics.Color,
    completedColor: androidx.compose.ui.graphics.Color,
    gridColor: androidx.compose.ui.graphics.Color,
) {
    val maxValue = dailyTotals.maxOfOrNull(DailyStudyTotal::plannedMinutes)?.coerceAtLeast(1) ?: 1
    val baseline = size.height - 8.dp.toPx()
    val chartHeight = baseline - 8.dp.toPx()
    repeat(3) { line ->
        val y = baseline - chartHeight * (line + 1) / 3f
        drawLine(gridColor, Offset(0f, y), Offset(size.width, y), strokeWidth = 1.dp.toPx())
    }
    val slotWidth = size.width / 7f
    val barWidth = slotWidth * 0.28f
    dailyTotals.forEachIndexed { index, day ->
        val centerX = size.width - slotWidth * (index + 0.5f)
        val plannedHeight = chartHeight * day.plannedMinutes / maxValue.toFloat()
        val completedHeight = chartHeight * day.completedMinutes / maxValue.toFloat()
        drawRoundRect(plannedColor, Offset(centerX - barWidth / 2, baseline - plannedHeight), Size(barWidth, plannedHeight.coerceAtLeast(0f)), CornerRadius(barWidth / 2))
        drawRoundRect(completedColor, Offset(centerX - barWidth / 2, baseline - completedHeight), Size(barWidth, completedHeight.coerceAtLeast(0f)), CornerRadius(barWidth / 2))
    }
}

private fun Int.toHourMinuteLabel(): String =
    if (this < 60) "${PersianDigits.format(this)} دقیقه" else "${PersianDigits.format(this / 60)} ساعت و ${PersianDigits.format(this % 60)} دقیقه"

private fun java.time.DayOfWeek.persianShortName(): String = when (this) {
    java.time.DayOfWeek.SATURDAY -> "ش"
    java.time.DayOfWeek.SUNDAY -> "ی"
    java.time.DayOfWeek.MONDAY -> "د"
    java.time.DayOfWeek.TUESDAY -> "س"
    java.time.DayOfWeek.WEDNESDAY -> "چ"
    java.time.DayOfWeek.THURSDAY -> "پ"
    java.time.DayOfWeek.FRIDAY -> "ج"
}

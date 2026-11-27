package com.mzarmehi1390.darsyar.features.planner.presentation

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import com.mzarmehi1390.darsyar.core.common.JalaliDate
import com.mzarmehi1390.darsyar.core.common.PersianDigits
import java.time.LocalDate

private val jalaliMonthNames = listOf(
    "فروردین", "اردیبهشت", "خرداد", "تیر", "مرداد", "شهریور",
    "مهر", "آبان", "آذر", "دی", "بهمن", "اسفند",
)
private val jalaliWeekdayNames = listOf("ش", "ی", "د", "س", "چ", "پ", "ج")

/**
 * Shared Persian calendar picker. The callback deliberately returns a Gregorian
 * ISO date key so existing Room/domain/backup contracts remain unchanged.
 */
@Composable
internal fun JalaliDatePickerDialog(
    initialIsoDate: String?,
    onDismiss: () -> Unit,
    onDateSelected: (String) -> Unit,
) {
    val initialGregorian = remember(initialIsoDate) {
        runCatching { initialIsoDate?.let(LocalDate::parse) ?: LocalDate.now() }
            .getOrDefault(LocalDate.now())
    }
    var visibleMonth by remember(initialIsoDate) {
        mutableStateOf(JalaliDate.fromGregorian(initialGregorian).let { it.year to it.month })
    }
    var selectedDate by remember(initialIsoDate) { mutableStateOf(initialGregorian) }
    val (year, month) = visibleMonth
    val firstDay = remember(year, month) { JalaliDate.toGregorian(JalaliDate(year, month, 1)) }
    val daysInMonth = remember(year, month) {
        val nextMonth = if (month == 12) JalaliDate(year + 1, 1, 1) else JalaliDate(year, month + 1, 1)
        (JalaliDate.toGregorian(nextMonth).toEpochDay() - firstDay.toEpochDay()).toInt()
    }
    val leadingCells = (firstDay.dayOfWeek.value + 1) % 7
    val cells = List(leadingCells) { null } + (1..daysInMonth).map { day ->
        JalaliDate.toGregorian(JalaliDate(year, month, day))
    }
    val paddedCells = cells + List((7 - cells.size % 7) % 7) { null }

    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text("انتخاب تاریخ شمسی") },
        text = {
            Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    IconButton(onClick = {
                        visibleMonth = if (month == 1) year - 1 to 12 else year to month - 1
                    }) { Text("‹", style = MaterialTheme.typography.headlineSmall) }
                    Text(
                        "${jalaliMonthNames[month - 1]} ${PersianDigits.format(year)}",
                        style = MaterialTheme.typography.titleMedium,
                        fontWeight = FontWeight.SemiBold,
                    )
                    IconButton(onClick = {
                        visibleMonth = if (month == 12) year + 1 to 1 else year to month + 1
                    }) { Text("›", style = MaterialTheme.typography.headlineSmall) }
                }
                Row(Modifier.fillMaxWidth()) {
                    jalaliWeekdayNames.forEach { name ->
                        Text(
                            name,
                            modifier = Modifier.weight(1f),
                            textAlign = TextAlign.Center,
                            style = MaterialTheme.typography.labelMedium,
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                        )
                    }
                }
                paddedCells.chunked(7).forEach { week ->
                    Row(Modifier.fillMaxWidth()) {
                        week.forEach { date ->
                            if (date == null) {
                                Text(" ", modifier = Modifier.weight(1f).padding(vertical = 8.dp))
                            } else {
                                val isSelected = date == selectedDate
                                val isToday = date == LocalDate.now()
                                Column(
                                    modifier = Modifier
                                        .weight(1f)
                                        .padding(2.dp)
                                        .size(36.dp)
                                        .clip(CircleShape)
                                        .background(
                                            if (isSelected) MaterialTheme.colorScheme.primary
                                            else MaterialTheme.colorScheme.surface,
                                        )
                                        .clickable { selectedDate = date },
                                    horizontalAlignment = Alignment.CenterHorizontally,
                                    verticalArrangement = Arrangement.Center,
                                ) {
                                    Text(
                                        PersianDigits.format(JalaliDate.fromGregorian(date).day),
                                        color = if (isSelected) MaterialTheme.colorScheme.onPrimary
                                        else MaterialTheme.colorScheme.onSurface,
                                        style = MaterialTheme.typography.bodyMedium,
                                        fontWeight = if (isToday) FontWeight.Bold else FontWeight.Normal,
                                    )
                                }
                            }
                        }
                    }
                }
                Text(
                    "انتخاب‌شده: ${PersianDigits.toPersianDigits(JalaliDate.fromGregorian(selectedDate).toDisplayString())}",
                    modifier = Modifier.fillMaxWidth(),
                    textAlign = TextAlign.Center,
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
        },
        confirmButton = {
            TextButton(onClick = { onDateSelected(selectedDate.toString()) }) { Text("تأیید") }
        },
        dismissButton = { TextButton(onClick = onDismiss) { Text("انصراف") } },
    )
}

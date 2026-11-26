package com.mzarmehi1390.darsyar.features.exams.presentation

import androidx.compose.material3.AlertDialog
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import com.mzarmehi1390.darsyar.features.exams.domain.models.ExamSheet

@Composable
internal fun DeleteExamSheetDialog(
    sheet: ExamSheet,
    linkedHistoryCount: Int,
    onDismiss: () -> Unit,
    onConfirm: () -> Unit,
) {
    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text("حذف برگهٔ آزمون؟") },
        text = {
            Text(
                buildString {
                    append("«${sheet.name}» و پاسخ‌های ثبت‌شدهٔ آن حذف می‌شوند.")
                    if (linkedHistoryCount > 0) {
                        append("\n\nتعداد ${linkedHistoryCount} نتیجهٔ مرتبط نیز حذف خواهد شد.")
                    }
                    append("\n\nاین عملیات قابل بازگشت نیست.")
                },
            )
        },
        confirmButton = {
            TextButton(onClick = onConfirm) {
                Text("حذف دائمی", color = MaterialTheme.colorScheme.error)
            }
        },
        dismissButton = {
            TextButton(onClick = onDismiss) { Text("انصراف") }
        },
    )
}

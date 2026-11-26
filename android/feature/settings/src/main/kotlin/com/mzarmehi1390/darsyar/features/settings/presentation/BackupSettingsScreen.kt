package com.mzarmehi1390.darsyar.features.settings.presentation

import android.net.Uri
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.mzarmehi1390.darsyar.core.datastore.DarsYarPreferences
import com.mzarmehi1390.darsyar.core.datastore.DarsYarPreferencesRepository
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import kotlinx.coroutines.launch

@Composable
fun BackupSettingsScreen(
    gateway: BackupSettingsGateway,
    preferencesRepository: DarsYarPreferencesRepository,
) {
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    val preferences by preferencesRepository.preferences.collectAsStateWithLifecycle(
        initialValue = DarsYarPreferences(),
    )
    var busy by remember { mutableStateOf(false) }
    var statusMessage by remember { mutableStateOf<String?>(null) }
    var pendingBackup by remember { mutableStateOf<ValidatedBackup?>(null) }

    val exportLauncher = rememberLauncherForActivityResult(
        ActivityResultContracts.CreateDocument("application/json"),
    ) { uri: Uri? ->
        if (uri != null) scope.launch {
            busy = true
            statusMessage = null
            try {
                val json = gateway.exportBackup()
                val output = context.contentResolver.openOutputStream(uri)
                    ?: error("Unable to open selected destination.")
                output.bufferedWriter(Charsets.UTF_8).use { it.write(json) }
                statusMessage = "نسخهٔ پشتیبان با موفقیت ذخیره شد."
            } catch (_: Exception) {
                statusMessage = "ذخیرهٔ نسخهٔ پشتیبان انجام نشد."
            } finally {
                busy = false
            }
        }
    }

    val importLauncher = rememberLauncherForActivityResult(
        ActivityResultContracts.OpenDocument(),
    ) { uri: Uri? ->
        if (uri != null) scope.launch {
            busy = true
            statusMessage = null
            try {
                val validated = context.contentResolver.openInputStream(uri)?.use { input ->
                    gateway.readAndValidateBackup(input)
                } ?: throw IllegalStateException("Unable to open selected backup.")
                pendingBackup = validated
            } catch (_: Exception) {
                statusMessage = "فایل انتخاب‌شده معتبر نیست یا خواندن آن ممکن نشد."
            } finally {
                busy = false
            }
        }
    }

    pendingBackup?.let { backup ->
        AlertDialog(
            onDismissRequest = { if (!busy) pendingBackup = null },
            title = { Text("بازیابی نسخهٔ پشتیبان؟") },
            text = {
                Text(
                    "این فایل شامل ${backup.summary.taskCount} کار، " +
                        "${backup.summary.studySessionCount} جلسهٔ مطالعه، " +
                        "${backup.summary.examCount} آزمون و " +
                        "${backup.summary.resultCount} نتیجه است. " +
                        "با ادامه، اطلاعات فعلی برنامه با اطلاعات این فایل جایگزین می‌شود.",
                )
            },
            confirmButton = {
                TextButton(enabled = !busy, onClick = {
                    pendingBackup = null
                    scope.launch {
                        busy = true
                        statusMessage = null
                        try {
                            gateway.restoreBackup(backup.json)
                            statusMessage = "اطلاعات با موفقیت بازیابی شد."
                        } catch (_: Exception) {
                            statusMessage = "بازیابی نسخهٔ پشتیبان انجام نشد."
                        } finally {
                            busy = false
                        }
                    }
                }) { Text("جایگزینی و بازیابی") }
            },
            dismissButton = {
                TextButton(enabled = !busy, onClick = { pendingBackup = null }) {
                    Text("انصراف")
                }
            },
        )
    }

    Column(
        Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(24.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp),
    ) {
        Text("تنظیمات", style = MaterialTheme.typography.headlineLarge, fontWeight = FontWeight.Bold)
        Text("ظاهر برنامه", style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.SemiBold)
        Text("پوستهٔ برنامه", style = MaterialTheme.typography.titleMedium)
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            listOf("system" to "سیستم", "light" to "روشن", "dark" to "تیره").forEach { (mode, label) ->
                if (preferences.themeMode == mode) {
                    Button(
                        onClick = { scope.launch { preferencesRepository.setThemeMode(mode) } },
                        modifier = Modifier.weight(1f),
                    ) { Text(label) }
                } else {
                    OutlinedButton(
                        onClick = { scope.launch { preferencesRepository.setThemeMode(mode) } },
                        modifier = Modifier.weight(1f),
                    ) { Text(label) }
                }
            }
        }
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Column(modifier = Modifier.weight(1f)) {
                Text("انیمیشن‌های برنامه", style = MaterialTheme.typography.titleMedium)
                Text(
                    if (preferences.animationsEnabled) "تنظیم انیمیشن‌ها روشن است."
                    else "تنظیم انیمیشن‌ها خاموش است.",
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
            Switch(
                checked = preferences.animationsEnabled,
                onCheckedChange = { enabled ->
                    scope.launch { preferencesRepository.setAnimationsEnabled(enabled) }
                },
            )
        }
        Text(
            "اطلاعات درس‌یار به‌صورت محلی روی همین دستگاه ذخیره می‌شود. فایل پشتیبان را خودتان انتخاب و مدیریت می‌کنید.",
            style = MaterialTheme.typography.bodySmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
        Text("پشتیبان‌گیری و بازیابی", style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.SemiBold)
        Text(
            "از کارها، جلسات مطالعه، آزمون‌ها و نتایج خود یک فایل JSON بسازید. " +
                "برای انتقال اطلاعات به دستگاه دیگر، همین فایل را بازیابی کنید.",
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
        Button(
            onClick = { exportLauncher.launch("darsyar-backup.json") },
            enabled = !busy,
            modifier = Modifier.fillMaxWidth(),
        ) { Text("ذخیرهٔ نسخهٔ پشتیبان") }
        OutlinedButton(
            onClick = { importLauncher.launch(arrayOf("application/json")) },
            enabled = !busy,
            modifier = Modifier.fillMaxWidth(),
        ) { Text("انتخاب فایل برای بازیابی") }
        if (busy) {
            Row(
                Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.Center,
                verticalAlignment = Alignment.CenterVertically,
            ) {
                CircularProgressIndicator()
                Text("در حال پردازش…", modifier = Modifier.padding(start = 8.dp))
            }
        }
        statusMessage?.let {
            Text(it, color = MaterialTheme.colorScheme.primary, style = MaterialTheme.typography.bodyMedium)
        }
        Text(
            "فایل فقط با انتخاب خودتان از طریق پنجرهٔ امن اندروید خوانده یا ذخیره می‌شود؛ " +
                "برنامه به مجوز دسترسی گسترده به حافظه نیاز ندارد.",
            style = MaterialTheme.typography.bodySmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
    }
}

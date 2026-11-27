package com.mzarmehi1390.darsyar.macrobenchmark

import androidx.benchmark.macro.MacrobenchmarkScope
import androidx.benchmark.macro.StartupMode
import androidx.benchmark.macro.StartupTimingMetric
import androidx.benchmark.macro.junit4.MacrobenchmarkRule
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.uiautomator.By
import androidx.test.uiautomator.Until
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
class ExamProcessRecoveryTest {
    @get:Rule
    val benchmarkRule = MacrobenchmarkRule()

    @Test
    fun activeExamAndTimer_areRestoredAfterColdProcessRestart() {
        val examName = "Recovery-Exam"

        benchmarkRule.measureRepeated(
            packageName = TARGET_PACKAGE,
            metrics = listOf(StartupTimingMetric()),
            iterations = 1,
            startupMode = StartupMode.COLD,
            setupBlock = {
                // Isolate this scenario from previous emulator runs.
                device.executeShellCommand("pm clear $TARGET_PACKAGE")
                startActivityAndWait()

                openExams()
                clickText("برگهٔ جدید")
                waitForText("برگهٔ آزمون جدید")

                val nameField = device.findObjects(By.clazz("android.widget.EditText")).firstOrNull()
                checkNotNull(nameField) { "Exam name field was not exposed to UI Automator." }
                nameField.setText(examName)

                clickText("ذخیره")
                waitForText("انصراف")
                clickText("انصراف")

                clickText("شروع آزمون")
                waitForTextStartsWith("زمان باقی‌مانده:")
            },
            measureBlock = {
                // StartupMode.COLD terminates the target process after setupBlock.
                // A fresh MainActivity/ExamViewModel must load the durable Room state.
                startActivityAndWait()
                openExams()
                waitForText(examName)
                waitForTextStartsWith("زمان باقی‌مانده:")
                assertTrue(
                    "The restored exam timer was not rendered after a cold process restart.",
                    device.hasObject(By.textStartsWith("زمان باقی‌مانده:")),
                )
            },
        )
    }

    private fun MacrobenchmarkScope.openExams() {
        clickText("آزمون‌ها")
    }

    private fun MacrobenchmarkScope.clickText(value: String) {
        waitForText(value)
        val exact = device.findObject(By.text(value))
        val target = exact ?: device.findObject(By.textContains(value.substringAfterLast(' ')))
        checkNotNull(target) { "UI text disappeared before click: $value" }.click()
    }

    private fun MacrobenchmarkScope.waitForText(value: String) {
        val exactMatch = device.wait(Until.hasObject(By.text(value)), UI_TIMEOUT_MILLIS)
        val fallbackMatch = !exactMatch && device.wait(
            Until.hasObject(By.textContains(value.substringAfterLast(' '))),
            UI_TIMEOUT_MILLIS,
        )
        check(exactMatch || fallbackMatch) {
            "Timed out waiting for UI text: $value"
        }
    }

    private fun MacrobenchmarkScope.waitForTextStartsWith(value: String) {
        check(device.wait(Until.hasObject(By.textStartsWith(value)), UI_TIMEOUT_MILLIS)) {
            "Timed out waiting for UI text starting with: $value"
        }
    }

    private companion object {
        const val TARGET_PACKAGE = "com.mzarmehi1390.darsyar"
        const val UI_TIMEOUT_MILLIS = 15_000L
    }
}

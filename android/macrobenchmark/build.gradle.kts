plugins {
    alias(libs.plugins.android.test)
}

android {
    namespace = "com.mzarmehi1390.darsyar.macrobenchmark"
    compileSdk = 37

    defaultConfig {
        minSdk = 23
        targetSdk = 36
        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"
        // This suite validates process recovery on a debug APK; it is not used
        // to publish performance numbers. The emulator warning is therefore
        // suppressed only for this functional recovery check.
        testInstrumentationRunnerArguments["androidx.benchmark.suppressErrors"] =
            "DEBUGGABLE,EMULATOR"
    }

    targetProjectPath = ":app"
    // A macrobenchmark test APK must instrument itself, not the target app.
    // This keeps the test runner in a separate process so Macrobenchmark can
    // kill and relaunch the application under test.
    experimentalProperties["android.experimental.self-instrumenting"] = true
}

dependencies {
    implementation(libs.androidx.benchmark.macro.junit4)
    implementation(libs.androidx.test.ext.junit)
    implementation(libs.androidx.test.uiautomator)
}

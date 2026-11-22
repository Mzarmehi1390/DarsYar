plugins {
    alias(libs.plugins.android.library)
    alias(libs.plugins.kotlin.android)
}

android {
    namespace = "com.mzarmehi1390.darsyar.core.common"
    compileSdk = 37
    defaultConfig { minSdk = 23 }
}

dependencies {
    implementation(libs.kotlinx.coroutines.core)
}

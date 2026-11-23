plugins {
    alias(libs.plugins.android.library)
}

android {
    namespace = "com.mzarmehi1390.darsyar.core.common"
    compileSdk = 36
    defaultConfig { minSdk = 23 }
}

dependencies {
    implementation(libs.kotlinx.coroutines.core)
}

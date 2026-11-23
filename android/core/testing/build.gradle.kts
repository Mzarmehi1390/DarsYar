plugins {
    alias(libs.plugins.android.library)
}

android {
    namespace = "com.mzarmehi1390.darsyar.core.testing"
    compileSdk = 36
    defaultConfig { minSdk = 23 }
}

dependencies {
    api(libs.junit)
    api(libs.kotlinx.coroutines.test)
}

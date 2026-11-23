plugins {
    alias(libs.plugins.android.library)
}

android {
    namespace = "com.mzarmehi1390.darsyar.core.datastore"
    compileSdk = 37
    defaultConfig { minSdk = 23 }
}

dependencies {
    implementation(project(":core:common"))
    implementation(libs.androidx.datastore.preferences)
    implementation(libs.kotlinx.coroutines.android)
}

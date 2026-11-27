pluginManagement {
    resolutionStrategy {
        eachPlugin {
            if (requested.id.id == "org.jetbrains.kotlin.plugin.compose") {
                // Resolve the Compose compiler plugin implementation directly from Maven Central.
                // This avoids relying on the separate Gradle Plugin Portal marker artifact.
                useModule("org.jetbrains.kotlin:compose-compiler-gradle-plugin:${requested.version}")
            }
        }
    }
    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

dependencyResolutionManagement {
    repositoriesMode.set(RepositoriesMode.FAIL_ON_PROJECT_REPOS)
    repositories {
        google()
        mavenCentral()
    }
}

rootProject.name = "DarsYar"

include(":app")
include(":macrobenchmark")
include(":core:common")
include(":core:designsystem")
include(":core:graphics")
include(":core:database")
include(":core:datastore")
include(":core:testing")
include(":feature:dashboard")
include(":feature:planner")
include(":feature:exams")
include(":feature:settings")
include(":feature:statistics")

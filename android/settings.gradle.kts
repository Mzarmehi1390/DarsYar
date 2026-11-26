pluginManagement {
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

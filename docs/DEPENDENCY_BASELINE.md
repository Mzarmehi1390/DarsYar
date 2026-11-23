# Native Android Dependency Baseline

> Snapshot date: 2026-11-23. Versions are pinned, not dynamic. This is the initial compatibility candidate; GitHub Actions build verification is the acceptance gate.

## Toolchain

| Component | Pinned version | Basis |
|---|---:|---|
| Android Gradle Plugin | 9.5.0 | Stable AGP release |
| Gradle | 9.6.0 | Minimum required by AGP 9.5 |
| Kotlin | 2.4.21 | Current stable Kotlin patch |
| Compose Compiler Gradle plugin | 2.4.21 | Must match Kotlin compiler plugin |
| KSP | 2.3.12 | KSP quick-start example for Kotlin 2.4.21 |
| JDK | 17 | AGP toolchain baseline |

## AndroidX and libraries

| Library | Pinned version | Notes |
|---|---:|---|
| Compose BOM | 2026.06.01 | Stable Compose 1.11.x line compatible with API 36 |
| Navigation Compose | 2.10.2 | Stable Navigation 2.10 line |
| Room | 2.8.5 | Stable release; use KSP compiler |
| Preferences DataStore | 1.3.0 | Stable release |
| Lifecycle | 2.11.1 | Stable release for lifecycle-aware Compose collection/ViewModel integration |
| WorkManager | 2.12.0 | Add only for genuine deferrable background work |
| Hilt | 2.60.1 | Pinned stable artifact version; validate Gradle plugin + KSP integration in CI |
| Coil Compose | 3.6.3 | Pinned stable release; only use where image loading is needed |
| Coroutines | 1.10.2 | Kotlin coroutine runtime |
| Kotlin Serialization JSON | 1.9.0 | Backup DTOs / typed route serialization |
| Activity Compose | 1.13.0 | Activity integration |
| JUnit | 4.13.2 | Local JVM unit tests |
| AndroidX Test JUnit | 1.3.0 | Instrumented tests |
| Espresso | 3.7.0 | Instrumented test support |
| Detekt | 1.23.8 | Static Kotlin analysis baseline |

Compose libraries are versioned through the BOM. Do not assign independent Compose versions unless a documented compatibility reason requires an override.

## Why the initial build uses API 36

The newest Compose 1.12/1.13 releases require compileSdk 37/37.1. The public Android SDK package feed available to the GitHub runner did not expose `platforms;android-37`; CI stopped before Gradle could run. To establish a reproducible native baseline, the initial build uses stable Compose 1.11.x with compileSdk 36, which is available in the runner. This is a deliberate compatibility choice, not a claim that newer Compose releases are unsuitable. Re-evaluate after API 37 is available in the standard SDK feed and AGP support is verified.

## Compatibility checks before locking

1. Confirm Compose BOM 2026.06.01 resolves and its mapped Compose artifacts compile against API 36.
2. Confirm Hilt 2.60.1 plugin + KSP 2.3.12 works with Kotlin 2.4.21 and AGP 9.5.0.
3. Verify Room 2.8.5 and DataStore 1.3.0 resolve and compile.
4. Verify Coil 3.6.3 resolves from Maven Central and add it to feature dependencies only where a real image-loading use case exists.
5. If any dependency forces an unstable transitive version or toolchain downgrade, stop and document the compatibility decision.
6. No dynamic dependency selectors (for example `9.5.+`) are allowed.

## Official references

- Compose stable release and API-level requirements: https://developer.android.com/jetpack/androidx/releases/compose
- Compose BOM mapping: https://developer.android.com/develop/ui/compose/bom
- AGP 9.5 / Gradle 9.6 compatibility: https://developer.android.com/build/releases/about-agp
- Kotlin 2.4.21 release: https://kotlinlang.org/docs/releases.html
- Room 2.8.5 and KSP compiler setup: https://developer.android.com/jetpack/androidx/releases/room
- DataStore 1.3.0: https://developer.android.com/jetpack/androidx/releases/datastore
- Navigation 2.10.2: https://developer.android.com/jetpack/androidx/releases/navigation
- KSP setup: https://kotlinlang.org/docs/ksp-quickstart.html
- Dagger/Hilt releases: https://github.com/google/dagger/releases

## Current validation status

- [ ] Gradle dependency resolution.
- [ ] Native debug build.
- [ ] Unit tests.
- [ ] Android Lint.
- [ ] Detekt.
- [ ] Physical-device smoke test.

A version being listed here is a candidate until the checks above pass.

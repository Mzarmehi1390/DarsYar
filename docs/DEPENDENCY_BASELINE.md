# Native Android Dependency Baseline

> Snapshot date: 2026-11-23. Versions are pinned, not dynamic. This is the initial compatibility candidate; GitHub Actions build verification is the acceptance gate.

## Toolchain

| Component | Pinned version | Basis |
|---|---:|---|
| Android Gradle Plugin | 9.5.0 | Current stable AGP example in Android build docs |
| Gradle | 9.6.0 | Minimum required by AGP 9.5 |
| Kotlin | 2.4.21 | Current stable Kotlin patch |
| Compose Compiler Gradle plugin | 2.4.21 | Must match Kotlin compiler plugin |
| KSP | 2.3.12 | Current KSP quick-start example for Kotlin 2.4.21 |
| JDK | 17 | AGP 9.5 toolchain baseline |

## AndroidX and libraries

| Library | Pinned version | Notes |
|---|---:|---|
| Compose BOM | 2026.11.01 | November 2026 stable Compose release; requires Kotlin 2.2+ and compileSdk 37.1 |
| Navigation Compose | 2.10.2 | Stable Navigation 2.10 line |
| Room | 2.8.5 | Stable release; use KSP compiler |
| Preferences DataStore | 1.3.0 | Stable release |
| Lifecycle | 2.12.0 | Lifecycle-aware Compose collection/ViewModel integration |
| WorkManager | 2.12.0 | Add only for genuine deferrable background work |
| Hilt | 2.60.1 | Pinned stable artifact version; validate Gradle plugin + KSP integration in CI |
| Coil Compose | 3.6.3 | Pinned stable release; only use where image loading is needed |
| Coroutines | 1.10.2 | Kotlin coroutine runtime |
| Kotlin Serialization JSON | 1.9.0 | Backup DTOs / typed route serialization |
| JUnit | 4.13.2 | Local JVM unit tests |
| AndroidX Test JUnit | 1.3.0 | Instrumented tests |
| Espresso | 3.7.0 | Instrumented test support |
| Detekt | 1.23.8 | Static Kotlin analysis baseline |

Compose libraries are versioned through the BOM. Do not assign independent Compose versions unless a documented compatibility reason requires an override.

## Compatibility checks before locking

1. Compose November 2026 release states BOM 2026.11.01 requires compileSdk 37.1 and Kotlin 2.2 or newer. The current AGP stable docs list AGP 9.5.0 and Gradle 9.6.0; confirm SDK 37.1 is accepted by the chosen installed AGP/SDK packages in CI.
2. Confirm Hilt 2.60.1 plugin + KSP 2.3.12 works with Kotlin 2.4.21 and AGP 9.5.0. If not, pin the latest mutually compatible stable pair; do not force a build through experimental flags.
3. Verify Coil 3.6.3 resolves from Maven Central and is needed by an actual screen before adding it to feature dependencies.
4. If any dependency forces an unstable transitive version or toolchain downgrade, stop and document the compatibility decision.
5. No dynamic dependency selectors (for example `9.5.+`) are allowed.

## Official references

- Compose November 2026 stable release and BOM requirements: https://developer.android.com/blog/posts/jetpack-compose-november-2026-release
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

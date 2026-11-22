# Build and Release — Native Android

> The native build foundation is under construction. This document records current configuration, not a release-ready claim.

## Project layout

The native Android Gradle project is rooted at `android/`. The legacy Flutter source remains in the repository as the functional reference and migration source; the new Gradle settings no longer include the Flutter Gradle plugin.

## Current Android configuration

| Setting | Current value |
|---|---|
| Application ID | `com.mzarmehi1390.darsyar` |
| Namespace | `com.mzarmehi1390.darsyar` |
| minSdk | 23 (Android 6.0) |
| compileSdk | 37 |
| targetSdk | 36 |
| versionCode | 2 |
| versionName | 1.1.0 |
| JDK | 17 |
| Gradle | 9.6.0 |
| Android Gradle Plugin | 9.5.0 |
| Kotlin | 2.4.21 |

The Compose November 2026 BOM requests compileSdk 37.1. The current project is pinned to compileSdk 37; this minor API-level compatibility must be confirmed by the native CI build. Do not consider the dependency baseline locked until the build passes.

## Build from a developer machine

Requirements:
- JDK 17.
- Android SDK with API 37 platform and build tools.
- Gradle 9.6.0 available on PATH.
- Android SDK environment variables configured.

From repository root:

```bash
cd android
gradle --no-daemon :app:assembleDebug
gradle --no-daemon test
gradle --no-daemon lint
```

The repository currently contains Gradle wrapper properties but does not yet track the Gradle wrapper launcher scripts/JAR. Until the wrapper is added and verified, use an installed Gradle 9.6.0 distribution.

## CI

Workflow: `.github/workflows/android-native-ci.yml`

The workflow:
1. Checks out the branch.
2. Installs JDK 17.
3. provisions Gradle 9.6.0.
4. accepts Android SDK licenses and installs API 37/build tools.
5. runs debug APK assembly, unit tests and Android Lint.
6. uploads the debug APK only after successful validation.

The old Flutter CI remains on main and is not evidence of native build health.

## Signing and in-place upgrade risk

The application ID remains unchanged, but Android only permits an in-place update when the new APK is signed with the same signing identity as the installed app (and version code is higher). The original release keystore is not assumed available in CI. Do not publish or distribute an upgrade APK until signing-key continuity is verified. A debug-signed CI APK is a validation artifact, not a production release.

## Release checklist

- [ ] Gradle wrapper launcher and JAR committed and verified.
- [ ] Native CI passes.
- [ ] minSdk/targetSdk support policy confirmed.
- [ ] Original release signing identity verified.
- [ ] Migration from the last Flutter release tested on a device.
- [ ] Backup/restore tested.
- [ ] Release APK and AAB built and install-tested.
- [ ] No Flutter runtime or Dart build step is required by native CI.

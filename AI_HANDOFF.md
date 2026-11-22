# AI Handoff — DarsYar Native Android Rebuild

## Current objective

Rebuild DarsYar as a fully native Android application in Kotlin + Jetpack Compose. This is a functional and architectural reconstruction, not a Flutter port or a visual prototype.

## Repository state

- Repository: https://github.com/Mzarmehi1390/DarsYar
- Default branch: `main`
- Audited base: `cb0e9affcf2486c42dd146a66044c0f5fd34ca40`
- Active work branch: `feat/native-android-rebuild`
- Original application ID: `com.mzarmehi1390.darsyar`
- Current production implementation on main is Flutter.
- Do not commit native work to `main` until a reviewed, tested PR is ready.

## Read these first

1. `docs/NATIVE_REBUILD_AUDIT.md`
2. `docs/FEATURE_INVENTORY.md`
3. `docs/REDESIGN_AUDIT.md`
4. `docs/LIQUID_GLASS_DESIGN_SYSTEM.md`
5. `README.md`

The first two documents describe the native migration baseline. The existing redesign docs describe current Flutter visuals and behaviors; they are references, not native architecture constraints.

## Non-negotiable product contracts

- Preserve every item in `docs/FEATURE_INVENTORY.md`.
- Android only; do not add iOS builds or Apple frameworks.
- Kotlin + Jetpack Compose only; no Flutter runtime, Dart, WebView or hybrid UI.
- Preserve application ID exactly.
- Do not delete the Flutter implementation until native feature parity and migration have been validated. Keep `main` as a recoverable source of truth.
- No destructive persistence migration. Preserve the v1 JSON backup importer.
- Persian/RTL, light/dark/system themes and reduced-motion preference must work.
- Liquid Glass must not be mislabeled: blur and opacity alone are not refraction. Prove backdrop sampling and fallbacks in a showcase first.
- Dense study content prioritizes legibility over material effects.
- Do not claim a build, test, performance number or device validation without actual evidence.

## Workflow

1. Inspect current branch and synchronize with latest main before starting a new stage.
2. Read the current phase docs and inspect relevant source files before changing them.
3. Implement a coherent, reviewable stage; avoid tiny cosmetic batches and avoid huge unvalidated rewrites.
4. Run relevant unit/integration/UI tests and static checks.
5. Inspect the diff and update docs to reflect what is actually implemented.
6. Commit focused changes to `feat/native-android-rebuild`; keep main stable.
7. Report exact commit, changed files, tests executed, outcomes, and remaining risks.
8. Do not claim continuous background work or work outside the active execution session.

## Phase status

- Phase 1 — Repository audit: initial audit and inventory documented in `docs/NATIVE_REBUILD_AUDIT.md` and `docs/FEATURE_INVENTORY.md`.
- Phase 2 — Architecture and technical design: next.
- Phases 3–10: not started.

## Important unresolved decisions

- Explicit minSdk / compileSdk / targetSdk and support matrix.
- Confirm exact legacy Android SharedPreferences file/key representation from the locked plugin and a real installation.
- Confirm release keystore continuity for in-place updates.
- Prove AGSL backdrop sampling architecture on supported Android versions.
- Final module graph and Room schema.
- Whether the native app will keep v1 backup export or only v1 import + a newer explicit export schema.

Do not guess these. Investigate and document decisions before implementation.

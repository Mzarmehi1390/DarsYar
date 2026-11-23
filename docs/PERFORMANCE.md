# Native Performance Engineering Plan

> Targets and measurement plan only. No native performance result has been measured yet. The current code is still a foundation build; no on-device profile exists.

## Principles

- Optimize from traces and repeatable measurements, not intuition.
- Keep business work and disk operations off the main thread.
- Keep frequently changing state local to the smallest possible Compose subtree.
- Use immutable UI state and stable list keys.
- Keep dense planner/exam content on solid surfaces; glass is limited to bounded visual chrome.
- Do not reduce quality or disable animation solely to make a benchmark pass.

## Graphics budget

Measure:
- AGSL shader compile/prewarm time.
- Backdrop acquisition and invalidation cost.
- GPU overdraw and offscreen render passes.
- Shader texture reads and memory bandwidth.
- Layer/bitmap allocation and cache retention.
- 60/90/120 Hz frame pacing where supported.
- Scroll jank with long task/session and question collections.
- Battery impact of repeated invalidation.

No unbounded bitmap cache. No full-screen blur by default. No per-frame shader recompilation. No recursive backdrop capture.

## Benchmark scenarios

1. Cold start from process death.
2. Warm start from background.
3. Navigate through all four primary destinations.
4. Scroll planner with 100+ synthetic sessions/tasks.
5. Open an exam with 200 questions and move through the question navigator.
6. Toggle answers and review marks.
7. Open/close sheets and dialogs with the keyboard visible.
8. Render one focal glass surface over the ambient backdrop.
9. Animate selected glass controls.
10. Run fallback renderer on a device/API without AGSL.

## Reporting format

Every reported number must include:
- Device model and SoC.
- Android version/API level.
- Display refresh rate.
- Build variant and commit SHA.
- Benchmark scenario and repetitions.
- Median and tail latency/frame-time metrics.
- Memory observations and any thermal throttling.

## Acceptance targets

- Aim for 60 FPS on supported 60 Hz devices and higher refresh rates where sustainable.
- Avoid sustained frame drops and main-thread stalls.
- Maintain smooth scrolling and responsive touch feedback.
- No material memory growth after repeated navigation.
- Preserve readable text and correct fallback behavior.

These are engineering targets, not measured claims.

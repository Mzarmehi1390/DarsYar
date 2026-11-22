# DarsYar Native Liquid Glass Engine

> Phase 2 technical design. The renderer and shaders are not implemented or hardware-validated yet.

## 1. Visual contract

The goal is a calm, premium optical material inspired by the principles of modern Liquid Glass:
- visible light transmission and background color influence;
- localized distortion/refraction of an explicitly supplied backdrop;
- restrained specular reflection and edge illumination;
- curved depth cues and layered tint;
- responsive press/selection state;
- light/dark adaptive material parameters.

Blur, alpha, gradients and a white stroke alone are not Liquid Glass. If a rendering path cannot sample a real backdrop, it must be described as a fallback material, not refraction.

Dense study content remains on solid, high-contrast surfaces. Refractive material is reserved for bounded navigation chrome, focal hero surfaces, compact controls and selected modal surfaces.

## 2. Android rendering facts and constraints

- AGSL `RuntimeShader` is available on Android 13 / API 33 and later.
- `RenderEffect` is available on Android 12 / API 31 and later.
- A RuntimeShader does not automatically receive arbitrary pixels from behind a Compose node.
- RenderEffect can apply effects to a rendered layer; it does not by itself provide arbitrary backdrop capture.
- A shader needs an explicit input (for example a bitmap/image shader or another shader) for the background it distorts.
- Compose graphics layers can isolate drawing and support offscreen rendering/capture, but capture frequency, invalidation, memory and feedback loops must be designed deliberately.

Therefore the implementation must not ship a "refraction" API that only blurs the glass surface itself.

## 3. Proposed rendering layers

### A. Material tokens

Centralize:
- material strength (subtle / standard / focal);
- tint by light/dark theme;
- transmission/opacity;
- refraction displacement scale;
- specular intensity and direction;
- edge-light width/intensity;
- corner geometry;
- shadow/elevation;
- press/selected/disabled state;
- fallback quality.

No screen should hardcode shader constants.

### B. Backdrop contract

Define a small graphics API conceptually similar to:
- `GlassBackdropSource`: owns a known backdrop image/shader and invalidation policy.
- `GlassMaterialSpec`: immutable parameters for one material role.
- `GlassSurface`: draws a bounded surface using backdrop input when available.
- `GlassFallback`: high-quality non-refraction treatment for unsupported devices or unavailable backdrop capture.

Backdrop sources must be explicit and owned by the scene/root. They must not attempt to discover or sample arbitrary Compose siblings.

### C. AGSL material

The AGSL shader receives:
- source backdrop shader/image;
- surface-local coordinates and bounds;
- normalized surface shape/mask;
- light direction/intensity;
- material parameters.

The shader can then:
1. map surface-local coordinates into backdrop coordinates;
2. calculate a restrained normal/curvature approximation;
3. offset the backdrop sample for localized refraction;
4. apply controlled transmission/tint;
5. add edge Fresnel-like illumination and specular response;
6. preserve alpha/mask outside the rounded surface.

The exact shader model is a technical spike deliverable. Avoid expensive per-pixel loops and multiple redundant texture samples.

### D. Compose integration

- Use `Modifier.graphicsLayer` and bounded drawing layers where they materially help.
- Keep glass surfaces clipped to their own bounds.
- Avoid full-screen offscreen effects.
- Cache immutable shader programs; update uniforms rather than recompiling shaders on animation frames.
- Keep high-frequency animation state local to the material.
- Provide semantics and click handling independently of the drawing layer.
- Do not use a nested glass surface inside another refractive surface unless a specific design has been profiled.

## 4. Backdrop acquisition strategy

The first prototype should use a deterministic, explicitly owned ambient scene shader/image as the backdrop. This proves the shader's optical behavior without claiming arbitrary content capture.

A second spike may evaluate capturing a bounded Compose background layer for dynamic surfaces. Acceptance requires:
- no recursive capture of the glass surface itself;
- no feedback/invalidation loop;
- controlled capture frequency;
- no unbounded bitmap allocation;
- correct resizing and lifecycle cleanup;
- measurable frame-time and memory impact;
- a clean fallback when capture is unavailable.

If arbitrary dynamic backdrop capture is too expensive or unstable, keep true refraction on the ambient/focal surfaces and use a clearly named translucent/specular fallback for dynamic navigation over changing content. Do not fake the capability.

## 5. Component roadmap

Build shared primitives first:
- GlassSurface / GlassCard
- GlassButton / GlassIconButton
- GlassNavigationBar / GlassNavigationItem
- GlassModal / GlassBottomSheet / GlassDialog
- GlassTextField / GlassSearchField
- GlassToolbar / GlassTabBar / GlassSegmentedControl
- GlassFloatingActionButton
- GlassProgressIndicator
- GlassSelectionControl / GlassDropdown / GlassTooltip

These are component contracts; each component should be added only when used by a real screen. Shared material tokens and rendering path are mandatory.

## 6. Fallback matrix

| Capability | API 33+ | API 31–32 | Below API 31 |
|---|---|---|---|
| AGSL RuntimeShader | Available | Not available | Not available |
| RenderEffect | Available | Available | Not available |
| True backdrop refraction | Only with explicit backdrop source | Use non-AGSL path or fallback | Fallback |
| Material fallback | Always available | Always available | Always available |

Do not choose the app's minSdk solely from shader availability. The app must remain usable on fallback devices. Exact minSdk is a platform decision to be resolved with distribution requirements.

## 7. Performance and visual validation

Measure on physical devices:
- shader compile/prewarm cost;
- cold and warm screen entry;
- frame timing during scroll and transitions;
- GPU overdraw and offscreen passes;
- capture cost and memory footprint;
- animation frame pacing at 60/90/120 Hz where supported;
- fallback visual quality on older APIs.

Test scenes:
1. Static ambient backdrop with one focal glass surface.
2. Floating navigation over a changing scroll surface.
3. Press/selected animations on compact controls.
4. Modal over a dimmed scene.
5. Light and dark themes.
6. Long Persian labels and font scaling.
7. Reduced-motion mode.

Acceptance requires screenshots/video from identified devices and a written measurement report. A successful shader compile is not visual or performance validation.

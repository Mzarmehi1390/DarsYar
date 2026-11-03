# DarsYar Liquid Glass Design System

This document records the shared visual contract for the application-wide redesign.
The implementation lives in `lib/design_system/`; screen-specific widgets should
consume these tokens instead of introducing unrelated material values.

## Product direction

DarsYar should feel like a calm, native-feeling iOS environment while retaining its own study-focused identity. Use Apple's Liquid Glass language as the visual reference: optical translucency, local background refraction, dimensional edge highlights, soft specular reflections, layered color and fluid state changes. This is an iOS-inspired implementation on Flutter/Android, not a claim to reproduce Apple's private rendering stack. Content, controls and study information remain the visual priority.

## Color foundations

| Role | Light | Dark |
| --- | --- | --- |
| Accent | `#16A36A` | `#75D9A5` |
| Secondary | `#5B83B6` | `#9BC4E8` |
| App background | `#E9F0F8` | `#0B1422` |
| Canvas | `#F3F7FC` | `#101D2D` |
| Surface | `#F8FBFF` | `#192A3D` |
| Raised surface | `#E3EDF7` | `#263D54` |
| Primary text | `#172536` | `#EAF3FC` |

Semantic colors must continue to communicate success, warning and error
independently of the accent color. Text contrast takes priority over translucency.

## Shape and spacing

- Small radius: 12 dp
- Medium radius: 18 dp
- Large radius: 22 dp
- Extra-large radius: 28 dp
- Primary page horizontal padding: 20 dp
- Shared bottom navigation content clearance: 124 dp

Use the closest token for new controls. A different radius is allowed only when
the component geometry requires it.

## Material roles

- **Focal glass:** the dashboard hero, rendered with the package's premium shader material.
- **Navigation glass:** the floating iOS-style tab capsule and its liquid selection lens.
- **Control glass:** planner weekday chips, segmented selectors, switches, pull-down menus and action buttons.
- **Icon glass:** compact page-header icon wells, using standard quality.
- **Content surfaces:** task rows, study-session rows, result cards, summaries, settings groups and exam setup panels use solid `DarsYarContentSurface` fills. This keeps long Persian copy and numeric data readable.
- **Modal glass:** use `GlassDialog` for short confirmations and `GlassModalSheet` for multi-field editors, answer-key lists and pickers. Use a Cupertino wheel picker inside a glass sheet for time selection.

The app now uses `liquid_glass_widgets` 1.16.1 with its `GlassThemeData.ios27()` preset, shader prewarming, adaptive quality and `GlassScaffold` + `GlassTabBar.bottom` navigation. Planner weekday chips use `GlassChip`, the exam-mode and theme selectors use `GlassSegmentedControl`, and the study-session weekday selector uses its scrollable variant. Primary actions use `GlassButton`, compact edit/delete actions use `GlassIconButton`, and overflow actions use `GlassPullDownButton`. The dashboard hero and primary page-header icon wells use the library's shader-backed `GlassContainer` material; the bottom navigation uses its liquid selected indicator. Dense study lists, summaries, settings groups and exam setup panels use `DarsYarContentSurface` with solid, high-contrast fills. This follows iOS's separation between refractive navigation/control chrome and readable content surfaces.

## Typography

Use the platform's readable Persian-capable sans-serif fallback. Do not force a
Latin-only font. The shared page header uses a 26 sp title and 12.5 sp supporting
text, with a shader-glass icon well. Screen titles, section titles, body text, labels and numeric metrics should
remain distinct through size and weight rather than color alone.

## Atmospheric background and focal surfaces

- Use a cool, softly layered blue/green/violet ambient background so glass can pick up visible color variation.
- The dashboard hero is a shader-backed, elevated focal glass surface, not an opaque gradient banner.
- Planner weekday selectors use `GlassChip`; the exam destination selector uses `GlassSegmentedControl` with a fluid glass indicator.
- Do not place refractive controls inside refractive cards. A solid content surface may contain a glass control; a glass hero may contain ordinary text and non-glass icon treatments.
- Page-header icon wells use small independent shader-glass surfaces; they do not contain nested glass controls.
- Keep the highest contrast in text and actionable controls; reflections stay near material edges and must not cross important copy.
- Summary cards switch to a two-column wrap on compact widths instead of compressing Persian labels into narrow columns.

## Motion

- Page transitions: 190 ms, ease-out/ease-in cubic, low-amplitude vertical offset.
- Bottom navigation selection: 180 ms, ease-in-out cubic.
- Local progress and selection changes: short, non-repeating transitions.
- When `MediaQuery.disableAnimations` is true, page and navigation transitions
  must resolve immediately.
- Avoid continuous decorative animation and avoid movement that delays input.

## Navigation and safe areas

The bottom navigation is a floating shader-backed `GlassTabBar.bottom` capsule with a liquid selected indicator, Persian TalkBack labels and adaptive rendering quality. It intentionally follows the iOS floating-capsule pattern rather than the previous custom center notch. `GlassScaffold` owns bar z-ordering and bottom edge fading; page scroll padding remains sufficient to prevent the final content row from being obscured.

## Accessibility and localization

- Preserve RTL at the app root.
- Keep labels and control semantics in Persian.
- Keep selected navigation state exposed to assistive technology.
- Preserve the no-flash tap feedback policy.
- Keep touch targets comfortably usable.
- Maintain readable contrast in both themes.
- Respect reduced-motion preferences.

## Performance rules

- Prefer the package's shader-backed glass for floating controls, page-header icon wells, the dashboard focal hero and navigation.
- Keep dense study content on solid grouped surfaces.
- Use adaptive quality and retain a standard/minimal fallback on slower devices.
- Blur only bounded surfaces.
- Prefer the package's shared glass layer over nested independent glass renderers.
- Do not use manual `BackdropFilter` surfaces as a substitute for the iOS 27 shader material.
- Keep expensive effects out of large scrolling regions.
- Do not add perpetual animation or unnecessary stateful rebuilds.
- Validate scrolling and animation on a physical Android device before release.

## Change acceptance

A screen change is accepted only when it preserves the screen's existing actions,
storage behavior and navigation, works in light and dark themes, remains RTL,
and introduces no analyzer, widget-test or release-build regression.

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

- **Primary glass:** default cards, task rows, study-session rows and result cards.
- **Secondary glass:** compact summaries and supporting information.
- **Elevated glass:** important grouped panels such as exam setup and weekly reports.
- **Navigation glass:** the bottom dock, with its own notch and selected-item treatment.
- **Modal surfaces:** dialogs, popup menus, bottom sheets, time pickers and date pickers
  share the same rounded geometry, theme-aware surfaces, restrained elevation and
  high-contrast text. These defaults are centralized in `DarsYarTheme` so
  transient UI does not drift between features.

The shared `DarsYarGlassSurface` now uses a bounded 15 dp blur by default, a translucent three-stop material gradient, a bright upper specular line, a faint lower rim, a small reflected bloom and a soft contact shadow. Elevated focal surfaces may opt into a stronger local blur (for example, the dashboard hero at 20 dp). Keep all blur clipped to the material bounds; never blur the full scrolling page. Do not nest glass surfaces unless the inner surface is a genuinely separate control or floating object.

## Typography

Use the platform's readable Persian-capable sans-serif fallback. Do not force a
Latin-only font. The shared page header uses a 24 sp title and 12.5 sp supporting
text, with a glass icon well. Screen titles, section titles, body text, labels and numeric metrics should
remain distinct through size and weight rather than color alone.

## Atmospheric background and focal surfaces

- Use a cool, softly layered blue/green/violet ambient background so glass can pick up visible color variation.
- The dashboard hero is a translucent elevated glass surface, not an opaque gradient banner.
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

The bottom dock remains predictable, keeps its selected destination exposed to
semantics, and must not cover the final content row. The glass material ends
before the device's bottom safe-area inset so that the gesture/navigation inset
does not become an opaque blurred strip.

## Accessibility and localization

- Preserve RTL at the app root.
- Keep labels and control semantics in Persian.
- Keep selected navigation state exposed to assistive technology.
- Preserve the no-flash tap feedback policy.
- Keep touch targets comfortably usable.
- Maintain readable contrast in both themes.
- Respect reduced-motion preferences.

## Performance rules

- Blur only bounded surfaces.
- Prefer the shared material over nested BackdropFilters.
- Keep expensive effects out of large scrolling regions.
- Do not add perpetual animation or unnecessary stateful rebuilds.
- Validate scrolling and animation on a physical Android device before release.

## Change acceptance

A screen change is accepted only when it preserves the screen's existing actions,
storage behavior and navigation, works in light and dark themes, remains RTL,
and introduces no analyzer, widget-test or release-build regression.

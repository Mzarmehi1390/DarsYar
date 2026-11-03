# DarsYar Liquid Glass Design System

This document records the shared visual contract for the application-wide redesign.
The implementation lives in `lib/design_system/`; screen-specific widgets should
consume these tokens instead of introducing unrelated material values.

## Product direction

DarsYar should feel calm, focused and precise. Liquid Glass is used to establish
depth and hierarchy, not as decoration on every pixel. Content, controls and
study information remain the visual priority.

## Color foundations

| Role | Light | Dark |
| --- | --- | --- |
| Accent | `#16A36A` | `#75D9A5` |
| Secondary | `#4B849C` | `#8DBBD0` |
| App background | `#EAF2EE` | `#08130F` |
| Canvas | `#F3F8F5` | `#0D1A14` |
| Surface | `#F9FCFA` | `#14251D` |
| Raised surface | `#E5F0E9` | `#20372B` |
| Primary text | `#14231D` | `#EAF5EE` |

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

The shared `DarsYarGlassSurface` uses a bounded blur (8 dp by default), a subtle
edge highlight, a restrained gradient and a soft shadow. Do not put a full-screen
blur behind scrolling content. Avoid stacking multiple blur layers around one
component.

## Typography

Use the platform's readable Persian-capable sans-serif fallback. Do not force a
Latin-only font. The shared page header uses a 23 sp title and 12 sp supporting
text. Screen titles, section titles, body text, labels and numeric metrics should
remain distinct through size and weight rather than color alone.

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

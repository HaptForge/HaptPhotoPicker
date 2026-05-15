# Changelog

## 0.2.0 — 2026-05-15

Feature pass — the picker now actually edits. v0.1.x exposed crop
chrome but the bytes returned were untouched; users tapped Done
expecting the cropped output they'd just framed and got the raw
asset. v0.2.0 closes that loop end-to-end, plus the three top-bar
papercuts from production feedback.

### Added

- **Interactive crop preview** — pinch-to-zoom (1.0×–4.0×) + pan
  via `InteractiveViewer`, 90° clockwise rotation button overlaid
  top-right, rule-of-thirds grid fades in during interaction. Each
  selected asset retains its own pan / zoom / rotation state keyed
  by asset id, so the user can flip among selections and resume
  where they left off on each.
- **Aspect-ratio enforcement** — the chosen `HaptAspectRatio`
  (original / square / portrait / landscape / custom) is now a
  hard frame inside the preview, and the same ratio drives the
  exported crop rect at Done. Changing the ratio resets the
  featured asset's transform — pan/zoom relative to the old frame
  shape wouldn't translate cleanly to the new one.
- **`HaptCropEngine`** — pure-Dart crop + rotation pipeline (uses
  the `image` package, no native bridges) that runs as the first
  step of the Done-tap pipeline. Returns JPEG-encoded `Uint8List`
  reflecting exactly what the user saw in the preview. Composes
  with any registered `HaptAssetTransform`s — crop runs first, then
  watermark / exif-strip / etc. consume the cropped bytes.
- **Per-asset crop state** (`HaptCropState`) — snapshotted into
  `HaptPickerResult` so consumers who don't want the `image`-package
  path can reconstruct the crop themselves from scale + translation
  + rotation quarters.

### Changed

- **Top bar layout** — fixed 92px slots on either side of the
  centered title means the layout no longer reflows as the
  selection count changes. Button typography bumped from 13px
  body to 15px button — the prior size read as a placeholder.
- **Single-pick selection badge** — when `maxSelection == 1`,
  badges render a check icon instead of the digit `1`. A number
  in a one-slot picker reads as noise.
- **Done label** — single-pick mode no longer surfaces the count
  in the label. "Done" on its own is clearer when there's only
  one slot.

### Dependencies

- Added `image: ^4.2.0` for the pure-Dart crop engine.

## 0.1.1 — 2026-05-15

First production-test polish pass — three visual bugs surfaced
while integrating into a real app.

### Fixes

- **Crop preview layout** — was using a raw `AspectRatio` against
  the asset's intrinsic ratio. A portrait screenshot (9:19.5)
  blew the preview up to ~780 px tall, pushing the asset grid
  off-screen. Now wrapped in a `ConstrainedBox(maxHeight: 38%
  viewport)` so the grid always stays visible.
- **Album list polish** — added a 56×56 cover thumbnail per row
  (lazy-loads the album's first asset), with thousands-separator
  count formatting (`5,134` instead of `5134`), drag handle on
  the sheet, and `InkWell` ripple on row tap. Was previously a
  plain `ListTile` — looked half-finished.
- **Done button states** — replaced the single washed-out
  `Opacity(0.4)` disabled treatment with two distinct visual
  states. Enabled: filled wine pill, white label, brand shadow.
  Disabled: transparent fill, primary outline at 40% alpha,
  primary-tinted label. Reads as "tap a thumbnail first" rather
  than "the button is broken". `AnimatedContainer` 180ms
  ease-out for the state transition.

## 0.1.0 — 2026-05-15

Initial release. Foundation + v0.1 differentiators.

### Foundation
- Token-based theming system (`HaptPickerTheme`) — every color,
  font, spacing, radius, shadow is a typed token. Override one
  field, inherit the rest from `HaptPickerTheme.light()` /
  `.dark()` / your own preset.
- Multi-language strings (`HaptPickerStrings`) — abstract base
  class + 9 built-in locales (en/vi/es/fr/de/pt/ja/ko/ar). App
  developers ship their own subclass to override every line.
- Configurable `HaptPickerConfig` — max selection, allowed media
  types, aspect-ratio palette, initial album.
- Asset + album wrappers (`HaptAsset`, `HaptAlbum`) decoupled
  from `photo_manager` so consumers never import third-party
  types.

### Differentiators
- Haptic choreography (`HaptHaptics`) — every interaction
  (select / deselect / scroll edge / max-reached / snap) fires a
  signature haptic. Globally togglable. iOS uses the Core Haptics
  taxonomy; Android falls back to the standard amplitude levels.
- Hero morph transitions between thumbnail → preview → crop.
- Pluggable post-processing pipeline — register `HaptAssetTransform`
  callbacks that run before assets are returned to the caller
  (auto-correct, sticker, watermark, etc.).

### Known gaps (planned for 0.2)
- Magnetic crop snapping (face / horizon / thirds)
- Burst-aware selection group
- Live filter preview in the grid
- Smart album auto-grouping (EXIF / GPS / faces)
- Built-in collage builder
- One-handed mode

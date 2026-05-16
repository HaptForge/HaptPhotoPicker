# Changelog

## 0.4.0 — 2026-05-16

Scope correction on the strings surface.

### Breaking

- **Removed the 8 non-English locale subclasses** (`HaptPickerStringsVi`,
  `Es`, `Fr`, `De`, `Pt`, `Ja`, `Ko`, `Ar`). Localization is the
  consumer's responsibility — most apps already have a JSON / ARB /
  intl pipeline, and the library wedging its own set of translations
  into that creates a second source of truth that drifts. The
  override surface (every string is a getter on
  `HaptPickerStrings`) is unchanged — apps now wire the picker
  strings from their own l10n layer.
- **Migration**: replace any `HaptPickerStringsVi()` etc. with your
  own subclass that pulls every getter from your app's translations:
  ```dart
  class MyPickerStrings extends HaptPickerStrings {
    MyPickerStrings(this.s);
    final AppStrings s;
    @override String get pickerTitle => s.pickerTitle;
    // …override every getter.
  }
  ```

### Kept

- `HaptPickerStrings` (abstract base — no defaults, missed
  overrides fail at compile time).
- `HaptPickerStringsEn` (English defaults — usable as-is for
  English, or subclass to tweak a line or two).

## 0.3.0 — 2026-05-16

Correctness pass on the editing primitives + the v0.2 "Known gaps"
list collapsed to a single bullet (real-time filter presets).

### Fixed

- **Crop math is now pixel-accurate.** v0.2's `HaptCropEngine` had
  a literal `pxRatio = h / 1000.0` heuristic for mapping the
  InteractiveViewer's translation back to source pixels — the
  comment in code admitted "isn't pixel-perfect for extreme pans".
  v0.3 wires the crop preview's real laid-out viewport size through
  to the engine (via `HaptPickerController.setPreviewViewportSize`,
  set by a `LayoutBuilder` inside the preview) and reconstructs the
  exact visible rect via cover-fit scale + inverse-transform
  geometry. The exported bytes now reflect what the user framed, not
  an approximation of it.

### Added

- **Color filter presets.** New `HaptFilter` value type
  parameterized by saturation / contrast / brightness / exposure.
  The same params drive both the live preview's `ColorFilter.matrix`
  AND the export's `image.adjustColor` — so the chip thumbnail you
  tap looks like the final output (within ~2% perceptual).
- Ships 8 default presets covering the neutral baseline + 7
  Instagram-class looks: **Original, Mono, Vivid, Warm, Cool,
  Bright, Vintage, Noir**. Override the catalog by passing your own
  list to `HaptPickerConfig(filters: [...])`; pass
  `const [HaptFilter.original]` to hide the strip entirely.
- **Filter strip UI** — horizontal scroll of live-preview chips
  beneath the crop preview. Each chip renders the active asset's
  64-px thumbnail wrapped in that filter's matrix, so the chip
  thumbnails always match the user's selected photo (not generic
  reference shots).
- **Per-asset filter state** — like the existing crop transform,
  the chosen filter is stored on `HaptCropState.filter` keyed by
  asset id. Switching among selected items resumes each one's
  filter where it left off.
- Localized filter labels via `HaptPickerStrings.filterLabel(String
  id)` — implementations shipped for all 9 built-in locales.

### Known gaps (planned for 0.4)

- Free-form crop (drag corners to crop tighter than the chip ratio)
- Straighten slider (rotate by 1° increments)
- Per-filter intensity slider
- Burst-aware selection grouping
- Live filter preview in the asset grid (not just the crop preview)
- One-handed mode

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

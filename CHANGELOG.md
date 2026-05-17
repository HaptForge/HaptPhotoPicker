# Changelog

## 0.7.1 — 2026-05-18

Two follow-up fixes to 0.7.0 surfaced by real-device QA.

### Fixed

- **Single-pick mode could lock out tap-to-replace.** When the
  auto-select bootstrap shipped in 0.7.0 ran, the picker became
  permanently `atMax` (1/1 selected) — and the grid cell's
  `disabled` flag treated that as "no more slots open" for every
  other thumbnail, so users couldn't tap a different photo. The
  grid now only gates on `atMax` when `maxSelection > 1`; in
  single-pick mode the cell stays tappable and `toggle` handles
  the swap via its existing tap-to-replace branch.

### Changed

- **Crop tool panel drill-down rewrite.** 0.7.0 stacked all four
  Crop affordances (Rotate / Flip H / Flip V / Straighten dial /
  aspect chips) in the same view, which pushed the asset grid
  below it off-screen on smaller phones — exactly the opposite of
  Apple's "general → specific" pattern.

  The Crop panel now has a single 36 px toolbar with five icon
  buttons:
  - **Aspect** (toggle) — opens the aspect-ratio chips below
  - **Straighten** (toggle) — opens the fine-rotation dial below
  - **Rotate 90°** (action) — fires on tap, no detail surface
  - **Flip H** (action) — fires on tap
  - **Flip V** (action) — fires on tap

  Only ONE detail surface is visible at a time (chips OR dial),
  so the panel stays the same height regardless of which tool the
  user has open. The asset grid keeps its real estate.

## 0.7.0 — 2026-05-18

Three quality-of-life fixes that smooth out the editor + gallery
surface for production use.

### Added

- **Fine-grained rotation dial** in the Crop tool panel. Apple-style
  horizontal tick rail with a centred indicator; drag left/right to
  rotate the image up to ±45° in 1° increments. Per-degree haptic
  tick + 0.5° dead-zone snap at centre lets users return to "no
  rotation" by feel alone. Numeric readout shows the current angle.
  New `HaptCropState.rotationFine` (double, default 0.0) carries the
  value; the crop engine composes it with `rotationQuarters` into a
  single `copyRotate` call on Done. Discrete 90° rotation via the
  existing rotate button is unchanged.

### Changed

- **Single-pick mode is now zero-empty-state.** The picker auto-
  selects the newest asset on first album load when
  `maxSelection == 1`, so the Done button is enabled the moment the
  sheet opens and the crop preview shows actual content instead of
  a placeholder. Tapping a different thumbnail swaps the selection
  (already existed); tapping the currently-selected thumbnail is
  now a no-op (previously it deselected, leaving the picker in an
  empty state — confusing in a single-pick context). Multi-pick
  semantics are unchanged.
- **Sheet chrome stands apart from the asset grid.** Header now sits
  on the theme's `surfaceElevated` token + a 0.5 px bottom hairline,
  so the Cancel / Album / Done row no longer merges visually into
  the gallery. Both light and dark themes pick up the change
  automatically; no consumer migration needed.
- **Asset-grid thumbnails decode at most once per asset.** The grid
  cell widget is now a `StatefulWidget` that caches its decode
  `Future` for the lifetime of the cell + uses
  `AutomaticKeepAliveClientMixin` so offscreen cells aren't disposed
  and re-decoded on scroll-back. The previous `StatelessWidget +
  inline FutureBuilder` re-fired the decode on every parent rebuild
  (selection badge update, scroll, theme switch) — the primary
  cause of grid jank on long albums.

## 0.6.0 — 2026-05-17

Closes the "photo editor parity" gap — three new tools land in the
editor surface that v0.5 introduced the tab strip for.

### Added

- **Adjust tab (3rd tool)** — four sliders for manual color
  grading: Brightness, Contrast, Saturation, Exposure. Each
  slider's label is tappable to snap the value back to its
  identity (1.0 for multiplicative, 0.0 for exposure). A Reset
  button below the sliders zeroes all four at once when any are
  active. Reuses the existing `HaptFilter` value type as the
  state struct so there's no second param-channel to maintain.
- **Filter intensity slider** — appears under the filter strip
  in the Filter tab whenever a non-identity preset is selected.
  Slides 0–100%; interpolates the preset's params toward identity
  by `(1 − intensity)`. Lets users dial back e.g. Vivid from
  "Instagram-loud" to "just slightly punchy".
- **Flip horizontal / vertical buttons** in the Crop tab's
  action row, alongside Rotate. Apply as `Transform.scale` in
  the live preview (zero CPU) + `img.flipHorizontal` /
  `img.flipVertical` in the engine on Done.
- `HaptFilter.compose({preset, intensity, adjustments})` — pure
  static helper that combines a preset (scaled by intensity)
  with the user's manual adjustments into a single final
  `HaptFilter`. Used by both the live preview's `ColorFiltered`
  and the engine's `img.adjustColor` so the two stay byte-for-
  byte (within ~2%) consistent.
- Controller methods to drive the new state:
  `setFilterIntensityForFeatured`, `setAdjustmentsForFeatured`,
  `toggleFlipHForFeatured`, `toggleFlipVForFeatured`.
- New abstract strings on `HaptPickerStrings`: `editorToolAdjust`,
  `editorActionRotate / FlipH / FlipV`, `editorFilterIntensity`,
  `editorAdjustBrightness / Contrast / Saturation / Exposure`,
  `editorAdjustReset`. English defaults shipped.

### Changed

- **Rotate button moved out of the canvas overlay** into the
  Crop tab's action row. Same affordance, but the canvas surface
  is now gesture-clean (no floating button to compete with pan/
  zoom). The 3 action buttons (Rotate / Flip H / Flip V) live
  side-by-side in a single row above the ratio chips.
- `_EditorTool` enum grows from `{ crop, filter }` to
  `{ crop, filter, adjust }`. Tab strip auto-sizes — Filter tab
  hides when the consumer config exposes < 2 filters; Crop and
  Adjust always render.

### Known gaps (planned for 0.7)

- **Straighten slider** (fine-grain rotation by 1° increments).
  Deferred because the `image` package's non-90° `copyRotate`
  produces a larger canvas with corner padding — needs an
  auto-crop to the largest interior rect for the export, and we
  want to ship that with proper math, not a hack.
- Burst-aware selection grouping
- Live filter preview in the asset grid (not just the crop preview)

## 0.5.0 — 2026-05-17

Two production-test bugs / gaps.

### Fixed

- **Single-pick mode now supports tap-to-replace.** Before:
  selecting a different photo while one was already picked
  silently failed (the controller treated it as "max reached").
  User had to deselect the current pick before tapping the new
  one — two taps for what should be one. Now: in single-pick mode
  (`maxSelection == 1`) tapping a different thumbnail clears the
  current pick + selects the new one in a single move. Multi-pick
  semantics are unchanged — that path correctly requires the user
  to explicitly deselect, because the selection ORDER matters
  there (badges render 1/2/3 of N).

### Added

- **Editor tool tabs.** v0.3/0.4 stacked the aspect-ratio chips
  and the filter strip below the crop canvas at the same time —
  the chips disappeared on small phones once filters shipped, and
  the surface read as a half-finished picker rather than a real
  photo editor. v0.5 introduces an explicit two-tab strip
  (**Crop** | **Filter**) below the crop canvas; tapping a tab
  reveals only that tool's panel. Crop shows ratio chips, Filter
  shows the live-preview strip. Both panels reuse the existing
  widgets — no behaviour change beyond visibility / discoverability.
- Two new abstract strings on `HaptPickerStrings` — `editorToolCrop`
  and `editorToolFilter`. English defaults shipped; consumer apps
  override via their existing `HaptPickerStrings` subclass.

### Layout fallback

- Tabs render only when BOTH ratios AND filters have more than
  one option each. If only ratios are configured, the chips show
  directly (no tabs). If only filters, the strip shows directly.
  If neither, the surface is empty — preserves the minimal feel
  for picker configurations that don't enable editing.

### Known gaps (planned for 0.6)

- Adjust tab (brightness / contrast / saturation / exposure sliders)
- Straighten slider (rotate by 1° increments)
- Per-filter intensity slider
- Flip horizontal / vertical buttons in the Crop tab
- Burst-aware selection grouping
- Live filter preview in the asset grid

## 0.4.1 — 2026-05-16

Smoothness pass on the crop preview + filter strip — no flicker on
filter selection, no overflow on small phones.

### Fixed

- **Main asset thumbnail no longer flickers on rebuild.** `_AssetThumb`
  was a `StatelessWidget` whose `FutureBuilder` started a fresh
  `readThumbnail` call on every parent rebuild — every filter tap
  (which fires `notifyListeners`) re-fetched the image. Converted
  to a `StatefulWidget` that captures the Future once per
  `(asset, dimensions)` tuple so the image stays mounted across
  rebuilds. `gaplessPlayback` was already there but couldn't help
  with the Future churn.
- **Filter strip no longer re-fetches per chip per rebuild.**
  Previously each of the 8 chips owned a `FutureBuilder<Uint8List?>`
  asking photo_manager for the same 120-px thumbnail on every
  rebuild. Hoisted the Future into the strip's State; the 8 chips
  now share the same bytes and just compose different
  `ColorFiltered` wrappers on top.
- **Filter strip height trimmed 78 → 66 px** so it fits the iPhone
  SE 1st-gen-class viewport without squeezing the asset grid below
  the 100-px usability floor. Chip dimensions also slimmed (46×46
  with 10-pt label) — visually denser but still readable.

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

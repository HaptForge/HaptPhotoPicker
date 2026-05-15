# Changelog

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

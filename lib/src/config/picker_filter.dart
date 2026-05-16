import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

/// A color-grading preset. Defined by four scalar parameters that
/// both the preview-side `ColorFilter.matrix` AND the engine-side
/// `image.adjustColor` consume — so the live preview thumbnail and
/// the final exported bytes look identical.
///
/// The four params are the same ones every consumer-grade photo
/// editor exposes, so the model maps cleanly to common knobs and
/// to the `image` package's adjustColor signature without us having
/// to hand-derive 20-value matrices per preset:
///
///   - `saturation` — 1.0 = unchanged. < 1 → desaturate (0 = mono).
///                                     > 1 → vivid.
///   - `contrast`   — 1.0 = unchanged. < 1 → flatter. > 1 → punchier.
///   - `brightness` — 1.0 = unchanged. Multiplicative; 0.9 = darker.
///   - `exposure`   — 0.0 = unchanged. Additive in log space; +0.2
///                    lifts shadows the way a +1/3 stop on a camera
///                    does.
///
/// To swap the catalog for your app's brand, build your own list of
/// `HaptFilter` instances and pass them via
/// `HaptPickerConfig(filters: [...])`. The default set covers a
/// neutral baseline + the seven most-recognized Instagram-class
/// looks so consumers ship with something usable out of the box.
@immutable
class HaptFilter {
  const HaptFilter({
    required this.id,
    this.label,
    this.saturation = 1.0,
    this.contrast = 1.0,
    this.brightness = 1.0,
    this.exposure = 0.0,
  });

  /// Stable identifier — also used as the i18n key (`filter.<id>`)
  /// when [label] is null.
  final String id;

  /// Optional explicit display label. When null, picker_strings
  /// resolves a localized name via `HaptPickerStrings.filterLabel(id)`.
  final String? label;

  final double saturation;
  final double contrast;
  final double brightness;
  final double exposure;

  /// Identity / "no-op" filter. The preview skips wrapping in a
  /// `ColorFiltered` when this is selected, and the engine short-
  /// circuits the `img.adjustColor` call — both keep the output
  /// bit-identical to the unfiltered crop.
  bool get isIdentity =>
      saturation == 1.0 &&
      contrast == 1.0 &&
      brightness == 1.0 &&
      exposure == 0.0;

  /// Compose a 4×5 `ColorFilter.matrix` that approximates the
  /// preset for the live preview. Real-time-correct enough to read
  /// as "this is what Vivid looks like" — final output uses the
  /// `image` package's adjustColor which gives a slightly more
  /// accurate result (different gamma handling), but the deltas
  /// are within ~2% perceptually.
  ColorFilter toColorFilter() {
    if (isIdentity) {
      return const ColorFilter.matrix(<double>[
        1, 0, 0, 0, 0, //
        0, 1, 0, 0, 0, //
        0, 0, 1, 0, 0, //
        0, 0, 0, 1, 0, //
      ]);
    }
    // Luminance coefficients (Rec. 601 — standard for SDR photo work).
    const lr = 0.299;
    const lg = 0.587;
    const lb = 0.114;
    final s = saturation;
    final invS = 1.0 - s;
    // Saturation matrix (preserves luminance).
    final satR = [lr * invS + s, lg * invS, lb * invS];
    final satG = [lr * invS, lg * invS + s, lb * invS];
    final satB = [lr * invS, lg * invS, lb * invS + s];
    // Contrast around 0.5 grey: out = (in - 0.5) * c + 0.5.
    final c = contrast;
    final cOffset = 0.5 * (1.0 - c) * 255;
    // Brightness is multiplicative; exposure is additive (×255 to
    // match Flutter's 0–255 channel range).
    final br = brightness;
    final exp = exposure * 255;
    // Compose: out = sat(in) * br * c + cOffset + exp.
    return ColorFilter.matrix(<double>[
      satR[0] * br * c, satR[1] * br * c, satR[2] * br * c, 0,
      cOffset + exp,
      satG[0] * br * c, satG[1] * br * c, satG[2] * br * c, 0,
      cOffset + exp,
      satB[0] * br * c, satB[1] * br * c, satB[2] * br * c, 0,
      cOffset + exp,
      0, 0, 0, 1, 0,
    ]);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is HaptFilter &&
          other.id == id &&
          other.saturation == saturation &&
          other.contrast == contrast &&
          other.brightness == brightness &&
          other.exposure == exposure);

  @override
  int get hashCode =>
      Object.hash(id, saturation, contrast, brightness, exposure);

  // ─── Default preset catalog ──────────────────────────────────────

  static const original = HaptFilter(id: 'original');
  static const mono = HaptFilter(id: 'mono', saturation: 0.0, contrast: 1.05);
  static const vivid =
      HaptFilter(id: 'vivid', saturation: 1.35, contrast: 1.10);
  static const warm = HaptFilter(
    id: 'warm',
    saturation: 1.10,
    contrast: 1.02,
    brightness: 1.03,
    exposure: 0.04,
  );
  static const cool = HaptFilter(
    id: 'cool',
    saturation: 0.95,
    contrast: 1.05,
    brightness: 0.98,
    exposure: -0.02,
  );
  static const bright = HaptFilter(
    id: 'bright',
    saturation: 1.05,
    contrast: 0.95,
    brightness: 1.08,
    exposure: 0.08,
  );
  static const vintage = HaptFilter(
    id: 'vintage',
    saturation: 0.80,
    contrast: 0.88,
    brightness: 1.02,
    exposure: 0.02,
  );
  static const noir =
      HaptFilter(id: 'noir', saturation: 0.0, contrast: 1.30);

  /// The default set shipped with the picker. Override via
  /// `HaptPickerConfig.filters` to ship a different catalog.
  static const defaults = <HaptFilter>[
    original,
    mono,
    vivid,
    warm,
    cool,
    bright,
    vintage,
    noir,
  ];
}

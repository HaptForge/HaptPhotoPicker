import 'package:flutter/foundation.dart';

import 'picker_filter.dart';

/// Compile-time configuration for a single `HaptPhotoPicker.pick`
/// invocation. Construct it once per call site; share it across
/// calls if you want consistent behaviour.
@immutable
class HaptPickerConfig {
  const HaptPickerConfig({
    this.maxSelection = 1,
    this.minSelection = 0,
    this.mediaType = HaptMediaType.image,
    this.aspectRatios = HaptAspectRatio.defaultSet,
    this.initialAspectRatio,
    this.filters = HaptFilter.defaults,
    this.gridColumns = 4,
    this.enableHaptics = true,
    this.requireAllSelectionsBeforeDone = false,
    this.minImageWidth,
    this.minImageHeight,
  });

  /// Hard ceiling on selection count. 1 = single-pick (return the
  /// item directly instead of a list — caller still gets a List
  /// for type uniformity).
  final int maxSelection;

  /// Optional minimum (e.g. for collage flows that require >= 2).
  /// Done button stays disabled until count >= [minSelection].
  final int minSelection;

  final HaptMediaType mediaType;

  /// Aspect-ratio chips shown above the grid. First entry is the
  /// default if [initialAspectRatio] is null.
  final List<HaptAspectRatio> aspectRatios;
  final HaptAspectRatio? initialAspectRatio;

  /// Color-grading presets surfaced in the filter strip beneath the
  /// crop preview. Override to ship a branded look book; set to
  /// `const [HaptFilter.original]` to hide the strip entirely (only
  /// the identity filter remains, no strip rendered).
  final List<HaptFilter> filters;

  /// Grid column count. 4 is Instagram-default. 3 = thicker
  /// thumbnails, 5+ = denser.
  final int gridColumns;

  /// Globally disable the haptic choreography for this invocation.
  /// (Per-event toggles live on `HaptHaptics` itself.)
  final bool enableHaptics;

  /// When true, the Done button is disabled unless the user has
  /// reached exactly [maxSelection]. Useful for "Pick exactly 4
  /// photos for the collage" flows.
  final bool requireAllSelectionsBeforeDone;

  /// Optional resolution gate — assets below this are tinted with
  /// the disabled overlay and refuse selection.
  final int? minImageWidth;
  final int? minImageHeight;

  HaptPickerConfig copyWith({
    int? maxSelection,
    int? minSelection,
    HaptMediaType? mediaType,
    List<HaptAspectRatio>? aspectRatios,
    HaptAspectRatio? initialAspectRatio,
    List<HaptFilter>? filters,
    int? gridColumns,
    bool? enableHaptics,
    bool? requireAllSelectionsBeforeDone,
    int? minImageWidth,
    int? minImageHeight,
  }) =>
      HaptPickerConfig(
        maxSelection: maxSelection ?? this.maxSelection,
        minSelection: minSelection ?? this.minSelection,
        mediaType: mediaType ?? this.mediaType,
        aspectRatios: aspectRatios ?? this.aspectRatios,
        initialAspectRatio: initialAspectRatio ?? this.initialAspectRatio,
        filters: filters ?? this.filters,
        gridColumns: gridColumns ?? this.gridColumns,
        enableHaptics: enableHaptics ?? this.enableHaptics,
        requireAllSelectionsBeforeDone: requireAllSelectionsBeforeDone ??
            this.requireAllSelectionsBeforeDone,
        minImageWidth: minImageWidth ?? this.minImageWidth,
        minImageHeight: minImageHeight ?? this.minImageHeight,
      );
}

/// Allowed media types. `any` returns whatever's in the album.
enum HaptMediaType { image, video, any }

/// Aspect-ratio chip. `original` keeps each photo at its native
/// ratio. Build custom ratios via the `.custom` constructor.
@immutable
class HaptAspectRatio {
  const HaptAspectRatio._({
    required this.id,
    required this.ratio,
    required this.label,
  });

  /// Stable identifier used as Riverpod / state key.
  final String id;

  /// width / height. Null for [original].
  final double? ratio;

  /// Display label. Resolves from `HaptPickerStrings` for built-in
  /// values; literal for custom ones.
  final String? label;

  // ─── Built-in ratios ─────────────────────────────────────────
  // All built-ins are `const` so consumers can pin them into a
  // `const HaptPickerConfig(...)` invocation. New canonical ratios
  // ship inline labels (e.g. "4:3"); the four legacy values
  // (`original`, `square`, `portrait`, `landscape`) keep their
  // label as `null` so they resolve via [HaptPickerStrings] for
  // backward compatibility with consumers who localised them.
  static const HaptAspectRatio original = HaptAspectRatio._(
    id: 'original',
    ratio: null,
    label: null,
  );
  static const HaptAspectRatio square = HaptAspectRatio._(
    id: 'square',
    ratio: 1.0,
    label: null,
  );
  static const HaptAspectRatio portrait = HaptAspectRatio._(
    id: 'portrait',
    ratio: 4 / 5,
    label: null,
  );
  static const HaptAspectRatio landscape = HaptAspectRatio._(
    id: 'landscape',
    ratio: 16 / 9,
    label: null,
  );

  // Canonical ratio set — covers every common crop the consumer
  // photo apps surface (Instagram square, Stories 9:16, classic 4:3
  // print, cinematic 16:9, panorama 2:1 / 3:1, vertical 1:2 / 1:3,
  // wallet 2:3 / 3:2).
  static const HaptAspectRatio r4x3 = HaptAspectRatio._(
      id: 'r4x3', ratio: 4 / 3, label: '4:3');
  static const HaptAspectRatio r3x4 = HaptAspectRatio._(
      id: 'r3x4', ratio: 3 / 4, label: '3:4');
  static const HaptAspectRatio r3x2 = HaptAspectRatio._(
      id: 'r3x2', ratio: 3 / 2, label: '3:2');
  static const HaptAspectRatio r2x3 = HaptAspectRatio._(
      id: 'r2x3', ratio: 2 / 3, label: '2:3');
  static const HaptAspectRatio r5x4 = HaptAspectRatio._(
      id: 'r5x4', ratio: 5 / 4, label: '5:4');
  static const HaptAspectRatio r9x16 = HaptAspectRatio._(
      id: 'r9x16', ratio: 9 / 16, label: '9:16');
  static const HaptAspectRatio r2x1 = HaptAspectRatio._(
      id: 'r2x1', ratio: 2.0, label: '2:1');
  static const HaptAspectRatio r1x2 = HaptAspectRatio._(
      id: 'r1x2', ratio: 0.5, label: '1:2');
  static const HaptAspectRatio r3x1 = HaptAspectRatio._(
      id: 'r3x1', ratio: 3.0, label: '3:1');
  static const HaptAspectRatio r1x3 = HaptAspectRatio._(
      id: 'r1x3', ratio: 1 / 3, label: '1:3');

  /// Canonical default-shipped set. Used by [HaptPickerConfig]'s
  /// default `aspectRatios` so out-of-the-box consumers get a rich
  /// Crop tool instead of a single "Auto" chip (which made the
  /// whole Crop tool collapse to no-op).
  ///
  /// Order matches Apple Photos / Instagram conventions: free-form
  /// first (Auto), then the popular square + portrait + landscape
  /// trio, then the wider canonical ratios. Override by passing a
  /// shorter list if your app only needs a subset.
  static const List<HaptAspectRatio> defaultSet = <HaptAspectRatio>[
    original,
    square,
    r4x3,
    r3x4,
    portrait, // 4:5 — Instagram portrait
    r5x4,
    landscape, // 16:9 — cinematic
    r9x16, // 9:16 — Story
    r3x2,
    r2x3,
    r2x1,
    r1x2,
    r3x1,
    r1x3,
  ];

  /// Custom ratio outside the built-in set.
  /// ```dart
  /// HaptAspectRatio.custom(id: 'story', ratio: 9 / 16, label: 'Story')
  /// ```
  const HaptAspectRatio.custom({
    required this.id,
    required double this.ratio,
    required String this.label,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is HaptAspectRatio && other.id == id);

  @override
  int get hashCode => id.hashCode;
}

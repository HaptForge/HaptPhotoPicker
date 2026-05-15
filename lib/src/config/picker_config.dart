import 'package:flutter/foundation.dart';

/// Compile-time configuration for a single `HaptPhotoPicker.pick`
/// invocation. Construct it once per call site; share it across
/// calls if you want consistent behaviour.
@immutable
class HaptPickerConfig {
  const HaptPickerConfig({
    this.maxSelection = 1,
    this.minSelection = 0,
    this.mediaType = HaptMediaType.image,
    this.aspectRatios = const [HaptAspectRatio.original],
    this.initialAspectRatio,
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

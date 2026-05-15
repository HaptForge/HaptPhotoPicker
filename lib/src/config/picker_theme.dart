import 'package:flutter/material.dart';

/// Top-level theme bundle for the picker. Pass into
/// `HaptPhotoPicker.pick(theme: ...)`. Sub-bundles are independently
/// overridable so an app dev can tweak (say) only the typography
/// without losing the rest of the defaults.
///
/// ```dart
/// final myTheme = HaptPickerTheme.light().copyWith(
///   colors: HaptPickerTheme.light().colors.copyWith(
///     primary: Color(0xFF850E35),
///     selectionBadge: Color(0xFFEE6983),
///   ),
///   typography: HaptPickerTypography.fromFamily('Inter'),
/// );
/// ```
@immutable
class HaptPickerTheme {
  const HaptPickerTheme({
    required this.colors,
    required this.typography,
    required this.spacing,
    required this.radii,
    required this.shadows,
  });

  final HaptPickerColors colors;
  final HaptPickerTypography typography;
  final HaptPickerSpacing spacing;
  final HaptPickerRadii radii;
  final HaptPickerShadows shadows;

  /// Light defaults — Instagram-leaning neutral whites with a
  /// configurable accent. Apps that want a brand-leaning look call
  /// `.copyWith(colors: ...)` to swap the accent + tint pair.
  factory HaptPickerTheme.light() => HaptPickerTheme(
        colors: HaptPickerColors.light(),
        typography: HaptPickerTypography.systemDefault(),
        spacing: const HaptPickerSpacing(),
        radii: const HaptPickerRadii(),
        shadows: HaptPickerShadows.standard(),
      );

  /// Dark defaults — mirrors `.light()` with inverted backgrounds.
  factory HaptPickerTheme.dark() => HaptPickerTheme(
        colors: HaptPickerColors.dark(),
        typography: HaptPickerTypography.systemDefault(),
        spacing: const HaptPickerSpacing(),
        radii: const HaptPickerRadii(),
        shadows: HaptPickerShadows.standard(),
      );

  HaptPickerTheme copyWith({
    HaptPickerColors? colors,
    HaptPickerTypography? typography,
    HaptPickerSpacing? spacing,
    HaptPickerRadii? radii,
    HaptPickerShadows? shadows,
  }) =>
      HaptPickerTheme(
        colors: colors ?? this.colors,
        typography: typography ?? this.typography,
        spacing: spacing ?? this.spacing,
        radii: radii ?? this.radii,
        shadows: shadows ?? this.shadows,
      );
}

/// Every color the picker paints. None inherit from `Theme.of` —
/// the consumer is in control. A null override leaves the inherited
/// value untouched via [copyWith].
@immutable
class HaptPickerColors {
  const HaptPickerColors({
    required this.surface,
    required this.surfaceElevated,
    required this.scrim,
    required this.border,
    required this.primary,
    required this.onPrimary,
    required this.selectionBadge,
    required this.selectionBadgeText,
    required this.selectionOverlay,
    required this.disabledOverlay,
    required this.gridBackground,
    required this.thumbnailPlaceholder,
    required this.cropFrame,
    required this.cropFrameGuide,
    required this.textPrimary,
    required this.textSecondary,
    required this.textInverse,
  });

  /// Sheet background.
  final Color surface;

  /// Elevated surfaces inside the sheet (album dropdown, modal
  /// pills) — usually a touch lighter / darker than [surface].
  final Color surfaceElevated;

  /// Modal barrier behind the picker sheet.
  final Color scrim;

  /// Hairlines between rows / around the crop frame.
  final Color border;

  /// Primary brand colour — used for the "Done" button + selection
  /// badge fill when no explicit [selectionBadge] is set.
  final Color primary;
  final Color onPrimary;

  /// Selection badge (circle in the top-right corner of a selected
  /// thumbnail) — explicit override so apps can dim it relative to
  /// the primary brand colour.
  final Color selectionBadge;
  final Color selectionBadgeText;

  /// Translucent wash painted over a selected thumbnail.
  final Color selectionOverlay;

  /// Wash over thumbnails that can't be selected (max reached,
  /// wrong media type, etc.).
  final Color disabledOverlay;

  final Color gridBackground;
  final Color thumbnailPlaceholder;

  /// Stroke around the crop preview rectangle.
  final Color cropFrame;

  /// Grid-thirds guide lines inside the crop frame (visible while
  /// the user is panning).
  final Color cropFrameGuide;

  final Color textPrimary;
  final Color textSecondary;

  /// Text colour against [primary] backgrounds (Done button label).
  final Color textInverse;

  factory HaptPickerColors.light() => const HaptPickerColors(
        surface: Color(0xFFFFFFFF),
        surfaceElevated: Color(0xFFF7F7F8),
        scrim: Color(0x99000000),
        border: Color(0xFFE5E5EA),
        primary: Color(0xFF0095F6),
        onPrimary: Color(0xFFFFFFFF),
        selectionBadge: Color(0xFF0095F6),
        selectionBadgeText: Color(0xFFFFFFFF),
        selectionOverlay: Color(0x330095F6),
        disabledOverlay: Color(0x66FFFFFF),
        gridBackground: Color(0xFFFFFFFF),
        thumbnailPlaceholder: Color(0xFFF2F2F4),
        cropFrame: Color(0xFFFFFFFF),
        cropFrameGuide: Color(0x66FFFFFF),
        textPrimary: Color(0xFF111113),
        textSecondary: Color(0xFF8E8E93),
        textInverse: Color(0xFFFFFFFF),
      );

  factory HaptPickerColors.dark() => const HaptPickerColors(
        surface: Color(0xFF0E0E10),
        surfaceElevated: Color(0xFF1A1A1D),
        scrim: Color(0xCC000000),
        border: Color(0xFF2A2A2E),
        primary: Color(0xFF0095F6),
        onPrimary: Color(0xFFFFFFFF),
        selectionBadge: Color(0xFF0095F6),
        selectionBadgeText: Color(0xFFFFFFFF),
        selectionOverlay: Color(0x550095F6),
        disabledOverlay: Color(0x66000000),
        gridBackground: Color(0xFF0E0E10),
        thumbnailPlaceholder: Color(0xFF1F1F22),
        cropFrame: Color(0xFFFFFFFF),
        cropFrameGuide: Color(0x44FFFFFF),
        textPrimary: Color(0xFFFFFFFF),
        textSecondary: Color(0xFF98989F),
        textInverse: Color(0xFFFFFFFF),
      );

  HaptPickerColors copyWith({
    Color? surface,
    Color? surfaceElevated,
    Color? scrim,
    Color? border,
    Color? primary,
    Color? onPrimary,
    Color? selectionBadge,
    Color? selectionBadgeText,
    Color? selectionOverlay,
    Color? disabledOverlay,
    Color? gridBackground,
    Color? thumbnailPlaceholder,
    Color? cropFrame,
    Color? cropFrameGuide,
    Color? textPrimary,
    Color? textSecondary,
    Color? textInverse,
  }) =>
      HaptPickerColors(
        surface: surface ?? this.surface,
        surfaceElevated: surfaceElevated ?? this.surfaceElevated,
        scrim: scrim ?? this.scrim,
        border: border ?? this.border,
        primary: primary ?? this.primary,
        onPrimary: onPrimary ?? this.onPrimary,
        selectionBadge: selectionBadge ?? this.selectionBadge,
        selectionBadgeText: selectionBadgeText ?? this.selectionBadgeText,
        selectionOverlay: selectionOverlay ?? this.selectionOverlay,
        disabledOverlay: disabledOverlay ?? this.disabledOverlay,
        gridBackground: gridBackground ?? this.gridBackground,
        thumbnailPlaceholder:
            thumbnailPlaceholder ?? this.thumbnailPlaceholder,
        cropFrame: cropFrame ?? this.cropFrame,
        cropFrameGuide: cropFrameGuide ?? this.cropFrameGuide,
        textPrimary: textPrimary ?? this.textPrimary,
        textSecondary: textSecondary ?? this.textSecondary,
        textInverse: textInverse ?? this.textInverse,
      );
}

/// Typography slots. Default values keep the system font; pass
/// `HaptPickerTypography.fromFamily('Inter')` to use a single family
/// across every slot, or build the bundle by hand for full control.
@immutable
class HaptPickerTypography {
  const HaptPickerTypography({
    required this.title,
    required this.body,
    required this.label,
    required this.button,
    required this.badge,
  });

  /// App-bar title + album name.
  final TextStyle title;

  /// Empty-state body, secondary helper text.
  final TextStyle body;

  /// Aspect-ratio chips, album row labels.
  final TextStyle label;

  /// Done button.
  final TextStyle button;

  /// Selection-count badge digit.
  final TextStyle badge;

  /// System defaults — `null` font family means platform default
  /// (SF Pro on iOS, Roboto on Android).
  factory HaptPickerTypography.systemDefault() => const HaptPickerTypography(
        title: TextStyle(
            fontSize: 17, fontWeight: FontWeight.w700, height: 1.2),
        body: TextStyle(
            fontSize: 14, fontWeight: FontWeight.w400, height: 1.35),
        label: TextStyle(
            fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 0.3),
        button: TextStyle(
            fontSize: 15, fontWeight: FontWeight.w700, height: 1.0),
        badge: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            height: 1.0,
            letterSpacing: 0.2),
      );

  /// Build the whole bundle off a single family.
  /// `HaptPickerTypography.fromFamily('Inter')` ships a coherent
  /// scale derived from Inter.
  factory HaptPickerTypography.fromFamily(String family,
          {String? package}) =>
      HaptPickerTypography(
        title: TextStyle(
            fontFamily: family,
            package: package,
            fontSize: 17,
            fontWeight: FontWeight.w700,
            height: 1.2),
        body: TextStyle(
            fontFamily: family,
            package: package,
            fontSize: 14,
            fontWeight: FontWeight.w400,
            height: 1.35),
        label: TextStyle(
            fontFamily: family,
            package: package,
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.3),
        button: TextStyle(
            fontFamily: family,
            package: package,
            fontSize: 15,
            fontWeight: FontWeight.w700,
            height: 1.0),
        badge: TextStyle(
            fontFamily: family,
            package: package,
            fontSize: 11,
            fontWeight: FontWeight.w800,
            height: 1.0,
            letterSpacing: 0.2),
      );

  HaptPickerTypography copyWith({
    TextStyle? title,
    TextStyle? body,
    TextStyle? label,
    TextStyle? button,
    TextStyle? badge,
  }) =>
      HaptPickerTypography(
        title: title ?? this.title,
        body: body ?? this.body,
        label: label ?? this.label,
        button: button ?? this.button,
        badge: badge ?? this.badge,
      );
}

/// Spacing scale — values match the 4-pt grid most apps use.
@immutable
class HaptPickerSpacing {
  const HaptPickerSpacing({
    this.xxs = 4,
    this.xs = 8,
    this.sm = 12,
    this.md = 16,
    this.lg = 20,
    this.xl = 28,
    this.gridGutter = 2,
  });

  final double xxs;
  final double xs;
  final double sm;
  final double md;
  final double lg;
  final double xl;

  /// Gap between grid cells. Instagram uses 2 px; some brands
  /// prefer 0 (touching) or larger.
  final double gridGutter;

  HaptPickerSpacing copyWith({
    double? xxs,
    double? xs,
    double? sm,
    double? md,
    double? lg,
    double? xl,
    double? gridGutter,
  }) =>
      HaptPickerSpacing(
        xxs: xxs ?? this.xxs,
        xs: xs ?? this.xs,
        sm: sm ?? this.sm,
        md: md ?? this.md,
        lg: lg ?? this.lg,
        xl: xl ?? this.xl,
        gridGutter: gridGutter ?? this.gridGutter,
      );
}

/// Corner-radius palette.
@immutable
class HaptPickerRadii {
  const HaptPickerRadii({
    this.thumbnail = 0,
    this.cropFrame = 12,
    this.button = 999,
    this.sheet = 28,
    this.badge = 999,
  });

  /// Thumbnail corner radius. 0 = Instagram-flush. Set 12+ for a
  /// card-y look.
  final double thumbnail;
  final double cropFrame;
  final double button;
  final double sheet;
  final double badge;

  HaptPickerRadii copyWith({
    double? thumbnail,
    double? cropFrame,
    double? button,
    double? sheet,
    double? badge,
  }) =>
      HaptPickerRadii(
        thumbnail: thumbnail ?? this.thumbnail,
        cropFrame: cropFrame ?? this.cropFrame,
        button: button ?? this.button,
        sheet: sheet ?? this.sheet,
        badge: badge ?? this.badge,
      );
}

/// Shadows are sometimes a brand axis (especially on lighter
/// themes). Each slot is a list so consumers can stack multiple
/// shadows (key + ambient).
@immutable
class HaptPickerShadows {
  const HaptPickerShadows({
    required this.sheet,
    required this.button,
    required this.badge,
  });

  final List<BoxShadow> sheet;
  final List<BoxShadow> button;
  final List<BoxShadow> badge;

  factory HaptPickerShadows.standard() => HaptPickerShadows(
        sheet: [
          BoxShadow(
            color: const Color(0x33000000).withValues(alpha: 0.10),
            blurRadius: 32,
            offset: const Offset(0, -8),
          ),
        ],
        button: [
          BoxShadow(
            color: const Color(0xFF0095F6).withValues(alpha: 0.30),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
        badge: [
          BoxShadow(
            color: const Color(0x33000000).withValues(alpha: 0.20),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      );

  HaptPickerShadows copyWith({
    List<BoxShadow>? sheet,
    List<BoxShadow>? button,
    List<BoxShadow>? badge,
  }) =>
      HaptPickerShadows(
        sheet: sheet ?? this.sheet,
        button: button ?? this.button,
        badge: badge ?? this.badge,
      );
}

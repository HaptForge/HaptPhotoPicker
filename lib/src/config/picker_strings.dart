/// Every user-facing string the picker renders. The library ships
/// **English defaults only** — localization is the consumer's
/// responsibility (and most apps' existing l10n layers already
/// handle it better than we could).
///
/// ```dart
/// // Quick override — change a line or two, inherit the rest.
/// class MyStrings extends HaptPickerStringsEn {
///   const MyStrings();
///   @override
///   String get pickerTitle => 'Pick a moment';
/// }
///
/// // Full l10n wiring — every string from your app's translation
/// // layer. Recommended for production apps shipping more than one
/// // language.
/// class MyL10nStrings extends HaptPickerStrings {
///   MyL10nStrings(this.s);
///   final AppStrings s;
///   @override String get pickerTitle => s.pickerTitle;
///   @override String get doneLabelEmpty => s.done;
///   // …override the rest.
/// }
///
/// HaptPhotoPicker.pick(context, strings: MyL10nStrings(S.of(context)));
/// ```
///
/// The abstract base has **no defaults** — missed strings fail at
/// compile time, not at runtime.
abstract class HaptPickerStrings {
  const HaptPickerStrings();

  /// Sheet title (also the app-bar text).
  String get pickerTitle;

  /// "Done" button label when nothing is selected (some brands
  /// want this disabled-but-readable, others want "Cancel"-like).
  String get doneLabelEmpty;

  /// "Done (N)" — fed the live count.
  String doneLabelWithCount(int count);

  /// Cancel / dismiss link in the top-left.
  String get cancelLabel;

  /// Album-switcher placeholder when no album is loaded yet.
  String get albumLoadingLabel;

  /// Default "All photos" album label — most apps want this
  /// localized to match the device OS.
  String get allPhotosLabel;

  /// Album-switcher button accessibility label.
  String get albumSwitcherA11yLabel;

  /// Toast shown when the user tries to select beyond [maxSelection].
  String maxSelectionReached(int max);

  /// Body of the empty-state when the album has no media.
  String get emptyAlbumBody;

  /// Title of the system permission-denied state.
  String get permissionDeniedTitle;

  /// Body of the system permission-denied state.
  String get permissionDeniedBody;

  /// CTA on the permission-denied state — opens system Settings.
  String get permissionDeniedSettings;

  /// Aspect-ratio chip labels. Apps that ship custom ratios should
  /// override these by name when constructing
  /// `HaptAspectRatio(label: ...)`.
  String get aspectRatioOriginal;
  String get aspectRatioSquare;
  String get aspectRatioPortrait;
  String get aspectRatioLandscape;

  /// Filter-chip label resolver. Receives the filter's `id`
  /// (e.g. 'mono', 'vivid'); subclasses return the localized label.
  /// Unknown ids should return the id itself so custom filters
  /// without overrides still render readable strings.
  String filterLabel(String id);

  /// "Selected N of M" — read out by screen readers when the user
  /// taps a thumbnail.
  String selectionAnnouncement(int n, int max);
}

// ─── English defaults (the only baked-in locale) ─────────────────────
//
// Apps can use this as-is for English, or subclass it to tweak a few
// lines. For other languages, the recommended pattern is to extend
// `HaptPickerStrings` directly and pull every string from the app's
// own l10n layer (intl, easy_localization, custom JSON map, etc).

class HaptPickerStringsEn extends HaptPickerStrings {
  const HaptPickerStringsEn();
  @override
  String get pickerTitle => 'Select photo';
  @override
  String get doneLabelEmpty => 'Done';
  @override
  String doneLabelWithCount(int count) => 'Done ($count)';
  @override
  String get cancelLabel => 'Cancel';
  @override
  String get albumLoadingLabel => 'Loading…';
  @override
  String get allPhotosLabel => 'All photos';
  @override
  String get albumSwitcherA11yLabel => 'Switch album';
  @override
  String maxSelectionReached(int max) => "You've reached $max items.";
  @override
  String get emptyAlbumBody => 'No photos in this album yet.';
  @override
  String get permissionDeniedTitle => 'Photo access is off';
  @override
  String get permissionDeniedBody =>
      'Allow photo access in Settings to pick photos.';
  @override
  String get permissionDeniedSettings => 'Open Settings';
  @override
  String get aspectRatioOriginal => 'Original';
  @override
  String get aspectRatioSquare => '1:1';
  @override
  String get aspectRatioPortrait => '4:5';
  @override
  String get aspectRatioLandscape => '16:9';
  @override
  String filterLabel(String id) => switch (id) {
        'original' => 'Original',
        'mono' => 'Mono',
        'vivid' => 'Vivid',
        'warm' => 'Warm',
        'cool' => 'Cool',
        'bright' => 'Bright',
        'vintage' => 'Vintage',
        'noir' => 'Noir',
        _ => id,
      };
  @override
  String selectionAnnouncement(int n, int max) =>
      'Selected $n of $max';
}

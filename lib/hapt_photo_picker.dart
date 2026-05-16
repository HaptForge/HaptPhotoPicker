/// HaptPhotoPicker — an Instagram-grade photo picker for Flutter.
///
/// Quick start:
///
/// ```dart
/// final assets = await HaptPhotoPicker.pick(
///   context,
///   config: const HaptPickerConfig(
///     maxSelection: 4,
///     mediaType: HaptMediaType.image,
///   ),
///   theme: HaptPickerTheme.light(),                // or custom
///   strings: const HaptPickerStringsEn(),          // or your subclass
/// );
/// ```
///
/// Every token of the theme, every string of the localization, and
/// every step of the post-processing pipeline is overridable —
/// `HaptPhotoPicker` is a library, not a tightly-coupled brand
/// surface.
library;

export 'src/api.dart' show HaptPhotoPicker, HaptPickerResult;
export 'src/config/picker_config.dart'
    show HaptPickerConfig, HaptMediaType, HaptAspectRatio;
export 'src/config/picker_filter.dart' show HaptFilter;
export 'src/config/picker_theme.dart'
    show
        HaptPickerTheme,
        HaptPickerColors,
        HaptPickerTypography,
        HaptPickerSpacing,
        HaptPickerRadii,
        HaptPickerShadows;
export 'src/config/picker_strings.dart'
    show
        HaptPickerStrings,
        HaptPickerStringsEn,
        HaptPickerStringsVi,
        HaptPickerStringsEs,
        HaptPickerStringsFr,
        HaptPickerStringsDe,
        HaptPickerStringsPt,
        HaptPickerStringsJa,
        HaptPickerStringsKo,
        HaptPickerStringsAr;
export 'src/data/asset.dart' show HaptAsset, HaptAssetKind;
export 'src/data/album.dart' show HaptAlbum;
export 'src/controller/picker_controller.dart'
    show HaptPickerController, HaptCropState;
export 'src/util/haptics.dart' show HaptHaptics, HaptHapticEvent;
export 'src/pipeline/asset_transform.dart'
    show HaptAssetTransform, HaptTransformContext, HaptTransformResult;

import 'package:flutter/widgets.dart';

import '../config/picker_config.dart';
import '../config/picker_filter.dart';
import '../data/album.dart';
import '../data/asset.dart';
import '../util/haptics.dart';

/// In-memory state for an open picker session. Driven by the picker
/// UI and read back by the result-builder when the user taps Done.
///
/// Uses ChangeNotifier (not a stream-based controller) so consumers
/// can plug it into their preferred state-management with a single
/// `AnimatedBuilder` / `ListenableBuilder`.
class HaptPickerController extends ChangeNotifier {
  HaptPickerController({
    required this.config,
    required this.haptics,
  }) : _aspectRatio = config.initialAspectRatio ?? config.aspectRatios.first;

  final HaptPickerConfig config;
  final HaptHaptics haptics;

  // ─── Albums ────────────────────────────────────────────────────────

  List<HaptAlbum> _albums = const [];
  List<HaptAlbum> get albums => List.unmodifiable(_albums);

  HaptAlbum? _currentAlbum;
  HaptAlbum? get currentAlbum => _currentAlbum;

  set albums(List<HaptAlbum> next) {
    _albums = next;
    _currentAlbum ??= next.isEmpty ? null : next.first;
    notifyListeners();
  }

  void switchAlbum(HaptAlbum album) {
    if (_currentAlbum == album) return;
    _currentAlbum = album;
    _assets = const [];
    haptics.fire(HaptHapticEvent.albumSwitch);
    notifyListeners();
  }

  // ─── Assets (paginated within the current album) ───────────────────

  List<HaptAsset> _assets = const [];
  List<HaptAsset> get assets => List.unmodifiable(_assets);

  set assets(List<HaptAsset> next) {
    _assets = next;
    // Single-pick mode bootstrap: when the album finishes its first
    // load (no asset list yet, nothing selected), seed the selection
    // with the newest asset (index 0 — photo_manager returns
    // newest-first). This implements the "no empty state in single-
    // pick" rule: the picker always has exactly one selection from
    // the moment it opens, so the Done button is enabled by default
    // and the crop preview shows actual content instead of a
    // placeholder. Multi-pick keeps the original "start empty"
    // semantics — there's no equally-correct default for N picks.
    if (config.maxSelection == 1 &&
        _selection.isEmpty &&
        next.isNotEmpty) {
      _selection.add(next.first);
    }
    notifyListeners();
  }

  // ─── Selection ─────────────────────────────────────────────────────

  /// Ordered list — first selected is index 0. The picker uses
  /// order to drive the badge digit (1 / 2 / 3 …).
  final List<HaptAsset> _selection = [];
  List<HaptAsset> get selection => List.unmodifiable(_selection);

  bool isSelected(HaptAsset a) => _selection.contains(a);

  /// 1-based selection index, or null when not selected. Used by
  /// the badge.
  int? selectionIndex(HaptAsset a) {
    final i = _selection.indexOf(a);
    return i == -1 ? null : i + 1;
  }

  bool get atMax => _selection.length >= config.maxSelection;

  bool get canFinish =>
      _selection.length >= config.minSelection &&
      (!config.requireAllSelectionsBeforeDone ||
          _selection.length == config.maxSelection);

  /// Toggle an asset's selection state. Returns true if the
  /// operation took effect; false if it was rejected.
  ///
  /// **Single-pick mode** (`maxSelection == 1`) is a true tap-to-
  /// replace: the picker is NEVER in a zero-selection state. The
  /// album auto-selects the newest asset on load (see `assets`
  /// setter), tapping a different thumbnail swaps the selection in
  /// one move, and tapping the currently-selected thumbnail is a
  /// no-op (no deselect). The user always has exactly one pick.
  /// Without this rule the Done button could go disabled mid-flow
  /// just because the user double-tapped the wrong thumbnail.
  ///
  /// **Multi-pick mode** keeps the original semantics: tapping a
  /// selected thumbnail deselects it, the second "add" beyond
  /// [HaptPickerConfig.maxSelection] fails so the user is
  /// explicitly told to deselect first — that's the right
  /// affordance when the selection ORDER matters (badges show 1/2/3).
  bool toggle(HaptAsset a) {
    if (_selection.contains(a)) {
      // Single-pick: tapping the already-selected asset is a no-op.
      // We never let the picker drop to zero selections in this mode.
      if (config.maxSelection == 1) {
        return false;
      }
      _selection.remove(a);
      haptics.fire(HaptHapticEvent.deselect);
      notifyListeners();
      return true;
    }
    if (atMax) {
      if (config.maxSelection == 1) {
        // Tap-to-replace: clear the current single pick + accept
        // the new one. Crop state for the displaced asset stays in
        // `_cropStates` (key'd by id) — re-selecting later resumes
        // the previous transform without surprises.
        _selection.clear();
        _selection.add(a);
        haptics.fire(HaptHapticEvent.select);
        notifyListeners();
        return true;
      }
      haptics.fire(HaptHapticEvent.maxReached);
      return false;
    }
    _selection.add(a);
    haptics.fire(HaptHapticEvent.select);
    notifyListeners();
    return true;
  }

  void clearSelection() {
    if (_selection.isEmpty) return;
    _selection.clear();
    notifyListeners();
  }

  // ─── Aspect ratio (crop preview) ───────────────────────────────────

  HaptAspectRatio _aspectRatio;
  HaptAspectRatio get aspectRatio => _aspectRatio;

  void setAspectRatio(HaptAspectRatio r) {
    if (_aspectRatio == r) return;
    _aspectRatio = r;
    // Aspect-ratio change resets the in-progress crop transform for
    // the featured asset — the user's prior pan/zoom was relative
    // to the old frame shape, so reapplying it under a new shape
    // would land them in a weird spot.
    final id = featuredAsset?.id;
    if (id != null) _cropStates.remove(id);
    haptics.fire(HaptHapticEvent.snap);
    notifyListeners();
  }

  // ─── Featured asset (which one the crop preview is editing) ────────

  /// Asset currently visible in the crop preview. Defaults to first
  /// selected; falls back to first asset of the album when nothing
  /// is selected yet. Driving the preview off this getter means the
  /// preview surfaces whichever item the user is paying attention
  /// to without needing a separate "active asset" field.
  HaptAsset? get featuredAsset {
    if (_focusOverride != null) return _focusOverride;
    if (_selection.isNotEmpty) return _selection.first;
    if (_assets.isNotEmpty) return _assets.first;
    return null;
  }

  HaptAsset? _focusOverride;

  /// Pin a specific asset as the crop-preview focus. Used when the
  /// user taps a different thumbnail just to preview-edit it, even
  /// while a different asset stays first in the selection order.
  /// Clear with `setFocus(null)`.
  void setFocus(HaptAsset? a) {
    if (_focusOverride == a) return;
    _focusOverride = a;
    notifyListeners();
  }

  // ─── Per-asset crop state ──────────────────────────────────────────
  //
  // Each picked asset can have its own pan / zoom / rotation. We
  // store them by asset id so the user can switch among selected
  // items and pick up where they left off on each.

  final Map<String, HaptCropState> _cropStates = {};

  HaptCropState cropFor(HaptAsset a) =>
      _cropStates[a.id] ?? const HaptCropState.identity();

  /// Replace the crop state for [a] with [next]. Called by the
  /// InteractiveViewer's transform listener every frame while the
  /// user pans / zooms. Cheap — same shape every call.
  void setCropFor(HaptAsset a, HaptCropState next) {
    _cropStates[a.id] = next;
    notifyListeners();
  }

  /// Rotate the featured asset 90° clockwise. Wraps at 4 (full
  /// cycle = identity).
  void rotateFeaturedClockwise() {
    final a = featuredAsset;
    if (a == null) return;
    final cur = cropFor(a);
    _cropStates[a.id] = cur.copyWith(
      rotationQuarters: (cur.rotationQuarters + 1) % 4,
    );
    haptics.fire(HaptHapticEvent.snap);
    notifyListeners();
  }

  /// Replace the color filter applied to the featured asset. Lets
  /// the user A/B between presets in the filter strip — same UX as
  /// Instagram's Filter row beneath the cropper.
  void setFilterForFeatured(HaptFilter filter) {
    final a = featuredAsset;
    if (a == null) return;
    final cur = cropFor(a);
    if (cur.filter == filter) return;
    _cropStates[a.id] = cur.copyWith(filter: filter);
    haptics.fire(HaptHapticEvent.snap);
    notifyListeners();
  }

  /// Set the chosen preset's intensity (0..1). 0 = no effect
  /// (identity), 1 = full preset. Bound to the slider that sits
  /// beneath the filter strip.
  void setFilterIntensityForFeatured(double intensity) {
    final a = featuredAsset;
    if (a == null) return;
    final clamped = intensity.clamp(0.0, 1.0);
    final cur = cropFor(a);
    if (cur.filterIntensity == clamped) return;
    _cropStates[a.id] = cur.copyWith(filterIntensity: clamped);
    notifyListeners();
  }

  /// Replace the manual adjustments on the featured asset. Called
  /// every time the user moves a slider in the Adjust tab.
  void setAdjustmentsForFeatured(HaptFilter adjustments) {
    final a = featuredAsset;
    if (a == null) return;
    final cur = cropFor(a);
    if (cur.adjustments == adjustments) return;
    _cropStates[a.id] = cur.copyWith(adjustments: adjustments);
    notifyListeners();
  }

  /// Toggle horizontal mirror on the featured asset.
  void toggleFlipHForFeatured() {
    final a = featuredAsset;
    if (a == null) return;
    final cur = cropFor(a);
    _cropStates[a.id] = cur.copyWith(flipH: !cur.flipH);
    haptics.fire(HaptHapticEvent.snap);
    notifyListeners();
  }

  /// Toggle vertical mirror on the featured asset.
  void toggleFlipVForFeatured() {
    final a = featuredAsset;
    if (a == null) return;
    final cur = cropFor(a);
    _cropStates[a.id] = cur.copyWith(flipV: !cur.flipV);
    haptics.fire(HaptHapticEvent.snap);
    notifyListeners();
  }

  /// Set the fine-grained rotation (degrees, [-45, 45]) on the
  /// featured asset. Clamps + snaps to 0° within a 0.5° dead-zone so
  /// the dial has a tactile centre. Fires a `tick` haptic on whole-
  /// degree boundaries — same idiom Apple's photo editor uses to
  /// give the dial physical feedback without spamming the motor on
  /// every sub-degree touch update.
  /// True when the featured asset has ANY edit applied — filter,
  /// adjustments, rotation, flips, or pan/zoom transform. The
  /// Revert button uses this to decide whether to render at all.
  bool get featuredHasEdits {
    final a = featuredAsset;
    if (a == null) return false;
    final s = cropFor(a);
    return s.rotationQuarters != 0 ||
        s.rotationFine != 0 ||
        s.flipH ||
        s.flipV ||
        !s.filter.isIdentity ||
        s.filterIntensity != 1.0 ||
        !s.adjustments.isIdentity ||
        s.scale != 1.0 ||
        s.translation != Offset.zero;
  }

  /// Clear every edit on the featured asset back to identity.
  /// Bound to the tool-chrome Revert button. Pan / zoom transform
  /// is reset too — the consumer expects "Revert" to mean
  /// "completely undo everything I did", not "keep some of it".
  void revertFeatured() {
    final a = featuredAsset;
    if (a == null) return;
    _cropStates[a.id] = const HaptCropState.identity();
    haptics.fire(HaptHapticEvent.confirm);
    notifyListeners();
  }

  void setRotationFineForFeatured(double degrees) {
    final a = featuredAsset;
    if (a == null) return;
    var clamped = degrees.clamp(-45.0, 45.0).toDouble();
    if (clamped.abs() < 0.5) clamped = 0.0;
    final cur = cropFor(a);
    final crossedDegree = cur.rotationFine.round() != clamped.round();
    _cropStates[a.id] = cur.copyWith(rotationFine: clamped);
    // Reuse `snap` (selectionClick) for the per-degree tick feel —
    // same idiom Apple's photo editor's dial uses. Avoids polluting
    // the enum with a brand-new event for one widget.
    if (crossedDegree) haptics.fire(HaptHapticEvent.snap);
    notifyListeners();
  }

  // ─── Preview viewport size ─────────────────────────────────────────
  //
  // The crop preview widget reports its laid-out viewport size here
  // every time the layout changes (chosen aspect ratio + screen
  // size). The crop engine consumes this on Done so it can map the
  // InteractiveViewer's translation (which is in viewport pixels)
  // back to source-pixel coordinates with real geometry — no more
  // hand-waved "h / 1000" heuristic.

  Size? _previewViewportSize;
  Size? get previewViewportSize => _previewViewportSize;

  /// Called by `CropPreview`'s LayoutBuilder. Cheap — only fires a
  /// notification when the size actually changes (debounces against
  /// the per-frame rebuild noise during animations).
  void setPreviewViewportSize(Size size) {
    if (_previewViewportSize == size) return;
    _previewViewportSize = size;
    // No `notifyListeners` — viewport size is read-on-Done, not
    // observed by any UI. Skipping the notification keeps the
    // preview's `AnimatedBuilder` from rebuilding when its own
    // layout reports back.
  }
}

/// Per-asset crop state. Holds the InteractiveViewer transform
/// matrix (4×4, but only translate + uniform scale are used) and
/// rotation quarters (0/1/2/3 for 0°/90°/180°/270° clockwise).
/// Snapshotted into `HaptPickerResult` so consumers can apply the
/// crop themselves if they don't want our `image`-package path.
class HaptCropState {
  const HaptCropState({
    required this.scale,
    required this.translation,
    required this.rotationQuarters,
    required this.filter,
    this.filterIntensity = 1.0,
    this.adjustments = HaptFilter.original,
    this.flipH = false,
    this.flipV = false,
    this.rotationFine = 0.0,
  });

  /// Uniform scale factor. 1.0 = no zoom. Clamped to
  /// `[1.0, maxZoom]` by the crop preview widget.
  final double scale;

  /// Translation in viewport-pixel units, applied after the scale.
  final Offset translation;

  /// 0 / 1 / 2 / 3 representing 0° / 90° / 180° / 270° clockwise.
  final int rotationQuarters;

  /// Color preset applied to the asset. `HaptFilter.original` is
  /// the identity / no-op default. The PRESET is independent of
  /// the user's manual sliders ([adjustments]) — the engine
  /// composes them at render time.
  final HaptFilter filter;

  /// Strength of the chosen preset filter — 1.0 = full preset,
  /// 0.0 = no effect (identity). Interpolates linearly between
  /// the preset's params and the identity values. The "Filter"
  /// tab exposes this via an intensity slider that only shows
  /// when a non-identity filter is selected.
  final double filterIntensity;

  /// User's manual adjustments stacked on top of the preset.
  /// Reuses the [HaptFilter] shape so the engine + preview don't
  /// need a second param channel — the "Adjust" tab's 4 sliders
  /// edit this struct directly. Default is the identity filter
  /// (no manual adjustment).
  final HaptFilter adjustments;

  /// Mirror the image horizontally / vertically. The engine
  /// applies these AFTER rotation but BEFORE crop, so the
  /// thumbnail + the chosen aspect ratio frame stay consistent
  /// with what the user sees in the preview.
  final bool flipH;
  final bool flipV;

  /// Fine-grained user-driven rotation in DEGREES, layered on top of
  /// [rotationQuarters]. Clamped to ±45° by the dial widget so users
  /// who want a 90° turn use the discrete rotate button instead.
  /// Engine applies the combined angle (`quarters * 90° +
  /// rotationFine°`) during render. Default 0 = identity.
  final double rotationFine;

  /// Untouched state — no zoom, centered, no rotation, no filter.
  /// The crop preview seeds with this every time the user switches
  /// to a new asset.
  const HaptCropState.identity()
      : scale = 1.0,
        translation = Offset.zero,
        rotationQuarters = 0,
        filter = HaptFilter.original,
        filterIntensity = 1.0,
        adjustments = HaptFilter.original,
        flipH = false,
        flipV = false,
        rotationFine = 0.0;

  HaptCropState copyWith({
    double? scale,
    Offset? translation,
    int? rotationQuarters,
    HaptFilter? filter,
    double? filterIntensity,
    HaptFilter? adjustments,
    bool? flipH,
    bool? flipV,
    double? rotationFine,
  }) =>
      HaptCropState(
        scale: scale ?? this.scale,
        translation: translation ?? this.translation,
        rotationQuarters: rotationQuarters ?? this.rotationQuarters,
        filter: filter ?? this.filter,
        filterIntensity: filterIntensity ?? this.filterIntensity,
        adjustments: adjustments ?? this.adjustments,
        flipH: flipH ?? this.flipH,
        flipV: flipV ?? this.flipV,
        rotationFine: rotationFine ?? this.rotationFine,
      );
}

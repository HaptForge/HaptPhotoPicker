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
  /// operation took effect; false if it was rejected (max reached).
  bool toggle(HaptAsset a) {
    if (_selection.contains(a)) {
      _selection.remove(a);
      haptics.fire(HaptHapticEvent.deselect);
      notifyListeners();
      return true;
    }
    if (atMax) {
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
  });

  /// Uniform scale factor. 1.0 = no zoom. Clamped to
  /// `[1.0, maxZoom]` by the crop preview widget.
  final double scale;

  /// Translation in viewport-pixel units, applied after the scale.
  final Offset translation;

  /// 0 / 1 / 2 / 3 representing 0° / 90° / 180° / 270° clockwise.
  final int rotationQuarters;

  /// Color preset applied to the asset. `HaptFilter.original` is
  /// the identity / no-op default.
  final HaptFilter filter;

  /// Untouched state — no zoom, centered, no rotation, no filter.
  /// The crop preview seeds with this every time the user switches
  /// to a new asset.
  const HaptCropState.identity()
      : scale = 1.0,
        translation = Offset.zero,
        rotationQuarters = 0,
        filter = HaptFilter.original;

  HaptCropState copyWith({
    double? scale,
    Offset? translation,
    int? rotationQuarters,
    HaptFilter? filter,
  }) =>
      HaptCropState(
        scale: scale ?? this.scale,
        translation: translation ?? this.translation,
        rotationQuarters: rotationQuarters ?? this.rotationQuarters,
        filter: filter ?? this.filter,
      );
}

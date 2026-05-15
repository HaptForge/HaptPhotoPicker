import 'package:flutter/foundation.dart';

import '../config/picker_config.dart';
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
    haptics.fire(HaptHapticEvent.snap);
    notifyListeners();
  }
}

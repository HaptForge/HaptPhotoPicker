import 'package:flutter/services.dart';

/// Choreographed haptic events. Each event has a signature feel
/// that maps to iOS Core Haptics intensity + Android amplitude.
///
/// Apps that want a brand-specific feel can subclass `HaptHaptics`
/// and override `fire` — the picker will call into the subclass
/// for every event.
enum HaptHapticEvent {
  /// User tapped a thumbnail to select it. Light, snappy.
  select,

  /// User deselected. Slightly softer to read as "released".
  deselect,

  /// User scrolled past the album's top / bottom edge.
  scrollEdge,

  /// User tapped a thumbnail when max-selection was already reached.
  maxReached,

  /// Crop frame snapped onto an alignment guide (face, thirds).
  snap,

  /// User confirmed selection (tapped Done).
  confirm,

  /// Album switched.
  albumSwitch,
}

/// Single-method façade that the picker calls for every haptic
/// moment. Default impl maps each event to a sensible
/// `HapticFeedback` call.
///
/// Brand-spec haptic feel? Subclass + override `fire`:
///
/// ```dart
/// class MyHaptics extends HaptHaptics {
///   @override
///   Future<void> fire(HaptHapticEvent e) async {
///     if (e == HaptHapticEvent.confirm) {
///       await HapticFeedback.heavyImpact();
///       await Future.delayed(const Duration(milliseconds: 60));
///       await HapticFeedback.mediumImpact();
///       return;
///     }
///     return super.fire(e);
///   }
/// }
/// ```
class HaptHaptics {
  const HaptHaptics({this.enabled = true});

  /// Global mute. Set false in `HaptPickerConfig.enableHaptics`
  /// or via a runtime toggle if the user disables haptics in your
  /// app's settings.
  final bool enabled;

  Future<void> fire(HaptHapticEvent event) async {
    if (!enabled) return;
    switch (event) {
      case HaptHapticEvent.select:
        await HapticFeedback.selectionClick();
      case HaptHapticEvent.deselect:
        // Slightly lighter than select — light impact reads as
        // "released".
        await HapticFeedback.lightImpact();
      case HaptHapticEvent.scrollEdge:
        // Bouncy thud at the edge.
        await HapticFeedback.mediumImpact();
      case HaptHapticEvent.maxReached:
        // Two quick mediums — feels like "nope".
        await HapticFeedback.mediumImpact();
        await Future<void>.delayed(const Duration(milliseconds: 70));
        await HapticFeedback.mediumImpact();
      case HaptHapticEvent.snap:
        await HapticFeedback.selectionClick();
      case HaptHapticEvent.confirm:
        // Satisfying double-tap — heavy then medium.
        await HapticFeedback.heavyImpact();
        await Future<void>.delayed(const Duration(milliseconds: 80));
        await HapticFeedback.mediumImpact();
      case HaptHapticEvent.albumSwitch:
        await HapticFeedback.selectionClick();
    }
  }
}

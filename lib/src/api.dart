import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'config/picker_config.dart';
import 'config/picker_strings.dart';
import 'config/picker_theme.dart';
import 'data/asset.dart';
import 'pipeline/asset_transform.dart';
import 'ui/picker_sheet.dart';
import 'util/haptics.dart';

/// Single entry point. Opens a modal bottom sheet, returns the
/// user's selection (after running the post-processing pipeline,
/// if any). Returns null when the user cancels.
///
/// Why static / no constructor: the picker holds no app-wide state
/// — every call is self-contained, so an instance API would only
/// add boilerplate.
class HaptPhotoPicker {
  HaptPhotoPicker._();

  /// Show the picker and await the user's selection.
  ///
  /// - [config] controls behaviour (max selection, media type, …).
  /// - [theme] controls appearance — defaults to `HaptPickerTheme.light()`.
  /// - [strings] controls copy — defaults to `HaptPickerStringsEn()`.
  /// - [haptics] overrides the default haptic choreography.
  /// - [pipeline] runs each transform in order before returning.
  ///
  /// Returns null when the user dismisses without selecting. Returns
  /// an empty list when the user opens, deselects everything, and
  /// taps Done with `minSelection: 0`.
  static Future<List<HaptPickerResult>?> pick(
    BuildContext context, {
    HaptPickerConfig config = const HaptPickerConfig(),
    HaptPickerTheme? theme,
    HaptPickerStrings strings = const HaptPickerStringsEn(),
    HaptHaptics? haptics,
    List<HaptAssetTransform> pipeline = const [],
  }) async {
    final effectiveTheme = theme ?? HaptPickerTheme.light();
    final effectiveHaptics = haptics ??
        HaptHaptics(enabled: config.enableHaptics);

    return showModalBottomSheet<List<HaptPickerResult>?>(
      context: context,
      useRootNavigator: true,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: effectiveTheme.colors.scrim,
      builder: (_) => HaptPickerSheet(
        config: config,
        theme: effectiveTheme,
        strings: strings,
        haptics: effectiveHaptics,
        pipeline: pipeline,
      ),
    );
  }
}

/// What the caller actually gets back — a small wrapper around the
/// picked asset + the post-pipeline bytes (when any transform
/// rewrote them).
class HaptPickerResult {
  const HaptPickerResult({
    required this.asset,
    this.processedBytes,
  });

  final HaptAsset asset;

  /// Bytes after the pipeline ran. Null when no transform modified
  /// the asset — caller can read directly from `asset.readBytes()`.
  final Uint8List? processedBytes;
}

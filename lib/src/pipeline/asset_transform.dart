import 'dart:typed_data';

import '../data/asset.dart';

/// Context object handed to every transform. Carries enough info
/// for the transform to know WHY it's running (the picker's
/// config, the user's locale, the asset's index in the selection)
/// without re-plumbing.
class HaptTransformContext {
  const HaptTransformContext({
    required this.indexInSelection,
    required this.totalSelected,
    required this.locale,
  });

  final int indexInSelection;
  final int totalSelected;

  /// BCP-47 locale tag (e.g. `en-US`). Some transforms emit copy
  /// or stickers — they need to know what language to render in.
  final String locale;
}

/// Result of a transform. Contains either updated bytes or a
/// no-op signal (return `HaptTransformResult.passthrough(asset)`
/// to skip).
class HaptTransformResult {
  const HaptTransformResult._({
    required this.asset,
    required this.bytes,
  });

  /// The asset this result applies to.
  final HaptAsset asset;

  /// Override bytes. When null, picker reads from
  /// `asset.readBytes()` as usual.
  final Uint8List? bytes;

  /// Don't modify anything — return the asset as-is.
  factory HaptTransformResult.passthrough(HaptAsset asset) =>
      HaptTransformResult._(asset: asset, bytes: null);

  /// Return modified bytes. Caller should treat these as the
  /// authoritative payload — `asset.readBytes()` won't be consulted
  /// again.
  factory HaptTransformResult.bytes(HaptAsset asset, Uint8List data) =>
      HaptTransformResult._(asset: asset, bytes: data);
}

/// A pluggable post-processing step. Run between the user tapping
/// "Done" and the picker returning. Multiple transforms compose in
/// registration order — the output bytes of step N become the
/// input bytes for step N + 1.
///
/// Typical uses:
///   - `AutoExposureCorrectTransform` (image pipeline)
///   - `WatermarkTransform` (brand watermark in bottom-right)
///   - `MaxResolutionTransform` (downscale to 2048 px for upload)
///   - `StripExifTransform` (privacy — remove GPS / camera model)
abstract class HaptAssetTransform {
  const HaptAssetTransform();

  /// Stable identifier used in debug logs + when an app wants to
  /// query "is this transform already registered" before pushing
  /// it again.
  String get id;

  /// The work. Receive the asset (+ context) plus the previous
  /// step's bytes (null on the first step). Return either the
  /// modified bytes or a passthrough.
  Future<HaptTransformResult> run({
    required HaptAsset asset,
    required Uint8List? incomingBytes,
    required HaptTransformContext context,
  });
}

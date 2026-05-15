import 'package:flutter/foundation.dart';
import 'package:photo_manager/photo_manager.dart' as pm;

/// Domain enum for the underlying asset's kind.
enum HaptAssetKind { image, video, audio, other }

/// Plain wrapper around `photo_manager`'s `AssetEntity`. We never
/// surface `AssetEntity` types in the public API — consumers can
/// stay on `hapt_photo_picker` imports only.
///
/// Provides the bytes / file path the consumer actually wants,
/// hides the platform plumbing.
@immutable
class HaptAsset {
  const HaptAsset._({
    required this.id,
    required this.kind,
    required this.width,
    required this.height,
    required this.createdAt,
    required this.durationMs,
    required pm.AssetEntity entity,
  }) : _entity = entity;

  /// Wrap a raw `photo_manager` entity. Internal — consumers use
  /// the picker results, not this constructor.
  factory HaptAsset.fromEntity(pm.AssetEntity e) {
    final HaptAssetKind kind;
    switch (e.type) {
      case pm.AssetType.image:
        kind = HaptAssetKind.image;
      case pm.AssetType.video:
        kind = HaptAssetKind.video;
      case pm.AssetType.audio:
        kind = HaptAssetKind.audio;
      case pm.AssetType.other:
        kind = HaptAssetKind.other;
    }
    return HaptAsset._(
      id: e.id,
      kind: kind,
      width: e.width,
      height: e.height,
      createdAt: e.createDateTime,
      durationMs: e.duration * 1000,
      entity: e,
    );
  }

  final String id;
  final HaptAssetKind kind;
  final int width;
  final int height;
  final DateTime createdAt;
  final int durationMs;

  final pm.AssetEntity _entity;

  /// Reads the full asset bytes. Awaitable; can be a few MB for
  /// HEIC / RAW. Returns null when the asset is no longer
  /// accessible (deleted between selection + read).
  Future<Uint8List?> readBytes() => _entity.originBytes;

  /// File handle for the original. Some platforms (iOS Photo
  /// Library Sync) return null until the asset is downloaded
  /// locally — caller should fall back to [readBytes].
  Future<String?> filePath() async => (await _entity.file)?.path;

  /// Thumbnail bytes at the requested size. Used by the grid +
  /// crop preview. Cached by `photo_manager` internally.
  Future<Uint8List?> readThumbnail({
    int width = 256,
    int height = 256,
  }) =>
      _entity.thumbnailDataWithSize(
        pm.ThumbnailSize(width, height),
      );

  /// Internal hook for transforms / future native bridges.
  pm.AssetEntity get rawEntity => _entity;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is HaptAsset && other.id == id);
  @override
  int get hashCode => id.hashCode;
}

import 'package:flutter/foundation.dart';
import 'package:photo_manager/photo_manager.dart' as pm;

import 'asset.dart';

/// Wrapper around `photo_manager`'s `AssetPathEntity`. Hides the
/// third-party type so the public picker API doesn't leak it.
@immutable
class HaptAlbum {
  const HaptAlbum._({
    required this.id,
    required this.name,
    required this.assetCount,
    required pm.AssetPathEntity path,
  }) : _path = path;

  /// Build from a raw `photo_manager` path entity. Internal.
  static Future<HaptAlbum> fromPath(pm.AssetPathEntity p) async {
    final count = await p.assetCountAsync;
    return HaptAlbum._(
      id: p.id,
      name: p.name,
      assetCount: count,
      path: p,
    );
  }

  final String id;
  final String name;
  final int assetCount;
  final pm.AssetPathEntity _path;

  /// Lazy-load a page of assets from this album. Pagination keeps
  /// memory bounded — the grid scrolls infinite, we fetch ~120 at
  /// a time.
  Future<List<HaptAsset>> loadAssets({
    int page = 0,
    int pageSize = 120,
  }) async {
    final raw = await _path.getAssetListPaged(
      page: page,
      size: pageSize,
    );
    return raw.map(HaptAsset.fromEntity).toList(growable: false);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is HaptAlbum && other.id == id);
  @override
  int get hashCode => id.hashCode;
}

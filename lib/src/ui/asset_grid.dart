import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../config/picker_strings.dart';
import '../config/picker_theme.dart';
import '../controller/picker_controller.dart';
import '../data/asset.dart';

/// Scrollable thumbnail grid. Tap toggles selection (with haptic
/// + badge update). Tiles show:
///   - thumbnail
///   - selection overlay tint when selected
///   - selection badge (1, 2, 3, …) in the top-right
///   - duration pill in the bottom-right for videos
///   - disabled wash when max selection reached + this tile isn't
///     part of it
class AssetGrid extends StatelessWidget {
  const AssetGrid({
    super.key,
    required this.theme,
    required this.strings,
    required this.controller,
  });

  final HaptPickerTheme theme;
  final HaptPickerStrings strings;
  final HaptPickerController controller;

  @override
  Widget build(BuildContext context) {
    final t = theme;
    final assets = controller.assets;
    if (assets.isEmpty) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(t.spacing.lg),
          child: Text(
            strings.emptyAlbumBody,
            textAlign: TextAlign.center,
            style: t.typography.body.copyWith(color: t.colors.textSecondary),
          ),
        ),
      );
    }
    return Container(
      color: t.colors.gridBackground,
      child: GridView.builder(
        padding: EdgeInsets.symmetric(
          horizontal: t.spacing.gridGutter / 2,
          vertical: t.spacing.gridGutter / 2,
        ),
        physics: const AlwaysScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: controller.config.gridColumns,
          mainAxisSpacing: t.spacing.gridGutter,
          crossAxisSpacing: t.spacing.gridGutter,
        ),
        itemCount: assets.length,
        itemBuilder: (_, i) {
          final asset = assets[i];
          return _Thumbnail(
            theme: t,
            strings: strings,
            controller: controller,
            asset: asset,
          );
        },
      ),
    );
  }
}

class _Thumbnail extends StatelessWidget {
  const _Thumbnail({
    required this.theme,
    required this.strings,
    required this.controller,
    required this.asset,
  });

  final HaptPickerTheme theme;
  final HaptPickerStrings strings;
  final HaptPickerController controller;
  final HaptAsset asset;

  bool get _resolutionOk {
    final minW = controller.config.minImageWidth;
    final minH = controller.config.minImageHeight;
    if (minW != null && asset.width < minW) return false;
    if (minH != null && asset.height < minH) return false;
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final t = theme;
    final selectedIndex = controller.selectionIndex(asset);
    final selected = selectedIndex != null;
    final disabled = !_resolutionOk ||
        (!selected && controller.atMax);
    final isVideo = asset.kind == HaptAssetKind.video;

    return Semantics(
      label: selected
          ? strings.selectionAnnouncement(
              selectedIndex, controller.config.maxSelection)
          : null,
      selected: selected,
      button: true,
      child: GestureDetector(
        onTap: disabled ? null : () => controller.toggle(asset),
        child: Hero(
          // Tag is stable per asset id so the same thumbnail can be
          // morphed into a future fullscreen preview later. Hero
          // animation only fires if a destination Hero with the
          // same tag is pushed — passive otherwise.
          tag: 'hapt.asset.${asset.id}',
          child: Stack(
            fit: StackFit.expand,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(t.radii.thumbnail),
                child: _AssetThumb(
                  asset: asset,
                  placeholder: t.colors.thumbnailPlaceholder,
                ),
              ),
              if (selected)
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(color: t.colors.selectionOverlay),
                  ),
                ),
              if (disabled)
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(color: t.colors.disabledOverlay),
                  ),
                ),
              // Selection badge — top-right
              Positioned(
                top: 6,
                right: 6,
                child: _Badge(
                  theme: t,
                  index: selectedIndex,
                ),
              ),
              // Duration pill — bottom-right for videos
              if (isVideo)
                Positioned(
                  bottom: 6,
                  right: 6,
                  child: _DurationPill(theme: t, ms: asset.durationMs),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.theme, this.index});
  final HaptPickerTheme theme;

  /// Null = not selected (renders an outline circle).
  /// 1-based when selected.
  final int? index;

  @override
  Widget build(BuildContext context) {
    final t = theme;
    final selected = index != null;
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        color: selected ? t.colors.selectionBadge : Colors.transparent,
        shape: BoxShape.circle,
        border: Border.all(
          color: selected
              ? t.colors.selectionBadge
              : Colors.white.withValues(alpha: 0.9),
          width: 1.8,
        ),
        boxShadow: selected ? t.shadows.badge : null,
      ),
      alignment: Alignment.center,
      child: selected
          ? Text(
              '$index',
              style: t.typography.badge.copyWith(
                color: t.colors.selectionBadgeText,
              ),
            )
          : null,
    );
  }
}

class _DurationPill extends StatelessWidget {
  const _DurationPill({required this.theme, required this.ms});
  final HaptPickerTheme theme;
  final int ms;

  String get _formatted {
    final total = (ms / 1000).round();
    final m = (total / 60).floor();
    final s = (total % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final t = theme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(t.radii.badge),
      ),
      child: Text(
        _formatted,
        style: t.typography.badge.copyWith(
          color: Colors.white,
          fontSize: 10,
        ),
      ),
    );
  }
}

class _AssetThumb extends StatelessWidget {
  const _AssetThumb({required this.asset, required this.placeholder});
  final HaptAsset asset;
  final Color placeholder;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List?>(
      future: asset.readThumbnail(width: 280, height: 280),
      builder: (_, snap) {
        final bytes = snap.data;
        if (bytes == null) return Container(color: placeholder);
        return Image.memory(
          bytes,
          fit: BoxFit.cover,
          gaplessPlayback: true,
        );
      },
    );
  }
}

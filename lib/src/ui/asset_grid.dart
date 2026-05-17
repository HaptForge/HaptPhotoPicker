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
              // Selection badge — top-right. Number in multi-pick
              // mode, plain check in single-pick mode (a "1" when
              // the user is by definition picking one is noise).
              Positioned(
                top: 6,
                right: 6,
                child: _Badge(
                  theme: t,
                  index: selectedIndex,
                  showNumber: controller.config.maxSelection > 1,
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
  const _Badge({
    required this.theme,
    required this.showNumber,
    this.index,
  });
  final HaptPickerTheme theme;

  /// Null = not selected (renders an outline circle).
  /// 1-based when selected.
  final int? index;

  /// Multi-pick: show the 1-based index digit. Single-pick: show
  /// a check icon instead — a number when there's only one slot
  /// reads as noise.
  final bool showNumber;

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
      child: !selected
          ? null
          : (showNumber
              ? Text(
                  '$index',
                  style: t.typography.badge.copyWith(
                    color: t.colors.selectionBadgeText,
                  ),
                )
              : Icon(Icons.check_rounded,
                  color: t.colors.selectionBadgeText, size: 16)),
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

/// Grid thumbnail cell.
///
/// Stateful + keep-alive on purpose:
///   - **Stateful** with a cached `Future` lets the same in-flight
///     thumbnail decode survive parent rebuilds (selection-badge
///     redraws, scroll position updates, theme switches). The
///     previous StatelessWidget + inline `FutureBuilder` restarted
///     the Future on every rebuild and re-decoded the same JPEG
///     dozens of times per scroll, which is the primary cause of
///     grid jank on long albums.
///   - **AutomaticKeepAliveClientMixin** prevents the Sliver layer
///     from disposing offscreen cells. Without it, scrolling away
///     destroys decoded ImageProviders and scrolling back has to
///     re-decode from scratch — wasted CPU + flicker on every
///     direction change.
///   - **didUpdateWidget** swaps the cached Future when the cell is
///     recycled onto a different asset (GridView.builder reuses
///     widget instances). Comparing by `asset.id` instead of
///     identity matches photo_manager's stable-ID semantics.
class _AssetThumb extends StatefulWidget {
  const _AssetThumb({required this.asset, required this.placeholder});
  final HaptAsset asset;
  final Color placeholder;

  @override
  State<_AssetThumb> createState() => _AssetThumbState();
}

class _AssetThumbState extends State<_AssetThumb>
    with AutomaticKeepAliveClientMixin<_AssetThumb> {
  late Future<Uint8List?> _future;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _future = widget.asset.readThumbnail(width: 280, height: 280);
  }

  @override
  void didUpdateWidget(_AssetThumb old) {
    super.didUpdateWidget(old);
    if (old.asset.id != widget.asset.id) {
      _future = widget.asset.readThumbnail(width: 280, height: 280);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return FutureBuilder<Uint8List?>(
      future: _future,
      builder: (_, snap) {
        final bytes = snap.data;
        if (bytes == null) return Container(color: widget.placeholder);
        return Image.memory(
          bytes,
          fit: BoxFit.cover,
          gaplessPlayback: true,
        );
      },
    );
  }
}

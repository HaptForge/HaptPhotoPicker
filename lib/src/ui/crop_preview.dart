import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../config/picker_config.dart';
import '../config/picker_strings.dart';
import '../config/picker_theme.dart';
import '../controller/picker_controller.dart';
import '../data/asset.dart';

/// The big preview at the top of the picker that mirrors Instagram's
/// "current focus" rectangle. Shows the FIRST selected asset (or
/// the most-recently-tapped one if nothing's selected yet) at the
/// active aspect ratio.
///
/// v0.1 renders a static preview + the aspect-ratio chip row below.
/// Gesture-based cropping (pan + pinch + magnetic snap) is a 0.2
/// item — the controller already tracks the aspect ratio so wiring
/// gestures later is a UI-only change.
class CropPreview extends StatelessWidget {
  const CropPreview({
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
    final featured = _featured();
    final ratio = controller.aspectRatio.ratio ??
        (featured == null
            ? 1.0
            : featured.width / (featured.height == 0 ? 1 : featured.height));
    return Column(
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: t.spacing.md),
          child: AspectRatio(
            aspectRatio: ratio,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(t.radii.cropFrame),
              child: featured == null
                  ? _placeholderTile(t)
                  : _AssetThumb(
                      asset: featured,
                      placeholder: t.colors.thumbnailPlaceholder,
                      width: 800,
                      height: 800,
                    ),
            ),
          ),
        ),
        SizedBox(height: t.spacing.xs),
        if (controller.config.aspectRatios.length > 1)
          _AspectRatioChips(
            theme: t,
            strings: strings,
            controller: controller,
          ),
      ],
    );
  }

  HaptAsset? _featured() {
    if (controller.selection.isNotEmpty) return controller.selection.first;
    if (controller.assets.isNotEmpty) return controller.assets.first;
    return null;
  }

  Widget _placeholderTile(HaptPickerTheme t) =>
      Container(color: t.colors.thumbnailPlaceholder);
}

class _AspectRatioChips extends StatelessWidget {
  const _AspectRatioChips({
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
    return SizedBox(
      height: 32,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: t.spacing.md),
        itemCount: controller.config.aspectRatios.length,
        separatorBuilder: (_, __) => SizedBox(width: t.spacing.xs),
        itemBuilder: (_, i) {
          final r = controller.config.aspectRatios[i];
          final active = controller.aspectRatio == r;
          return GestureDetector(
            onTap: () => controller.setAspectRatio(r),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: EdgeInsets.symmetric(
                  horizontal: t.spacing.sm, vertical: t.spacing.xxs),
              decoration: BoxDecoration(
                color: active ? t.colors.primary : t.colors.surfaceElevated,
                borderRadius: BorderRadius.circular(t.radii.button),
              ),
              child: Center(
                child: Text(
                  _labelFor(r, strings),
                  style: t.typography.label.copyWith(
                    color:
                        active ? t.colors.onPrimary : t.colors.textPrimary,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  String _labelFor(HaptAspectRatio r, HaptPickerStrings s) {
    // Custom ratios pass their own literal label.
    if (r.label != null) return r.label!;
    switch (r.id) {
      case 'original':
        return s.aspectRatioOriginal;
      case 'square':
        return s.aspectRatioSquare;
      case 'portrait':
        return s.aspectRatioPortrait;
      case 'landscape':
        return s.aspectRatioLandscape;
      default:
        return r.id;
    }
  }
}

/// FutureBuilder wrapper that resolves the asset's thumbnail bytes
/// and paints them. Smaller than including a 3rd-party image lib
/// just for one use site.
class _AssetThumb extends StatelessWidget {
  const _AssetThumb({
    required this.asset,
    required this.placeholder,
    required this.width,
    required this.height,
  });

  final HaptAsset asset;
  final Color placeholder;
  final int width;
  final int height;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List?>(
      future: asset.readThumbnail(width: width, height: height),
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

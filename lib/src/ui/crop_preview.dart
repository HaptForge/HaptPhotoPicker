import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../config/picker_config.dart';
import '../config/picker_strings.dart';
import '../config/picker_theme.dart';
import '../controller/picker_controller.dart';
import '../data/asset.dart';

/// The big preview at the top of the picker. v0.2 introduces a fully
/// interactive crop:
///
///   • The asset image is wrapped in an `InteractiveViewer`. Pan +
///     pinch-zoom land in the controller's per-asset crop state so
///     switching between selected items remembers each one's framing.
///   • Aspect ratio chips drive a real frame — the visible window
///     becomes 1:1 / 4:5 / 16:9 etc. and the image is repositioned
///     via `BoxFit.cover` so the chosen frame is always filled.
///   • A rotate button (90° clockwise) sits in the top-right; the
///     `Transform.rotate` wraps the image so the rotation rides
///     along with the InteractiveViewer's pan / zoom.
///   • A thirds grid overlay paints while the user is interacting
///     and fades out 200 ms after the gesture ends.
///
/// All of this only handles the PREVIEW. Applying the crop to the
/// output bytes is `HaptCropEngine`'s job — it reads the same crop
/// state during the Done-tap pipeline.
class CropPreview extends StatefulWidget {
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
  State<CropPreview> createState() => _CropPreviewState();
}

class _CropPreviewState extends State<CropPreview> {
  final TransformationController _transform = TransformationController();
  bool _interacting = false;
  String? _wiredAssetId;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_syncFromController);
    _transform.addListener(_pushTransformToController);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_syncFromController);
    _transform.removeListener(_pushTransformToController);
    _transform.dispose();
    super.dispose();
  }

  /// When the controller's featured asset changes (user picked a
  /// different thumbnail), seed the InteractiveViewer with that
  /// asset's stored crop transform. Without this every switch would
  /// reset to identity.
  void _syncFromController() {
    final a = widget.controller.featuredAsset;
    if (a == null) return;
    if (a.id == _wiredAssetId) return;
    _wiredAssetId = a.id;
    final state = widget.controller.cropFor(a);
    final m = Matrix4.identity()
      ..translate(state.translation.dx, state.translation.dy)
      ..scale(state.scale);
    _transform.removeListener(_pushTransformToController);
    _transform.value = m;
    _transform.addListener(_pushTransformToController);
  }

  void _pushTransformToController() {
    final a = widget.controller.featuredAsset;
    if (a == null) return;
    final m = _transform.value;
    final t = m.getTranslation();
    widget.controller.setCropFor(
      a,
      widget.controller.cropFor(a).copyWith(
            scale: m.getMaxScaleOnAxis(),
            translation: Offset(t.x, t.y),
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.theme;
    final featured = widget.controller.featuredAsset;

    // Frame ratio — chosen aspect ratio chip drives the visible
    // window. "Original" falls back to the asset's intrinsic ratio
    // so the preview defaults to no-crop.
    final frameRatio = widget.controller.aspectRatio.ratio ??
        (featured == null
            ? 1.0
            : featured.width /
                (featured.height == 0 ? 1 : featured.height));

    // Cap preview to 42% of viewport — leaves room for the chips
    // + grid below on smaller phones.
    final media = MediaQuery.of(context);
    final maxHeight = media.size.height * 0.42;

    return Column(
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: t.spacing.md),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxHeight),
            child: AspectRatio(
              aspectRatio: frameRatio,
              child: _CropCanvas(
                theme: t,
                asset: featured,
                rotationQuarters: featured == null
                    ? 0
                    : widget.controller
                        .cropFor(featured)
                        .rotationQuarters,
                transformController: _transform,
                interacting: _interacting,
                onInteractionStart: () =>
                    setState(() => _interacting = true),
                onInteractionEnd: () =>
                    setState(() => _interacting = false),
                onRotate: () =>
                    widget.controller.rotateFeaturedClockwise(),
              ),
            ),
          ),
        ),
        SizedBox(height: t.spacing.xs),
        if (widget.controller.config.aspectRatios.length > 1)
          _AspectRatioChips(
            theme: t,
            strings: widget.strings,
            controller: widget.controller,
          ),
      ],
    );
  }
}

/// The actual crop canvas — InteractiveViewer over the asset image
/// + grid overlay + rotate button. Stateless because the parent
/// owns all the interaction state.
class _CropCanvas extends StatelessWidget {
  const _CropCanvas({
    required this.theme,
    required this.asset,
    required this.rotationQuarters,
    required this.transformController,
    required this.interacting,
    required this.onInteractionStart,
    required this.onInteractionEnd,
    required this.onRotate,
  });

  final HaptPickerTheme theme;
  final HaptAsset? asset;
  final int rotationQuarters;
  final TransformationController transformController;
  final bool interacting;
  final VoidCallback onInteractionStart;
  final VoidCallback onInteractionEnd;
  final VoidCallback onRotate;

  @override
  Widget build(BuildContext context) {
    final t = theme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(t.radii.cropFrame),
      child: Stack(
        fit: StackFit.expand,
        children: [
          DecoratedBox(
            decoration:
                BoxDecoration(color: t.colors.thumbnailPlaceholder),
          ),
          if (asset != null)
            InteractiveViewer(
              transformationController: transformController,
              minScale: 1.0,
              maxScale: 4.0,
              clipBehavior: Clip.hardEdge,
              boundaryMargin: EdgeInsets.zero,
              onInteractionStart: (_) => onInteractionStart(),
              onInteractionEnd: (_) => onInteractionEnd(),
              child: Transform.rotate(
                angle: rotationQuarters * math.pi / 2,
                child: _AssetThumb(
                  asset: asset!,
                  placeholder: t.colors.thumbnailPlaceholder,
                  width: 1400,
                  height: 1400,
                ),
              ),
            ),
          IgnorePointer(
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 200),
              opacity: interacting ? 1.0 : 0.0,
              child: CustomPaint(
                painter:
                    _ThirdsGridPainter(color: t.colors.cropFrameGuide),
              ),
            ),
          ),
          Positioned(
            top: 10,
            right: 10,
            child: _PillButton(
              theme: t,
              icon: Icons.rotate_right_rounded,
              onTap: onRotate,
            ),
          ),
        ],
      ),
    );
  }
}

class _PillButton extends StatelessWidget {
  const _PillButton({
    required this.theme,
    required this.icon,
    required this.onTap,
  });

  final HaptPickerTheme theme;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.55),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 36,
          height: 36,
          child: Icon(icon, color: Colors.white, size: 18),
        ),
      ),
    );
  }
}

class _ThirdsGridPainter extends CustomPainter {
  _ThirdsGridPainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;
    for (var i = 1; i < 3; i++) {
      final x = size.width * i / 3;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), p);
      final y = size.height * i / 3;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), p);
    }
  }

  @override
  bool shouldRepaint(covariant _ThirdsGridPainter old) =>
      old.color != color;
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
                color: active
                    ? t.colors.primary
                    : t.colors.surfaceElevated,
                borderRadius: BorderRadius.circular(t.radii.button),
              ),
              child: Center(
                child: Text(
                  _labelFor(r, strings),
                  style: t.typography.label.copyWith(
                    color: active
                        ? t.colors.onPrimary
                        : t.colors.textPrimary,
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

/// FutureBuilder-based thumbnail loader. Shared between the crop
/// canvas and the asset grid.
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

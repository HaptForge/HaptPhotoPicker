import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../config/picker_config.dart';
import '../config/picker_filter.dart';
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

/// Which editor tool panel is currently visible. Three tabs map to
/// the three things every consumer photo editor exposes:
///
///   - `crop`   — aspect ratio + rotate / flip transforms
///   - `filter` — preset color grades + intensity slider
///   - `adjust` — manual brightness / contrast / saturation / exposure
enum _EditorTool { crop, filter, adjust }

class _CropPreviewState extends State<CropPreview> {
  final TransformationController _transform = TransformationController();
  bool _interacting = false;
  String? _wiredAssetId;
  _EditorTool _tool = _EditorTool.crop;

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

    // Build the composed filter live so the preview shows preset +
    // intensity + adjustments combined. Keeps the on-screen image
    // in lockstep with what the engine will export on Done.
    final state = featured == null
        ? const HaptCropState.identity()
        : widget.controller.cropFor(featured);
    final effectiveFilter = HaptFilter.compose(
      preset: state.filter,
      intensity: state.filterIntensity,
      adjustments: state.adjustments,
    );
    final filters = widget.controller.config.filters;

    return Column(
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: t.spacing.md),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxHeight),
            child: AspectRatio(
              aspectRatio: frameRatio,
              // LayoutBuilder threads the actual rendered viewport
              // size back to the controller so the crop engine has
              // real numbers to invert the InteractiveViewer
              // transform with. Fires per layout-pass; the
              // controller's setter is a cheap no-op when the size
              // hasn't changed.
              child: LayoutBuilder(
                builder: (context, constraints) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (!mounted) return;
                    widget.controller.setPreviewViewportSize(
                      Size(constraints.maxWidth, constraints.maxHeight),
                    );
                  });
                  return _CropCanvas(
                    theme: t,
                    asset: featured,
                    rotationQuarters: state.rotationQuarters,
                    flipH: state.flipH,
                    flipV: state.flipV,
                    filter: effectiveFilter,
                    transformController: _transform,
                    interacting: _interacting,
                    onInteractionStart: () =>
                        setState(() => _interacting = true),
                    onInteractionEnd: () =>
                        setState(() => _interacting = false),
                  );
                },
              ),
            ),
          ),
        ),
        SizedBox(height: t.spacing.xs),
        // Tool surface — three tabs: Crop / Filter / Adjust.
        //
        // - Crop: always available (ratio chips + Rotate / Flip H /
        //   Flip V). If the config only ships one aspect ratio, the
        //   chips collapse to nothing but the action row stays.
        // - Filter: shown only when the config exposes ≥ 2 filters.
        // - Adjust: always available (manual sliders work on any
        //   image regardless of preset filters).
        //
        // Tabs render only when there are at least 2 visible panels;
        // otherwise we degrade to the single available panel
        // unchanged so the minimal-config case stays minimal.
        _buildToolSurface(t, featured, state, filters),
      ],
    );
  }

  Widget _buildToolSurface(
    HaptPickerTheme t,
    HaptAsset? featured,
    HaptCropState state,
    List<HaptFilter> filters,
  ) {
    if (featured == null) return const SizedBox.shrink();
    final hasFilters = filters.length > 1;
    // Crop and Adjust panels are always available. Filter is gated
    // on the config exposing ≥ 2 filters.
    final visiblePanels = <(_EditorTool, Widget)>[
      (
        _EditorTool.crop,
        _CropToolPanel(
          theme: t,
          strings: widget.strings,
          controller: widget.controller,
        ),
      ),
      if (hasFilters)
        (
          _EditorTool.filter,
          _FilterToolPanel(
            theme: t,
            strings: widget.strings,
            controller: widget.controller,
            asset: featured,
            state: state,
            filters: filters,
          ),
        ),
      (
        _EditorTool.adjust,
        _AdjustToolPanel(
          theme: t,
          strings: widget.strings,
          controller: widget.controller,
          adjustments: state.adjustments,
        ),
      ),
    ];
    // If somehow only one panel is visible (shouldn't happen since
    // Crop + Adjust are always present), show it bare. Otherwise
    // render the tab strip + the active panel.
    if (visiblePanels.length == 1) return visiblePanels.first.$2;

    // Sanitise active tab — if the user previously had Filter
    // selected but the config no longer exposes it, fall back to
    // Crop.
    final activeTool = visiblePanels.any((e) => e.$1 == _tool)
        ? _tool
        : _EditorTool.crop;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _EditorToolTabs(
          theme: t,
          strings: widget.strings,
          active: activeTool,
          available: visiblePanels.map((e) => e.$1).toList(growable: false),
          onTap: (tool) => setState(() => _tool = tool),
        ),
        SizedBox(height: t.spacing.xs),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          child: KeyedSubtree(
            key: ValueKey('panel-${activeTool.name}'),
            child: visiblePanels
                .firstWhere((e) => e.$1 == activeTool)
                .$2,
          ),
        ),
      ],
    );
  }
}

/// Tab strip below the crop canvas. Renders any subset of {Crop,
/// Filter, Adjust} depending on what the consumer config exposes —
/// Filter is gated on having ≥ 2 filters; Crop + Adjust are always
/// included. Each tab is icon + label.
class _EditorToolTabs extends StatelessWidget {
  const _EditorToolTabs({
    required this.theme,
    required this.strings,
    required this.active,
    required this.available,
    required this.onTap,
  });

  final HaptPickerTheme theme;
  final HaptPickerStrings strings;
  final _EditorTool active;
  final List<_EditorTool> available;
  final ValueChanged<_EditorTool> onTap;

  @override
  Widget build(BuildContext context) {
    final t = theme;
    return Container(
      margin: EdgeInsets.symmetric(horizontal: t.spacing.md),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: t.colors.surfaceElevated,
        borderRadius: BorderRadius.circular(t.radii.button),
      ),
      child: Row(
        children: [
          for (final tool in available)
            _ToolTab(
              theme: t,
              icon: _iconFor(tool),
              label: _labelFor(tool, strings),
              active: active == tool,
              onTap: () => onTap(tool),
            ),
        ],
      ),
    );
  }

  IconData _iconFor(_EditorTool tool) => switch (tool) {
        _EditorTool.crop => Icons.crop_rounded,
        _EditorTool.filter => Icons.auto_awesome_rounded,
        _EditorTool.adjust => Icons.tune_rounded,
      };

  String _labelFor(_EditorTool tool, HaptPickerStrings s) =>
      switch (tool) {
        _EditorTool.crop => s.editorToolCrop,
        _EditorTool.filter => s.editorToolFilter,
        _EditorTool.adjust => s.editorToolAdjust,
      };
}

class _ToolTab extends StatelessWidget {
  const _ToolTab({
    required this.theme,
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });
  final HaptPickerTheme theme;
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = theme;
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: active ? t.colors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(t.radii.button),
          ),
          alignment: Alignment.center,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 16,
                color: active ? t.colors.onPrimary : t.colors.textPrimary,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: t.typography.label.copyWith(
                  color: active ? t.colors.onPrimary : t.colors.textPrimary,
                  fontWeight:
                      active ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The actual crop canvas — InteractiveViewer over the asset image
/// + grid overlay. Rotate / flip controls moved into the Crop tool
/// panel below so the canvas itself stays gesture-clean.
class _CropCanvas extends StatelessWidget {
  const _CropCanvas({
    required this.theme,
    required this.asset,
    required this.rotationQuarters,
    required this.flipH,
    required this.flipV,
    required this.filter,
    required this.transformController,
    required this.interacting,
    required this.onInteractionStart,
    required this.onInteractionEnd,
  });

  final HaptPickerTheme theme;
  final HaptAsset? asset;
  final int rotationQuarters;

  /// Mirror flags. Applied as a `Transform.scale` on the asset
  /// subtree so the preview shows the mirrored image at zero CPU
  /// cost — the engine then applies the same mirror to the bytes
  /// on Done.
  final bool flipH;
  final bool flipV;

  /// Active color preset — applied via `ColorFiltered` so the live
  /// preview matches what the engine will export.
  final HaptFilter filter;

  final TransformationController transformController;
  final bool interacting;
  final VoidCallback onInteractionStart;
  final VoidCallback onInteractionEnd;

  @override
  Widget build(BuildContext context) {
    final t = theme;
    Widget assetTree = _AssetThumb(
      asset: asset!,
      placeholder: t.colors.thumbnailPlaceholder,
      width: 1400,
      height: 1400,
    );
    if (!filter.isIdentity) {
      assetTree = ColorFiltered(
        colorFilter: filter.toColorFilter(),
        child: assetTree,
      );
    }
    // Apply flip BEFORE rotation so the user sees a consistent
    // result regardless of the order they tapped flip vs rotate.
    if (flipH || flipV) {
      assetTree = Transform.scale(
        scaleX: flipH ? -1 : 1,
        scaleY: flipV ? -1 : 1,
        child: assetTree,
      );
    }
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
                child: assetTree,
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
        ],
      ),
    );
  }
}

// ─── Tool panel: Crop ───────────────────────────────────────────────

/// Crop-tab content — an action row (Rotate / Flip H / Flip V)
/// stacked above the aspect-ratio chips. Action buttons sit
/// outside the canvas so the canvas surface stays gesture-clean.
class _CropToolPanel extends StatelessWidget {
  const _CropToolPanel({
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
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: t.spacing.md),
          child: Row(
            children: [
              _ActionButton(
                theme: t,
                icon: Icons.rotate_right_rounded,
                label: strings.editorActionRotate,
                onTap: controller.rotateFeaturedClockwise,
              ),
              SizedBox(width: t.spacing.xs),
              _ActionButton(
                theme: t,
                icon: Icons.flip_rounded,
                label: strings.editorActionFlipH,
                onTap: controller.toggleFlipHForFeatured,
              ),
              SizedBox(width: t.spacing.xs),
              _ActionButton(
                theme: t,
                icon: Icons.flip_to_back_rounded,
                label: strings.editorActionFlipV,
                onTap: controller.toggleFlipVForFeatured,
              ),
            ],
          ),
        ),
        SizedBox(height: t.spacing.sm),
        if (controller.config.aspectRatios.length > 1)
          _AspectRatioChips(
            theme: t,
            strings: strings,
            controller: controller,
          ),
      ],
    );
  }
}

/// Square outlined button used inside the Crop tab's action row.
/// Icon above, label below — tappable target is the whole tile.
class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.theme,
    required this.icon,
    required this.label,
    required this.onTap,
  });
  final HaptPickerTheme theme;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = theme;
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: t.colors.surfaceElevated,
            borderRadius: BorderRadius.circular(t.radii.button),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: t.colors.textPrimary),
              SizedBox(height: t.spacing.xxs),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: t.typography.label.copyWith(
                  color: t.colors.textSecondary,
                  fontSize: 10.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Tool panel: Filter ─────────────────────────────────────────────

/// Filter-tab content — the existing filter strip + a 0..100%
/// intensity slider that only appears when a non-identity preset
/// is selected (no point editing the strength of "Original").
class _FilterToolPanel extends StatelessWidget {
  const _FilterToolPanel({
    required this.theme,
    required this.strings,
    required this.controller,
    required this.asset,
    required this.state,
    required this.filters,
  });

  final HaptPickerTheme theme;
  final HaptPickerStrings strings;
  final HaptPickerController controller;
  final HaptAsset asset;
  final HaptCropState state;
  final List<HaptFilter> filters;

  @override
  Widget build(BuildContext context) {
    final t = theme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _FilterStrip(
          theme: t,
          strings: strings,
          controller: controller,
          asset: asset,
          active: state.filter,
          filters: filters,
        ),
        if (!state.filter.isIdentity) ...[
          SizedBox(height: t.spacing.xs),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: t.spacing.md),
            child: _LabeledSlider(
              theme: t,
              label: strings.editorFilterIntensity,
              value: state.filterIntensity,
              min: 0.0,
              max: 1.0,
              displayPercent: true,
              onChanged: controller.setFilterIntensityForFeatured,
            ),
          ),
        ],
      ],
    );
  }
}

// ─── Tool panel: Adjust ─────────────────────────────────────────────

/// Adjust-tab content — 4 sliders (Brightness / Contrast /
/// Saturation / Exposure) + a Reset button that snaps all 4
/// back to identity. Reuses `HaptFilter` as the value type so
/// the params compose with the preset filter via the existing
/// `HaptFilter.compose` helper.
class _AdjustToolPanel extends StatelessWidget {
  const _AdjustToolPanel({
    required this.theme,
    required this.strings,
    required this.controller,
    required this.adjustments,
  });

  final HaptPickerTheme theme;
  final HaptPickerStrings strings;
  final HaptPickerController controller;
  final HaptFilter adjustments;

  void _set({
    double? saturation,
    double? contrast,
    double? brightness,
    double? exposure,
  }) {
    controller.setAdjustmentsForFeatured(
      HaptFilter(
        id: 'adjust',
        saturation: saturation ?? adjustments.saturation,
        contrast: contrast ?? adjustments.contrast,
        brightness: brightness ?? adjustments.brightness,
        exposure: exposure ?? adjustments.exposure,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = theme;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: t.spacing.md),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _LabeledSlider(
            theme: t,
            label: strings.editorAdjustBrightness,
            value: adjustments.brightness,
            min: 0.5,
            max: 1.5,
            centerValue: 1.0,
            onChanged: (v) => _set(brightness: v),
          ),
          _LabeledSlider(
            theme: t,
            label: strings.editorAdjustContrast,
            value: adjustments.contrast,
            min: 0.5,
            max: 1.8,
            centerValue: 1.0,
            onChanged: (v) => _set(contrast: v),
          ),
          _LabeledSlider(
            theme: t,
            label: strings.editorAdjustSaturation,
            value: adjustments.saturation,
            min: 0.0,
            max: 2.0,
            centerValue: 1.0,
            onChanged: (v) => _set(saturation: v),
          ),
          _LabeledSlider(
            theme: t,
            label: strings.editorAdjustExposure,
            value: adjustments.exposure,
            min: -1.0,
            max: 1.0,
            centerValue: 0.0,
            onChanged: (v) => _set(exposure: v),
          ),
          if (!adjustments.isIdentity) ...[
            SizedBox(height: t.spacing.xs),
            Align(
              alignment: Alignment.centerRight,
              child: GestureDetector(
                onTap: () => controller
                    .setAdjustmentsForFeatured(HaptFilter.original),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: t.colors.surfaceElevated,
                    borderRadius:
                        BorderRadius.circular(t.radii.button),
                  ),
                  child: Text(
                    strings.editorAdjustReset,
                    style: t.typography.label.copyWith(
                      color: t.colors.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Slider row with label + readout. `centerValue` (when supplied)
/// is the "neutral" point — for symmetric params (contrast/sat/
/// exposure) tapping the label snaps the value back to it.
/// `displayPercent` formats the readout as 0–100% instead of a
/// raw decimal (used for filter intensity).
class _LabeledSlider extends StatelessWidget {
  const _LabeledSlider({
    required this.theme,
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    this.centerValue,
    this.displayPercent = false,
  });

  final HaptPickerTheme theme;
  final String label;
  final double value;
  final double min;
  final double max;
  final double? centerValue;
  final bool displayPercent;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final t = theme;
    final readout = displayPercent
        ? '${(value.clamp(0.0, 1.0) * 100).round()}%'
        : value.toStringAsFixed(2);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: centerValue == null
                    ? null
                    : () => onChanged(centerValue!),
                child: Text(
                  label,
                  style: t.typography.label.copyWith(
                    color: t.colors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            Text(
              readout,
              style: t.typography.label.copyWith(
                color: t.colors.textSecondary,
                fontSize: 11,
              ),
            ),
          ],
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 3,
            thumbShape: const RoundSliderThumbShape(
                enabledThumbRadius: 8),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
            activeTrackColor: t.colors.primary,
            inactiveTrackColor:
                t.colors.primary.withValues(alpha: 0.18),
            thumbColor: t.colors.primary,
            overlayColor:
                t.colors.primary.withValues(alpha: 0.16),
          ),
          child: Slider(
            value: value.clamp(min, max),
            min: min,
            max: max,
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
}

/// Horizontal strip of filter chips beneath the crop preview. Each
/// chip shows a live thumbnail of the active asset with that
/// filter's matrix applied — uses the same parameters as the main
/// preview so chips and exported bytes stay in sync.
///
/// Stateful so we can capture the asset's 120-px thumbnail Future
/// ONCE on the active asset and reuse the bytes across all 8
/// filter chips. Without this caching, the previous build re-fetched
/// the same thumbnail per-chip per-rebuild, which flickered every
/// time the user tapped a filter (which itself triggers a rebuild).
class _FilterStrip extends StatefulWidget {
  const _FilterStrip({
    required this.theme,
    required this.strings,
    required this.controller,
    required this.asset,
    required this.active,
    required this.filters,
  });

  final HaptPickerTheme theme;
  final HaptPickerStrings strings;
  final HaptPickerController controller;
  final HaptAsset asset;
  final HaptFilter active;
  final List<HaptFilter> filters;

  @override
  State<_FilterStrip> createState() => _FilterStripState();
}

class _FilterStripState extends State<_FilterStrip> {
  late Future<Uint8List?> _bytes;

  @override
  void initState() {
    super.initState();
    _bytes = widget.asset.readThumbnail(width: 120, height: 120);
  }

  @override
  void didUpdateWidget(_FilterStrip old) {
    super.didUpdateWidget(old);
    if (old.asset.id != widget.asset.id) {
      _bytes = widget.asset.readThumbnail(width: 120, height: 120);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.theme;
    return SizedBox(
      // Compact-but-readable. 48-px chip + 4-px gap + 11-px label =
      // ~64-px strip. Tested down to iPhone SE 1st-gen-class viewports
      // where the previous 78-px strip squeezed the asset grid below
      // the usability threshold.
      height: 66,
      child: FutureBuilder<Uint8List?>(
        future: _bytes,
        builder: (_, snap) {
          final bytes = snap.data;
          return ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.symmetric(horizontal: t.spacing.md),
            itemCount: widget.filters.length,
            separatorBuilder: (_, __) => SizedBox(width: t.spacing.xs),
            itemBuilder: (_, i) {
              final f = widget.filters[i];
              final isActive = f == widget.active;
              return GestureDetector(
                onTap: () => widget.controller.setFilterForFeatured(f),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(9),
                        border: Border.all(
                          color: isActive
                              ? t.colors.primary
                              : Colors.transparent,
                          width: 2,
                        ),
                      ),
                      padding: const EdgeInsets.all(1.5),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(7),
                        child: bytes == null
                            ? Container(
                                color: t.colors.thumbnailPlaceholder)
                            : _FilterPreviewThumb(
                                bytes: bytes,
                                filter: f,
                              ),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _labelFor(f, widget.strings),
                      style: t.typography.label.copyWith(
                        color: isActive
                            ? t.colors.primary
                            : t.colors.textSecondary,
                        fontWeight:
                            isActive ? FontWeight.w700 : FontWeight.w500,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  String _labelFor(HaptFilter f, HaptPickerStrings s) {
    if (f.label != null) return f.label!;
    return s.filterLabel(f.id);
  }
}

/// Pure render of pre-fetched bytes under a filter matrix. No
/// FutureBuilder here — the parent strip owns the single shared
/// Future for the asset.
class _FilterPreviewThumb extends StatelessWidget {
  const _FilterPreviewThumb({
    required this.bytes,
    required this.filter,
  });

  final Uint8List bytes;
  final HaptFilter filter;

  @override
  Widget build(BuildContext context) {
    final img = Image.memory(
      bytes,
      fit: BoxFit.cover,
      gaplessPlayback: true,
    );
    if (filter.isIdentity) return img;
    return ColorFiltered(
      colorFilter: filter.toColorFilter(),
      child: img,
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

/// Stateful thumbnail loader. The Future is captured once per
/// (asset, dimensions) tuple — without this, every parent rebuild
/// (filter selection, transform tick, etc.) starts a fresh
/// `readThumbnail` call and the image flickers between the cached
/// resolution and the placeholder while photo_manager re-honors
/// the request. `gaplessPlayback` plus a stable Future keeps the
/// preview rock-steady across rebuilds.
class _AssetThumb extends StatefulWidget {
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
  State<_AssetThumb> createState() => _AssetThumbState();
}

class _AssetThumbState extends State<_AssetThumb> {
  late Future<Uint8List?> _bytes;

  @override
  void initState() {
    super.initState();
    _bytes = widget.asset.readThumbnail(
      width: widget.width,
      height: widget.height,
    );
  }

  @override
  void didUpdateWidget(_AssetThumb old) {
    super.didUpdateWidget(old);
    if (old.asset.id != widget.asset.id ||
        old.width != widget.width ||
        old.height != widget.height) {
      _bytes = widget.asset.readThumbnail(
        width: widget.width,
        height: widget.height,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List?>(
      future: _bytes,
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

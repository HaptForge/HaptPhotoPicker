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
    this.showToolSurface = true,
    this.maxHeightFraction = 0.42,
  });

  final HaptPickerTheme theme;
  final HaptPickerStrings strings;
  final HaptPickerController controller;

  /// When false, only the image canvas renders — no tabs, no aspect
  /// chips, no rotate / flip / dial. Set to false when the parent
  /// (`HaptPickerSheet`) drives a full-screen drill-in editor and
  /// owns the tool surface itself. Default true preserves the
  /// pre-0.8 single-screen layout for consumers using the picker
  /// outside the bundled sheet.
  final bool showToolSurface;

  /// What share of the screen height the preview canvas may occupy.
  /// Default 0.42 fits comfortably above the tool surface + asset
  /// grid. In drill-in mode the picker bumps this to ~0.7 so the
  /// preview grows when the grid is hidden.
  final double maxHeightFraction;

  @override
  State<CropPreview> createState() => _CropPreviewState();
}

/// Which editor tool panel is currently visible. Drill-in pattern:
/// tapping a launcher in the picker pushes a tool-specific screen
/// that fills the same vertical real estate the asset grid had.
///
///   - `crop`   — aspect ratio chips only
///   - `filter` — preset color grades + intensity slider
///   - `rotate` — discrete 90° rotate + flip H/V + fine-rotation dial
///   - `adjust` — manual brightness / contrast / saturation / exposure
enum EditorTool { crop, filter, rotate, adjust }

/// Legacy alias for callers still using the v0.7 internal tool enum.
/// Kept as a private typedef so the public surface stays clean.
typedef _EditorTool = EditorTool;

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

    // Cap preview height by the fraction the caller chose. 0.42 in
    // gallery mode (room for tool buttons + asset grid); ~0.7 in
    // drill-in mode (no grid below; let the preview breathe).
    final media = MediaQuery.of(context);
    final maxHeight = media.size.height * widget.maxHeightFraction;

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
                    rotationFine: state.rotationFine,
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
        if (widget.showToolSurface) ...[
          SizedBox(height: t.spacing.xs),
          // Legacy in-preview tool tabs. Off by default when the
          // parent uses drill-in mode (the picker sheet renders its
          // own launcher row + dedicated tool screens).
          _buildToolSurface(t, featured, state, filters),
        ],
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
        _EditorTool.rotate => Icons.rotate_right_rounded,
        _EditorTool.adjust => Icons.tune_rounded,
      };

  String _labelFor(_EditorTool tool, HaptPickerStrings s) =>
      switch (tool) {
        _EditorTool.crop => s.editorToolCrop,
        _EditorTool.filter => s.editorToolFilter,
        _EditorTool.rotate => s.editorActionRotate,
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
    required this.rotationFine,
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

  /// Fine-grained rotation in degrees (clamped ±45° by the controller).
  /// Composed with [rotationQuarters] at render time.
  final double rotationFine;

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
                angle: rotationQuarters * math.pi / 2 +
                    rotationFine * math.pi / 180,
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
/// Two submodes of the Crop tab — only one detail surface is visible
/// at a time so the panel stays compact and the asset grid below
/// keeps its real estate. Apple Photos uses the same drill-down: a
/// row of icon affordances on top, and the chosen affordance's
/// detail UI fills the slot below it.
enum _CropSubmode { aspect, straighten }

class _CropToolPanel extends StatefulWidget {
  const _CropToolPanel({
    required this.theme,
    required this.strings,
    required this.controller,
  });

  final HaptPickerTheme theme;
  final HaptPickerStrings strings;
  final HaptPickerController controller;

  @override
  State<_CropToolPanel> createState() => _CropToolPanelState();
}

class _CropToolPanelState extends State<_CropToolPanel> {
  /// Default to Aspect — the most-frequent operation. Straighten /
  /// rotate / flip are tools users reach for occasionally; aspect
  /// is the one they hit on every pick when targeting a 1:1 avatar,
  /// 4:5 portrait, etc.
  _CropSubmode _submode = _CropSubmode.aspect;

  @override
  Widget build(BuildContext context) {
    final t = widget.theme;
    final hasAspect = widget.controller.config.aspectRatios.length > 1;
    // If aspect-ratio support isn't configured, default + only mode
    // is Straighten. Selecting Aspect would render an empty area.
    if (!hasAspect && _submode == _CropSubmode.aspect) {
      _submode = _CropSubmode.straighten;
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Toolbar — horizontally scrollable in case a future build
        // ships more actions than fit on a narrow phone.
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: EdgeInsets.symmetric(horizontal: t.spacing.md),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (hasAspect)
                _CropToolbarToggle(
                  theme: t,
                  icon: Icons.aspect_ratio_rounded,
                  label: widget.strings.editorActionRotate,
                  // Reuse the existing localised label — "Aspect" is
                  // self-evident from the icon and avoids adding a
                  // 9-locale string churn for one word.
                  active: _submode == _CropSubmode.aspect,
                  onTap: () =>
                      setState(() => _submode = _CropSubmode.aspect),
                ),
              if (hasAspect) SizedBox(width: t.spacing.xs),
              _CropToolbarToggle(
                theme: t,
                icon: Icons.straighten_rounded,
                label: widget.strings.editorActionRotate,
                active: _submode == _CropSubmode.straighten,
                onTap: () => setState(
                    () => _submode = _CropSubmode.straighten),
              ),
              SizedBox(width: t.spacing.xs),
              // Rotate 90° / Flip H / Flip V are IMMEDIATE actions,
              // not toggles. They fire on tap and don't switch the
              // detail surface — that's how Apple's editor handles
              // discrete one-shot operations vs continuous tools.
              _CropToolbarAction(
                theme: t,
                icon: Icons.rotate_right_rounded,
                onTap: widget.controller.rotateFeaturedClockwise,
              ),
              SizedBox(width: t.spacing.xs),
              _CropToolbarAction(
                theme: t,
                icon: Icons.flip_rounded,
                onTap: widget.controller.toggleFlipHForFeatured,
              ),
              SizedBox(width: t.spacing.xs),
              _CropToolbarAction(
                theme: t,
                icon: Icons.flip_to_back_rounded,
                onTap: widget.controller.toggleFlipVForFeatured,
              ),
            ],
          ),
        ),
        SizedBox(height: t.spacing.sm),
        // Detail surface — ONLY the active submode's UI renders.
        // Both bodies have similar vertical height (~52 px) so
        // switching submodes doesn't reflow the asset grid below.
        if (_submode == _CropSubmode.aspect && hasAspect)
          _AspectRatioChips(
            theme: t,
            strings: widget.strings,
            controller: widget.controller,
          )
        else if (_submode == _CropSubmode.straighten)
          _RotationDial(theme: t, controller: widget.controller),
      ],
    );
  }
}

/// Pill-shaped toggle used in the Crop toolbar to switch which
/// detail UI is visible below. Active state = filled, inactive =
/// outlined. Compact (icon + nothing) so 5 fit on a narrow phone.
class _CropToolbarToggle extends StatelessWidget {
  const _CropToolbarToggle({
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
    return Semantics(
      label: label,
      selected: active,
      button: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          width: 44,
          height: 36,
          decoration: BoxDecoration(
            color: active
                ? t.colors.primary
                : t.colors.surfaceElevated,
            borderRadius: BorderRadius.circular(t.radii.button),
            border: Border.all(
              color: active
                  ? t.colors.primary
                  : t.colors.border,
              width: 1,
            ),
          ),
          alignment: Alignment.center,
          child: Icon(
            icon,
            size: 18,
            color: active ? t.colors.onPrimary : t.colors.textPrimary,
          ),
        ),
      ),
    );
  }
}

/// Fire-and-forget action button (rotate 90°, flip H/V). Same
/// dimensions as [_CropToolbarToggle] so the toolbar reads as one
/// cohesive row even though the two button types have different
/// semantics.
class _CropToolbarAction extends StatelessWidget {
  const _CropToolbarAction({
    required this.theme,
    required this.icon,
    required this.onTap,
  });

  final HaptPickerTheme theme;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = theme;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 44,
        height: 36,
        decoration: BoxDecoration(
          color: t.colors.surfaceElevated,
          borderRadius: BorderRadius.circular(t.radii.button),
          border: Border.all(color: t.colors.border, width: 1),
        ),
        alignment: Alignment.center,
        child: Icon(icon, size: 18, color: t.colors.textPrimary),
      ),
    );
  }
}

/// Horizontal degree dial — Apple Photos-style.
///
/// Drag-to-rotate gesture maps horizontal pixel deltas onto a ±45°
/// range. A tick rail underneath shows whole-degree ticks every 1°
/// with major ticks every 5°. Centred 0° has a strong dead-zone
/// snap (controller enforces 0.5° dead-band) so users can return to
/// "no rotation" by feel alone. Numeric readout above the rail
/// shows the current angle to 1 decimal.
///
/// Idiom matches the Crop / Straighten dial in Apple's iOS Photos
/// editor (the screenshot the user referenced): single thumb-like
/// indicator line at centre, ticks moving past it as you drag.
class _RotationDial extends StatefulWidget {
  const _RotationDial({required this.theme, required this.controller});

  final HaptPickerTheme theme;
  final HaptPickerController controller;

  @override
  State<_RotationDial> createState() => _RotationDialState();
}

class _RotationDialState extends State<_RotationDial> {
  /// Drag sensitivity: 1.6 px = 1° of rotation. Tuned so a full
  /// span of the dial (±45° = 90° of rotation) is ~145 px of finger
  /// travel — comfortable thumb sweep on a phone.
  static const double _pxPerDegree = 1.6;

  static const double _minDeg = -45;
  static const double _maxDeg = 45;

  @override
  Widget build(BuildContext context) {
    final t = widget.theme;
    final featured = widget.controller.featuredAsset;
    final current =
        featured == null ? 0.0 : widget.controller.cropFor(featured).rotationFine;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: t.spacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Numeric readout — Apple shows "0°" centered; we match.
          Center(
            child: Text(
              '${current >= 0 ? '+' : ''}${current.toStringAsFixed(1)}°',
              style: t.typography.label.copyWith(
                color: current.abs() < 0.5
                    ? t.colors.textSecondary
                    : t.colors.primary,
                fontWeight: FontWeight.w600,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          SizedBox(height: t.spacing.xs),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onHorizontalDragUpdate: (d) {
              final delta = d.delta.dx / _pxPerDegree;
              // We invert because dragging LEFT should INCREASE the
              // angle clockwise (image rotates right when ticks
              // scroll left — same direction as the user's wrist).
              final next = (current - delta).clamp(_minDeg, _maxDeg);
              widget.controller.setRotationFineForFeatured(next);
            },
            child: SizedBox(
              height: 36,
              child: CustomPaint(
                painter: _DialTickPainter(
                  degrees: current,
                  tickColor: t.colors.textSecondary.withValues(alpha: 0.4),
                  majorTickColor: t.colors.textPrimary.withValues(alpha: 0.65),
                  indicatorColor: t.colors.primary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Paints the horizontal tick rail + the centre indicator. Ticks
/// every 1° (minor) and every 5° (major, taller + slightly bolder).
/// The rail "moves" relative to the indicator: at +10° rotation,
/// the 10° tick sits under the indicator.
class _DialTickPainter extends CustomPainter {
  _DialTickPainter({
    required this.degrees,
    required this.tickColor,
    required this.majorTickColor,
    required this.indicatorColor,
  });

  final double degrees;
  final Color tickColor;
  final Color majorTickColor;
  final Color indicatorColor;

  static const double _pxPerDegree = 4.0; // visual rail density

  @override
  void paint(Canvas canvas, Size size) {
    final centreX = size.width / 2;
    final centreY = size.height / 2;
    // Visible range: how many degrees fit on screen. Each side =
    // (width/2) / pxPerDegree. We only paint visible ticks.
    final visiblePerSide = (size.width / 2 / _pxPerDegree).ceil();
    final minorPaint = Paint()
      ..color = tickColor
      ..strokeWidth = 1;
    final majorPaint = Paint()
      ..color = majorTickColor
      ..strokeWidth = 1.5;
    for (var deg = -visiblePerSide; deg <= visiblePerSide; deg++) {
      // Anchor each tick at its "rotation value" then offset by the
      // current degrees so the rail slides left when degrees goes up.
      final tickDeg = deg.toDouble();
      final offset = (tickDeg - degrees) * _pxPerDegree;
      final x = centreX + offset;
      if (x < -2 || x > size.width + 2) continue;
      final isMajor = deg % 5 == 0;
      final h = isMajor ? 16.0 : 8.0;
      canvas.drawLine(
        Offset(x, centreY - h / 2),
        Offset(x, centreY + h / 2),
        isMajor ? majorPaint : minorPaint,
      );
    }
    // Centre indicator — vertical brand-coloured bar.
    final indicator = Paint()
      ..color = indicatorColor
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(centreX, centreY - 14),
      Offset(centreX, centreY + 14),
      indicator,
    );
  }

  @override
  bool shouldRepaint(_DialTickPainter old) =>
      old.degrees != degrees ||
      old.indicatorColor != indicatorColor;
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

// ─── Public tool view ────────────────────────────────────────────────

/// Dispatcher widget that renders the controls for one [EditorTool].
/// Drives the bottom half of each drill-in tool screen in
/// `HaptPickerSheet`. The host owns the chrome (back button, Done
/// button) and the bigger image preview above; this widget just
/// renders the tool-specific controls.
///
/// For consumers using `CropPreview` outside the bundled sheet, the
/// legacy in-preview tab strip still renders by default; this
/// dispatcher is the v0.8+ drill-in path.
class EditorToolView extends StatelessWidget {
  const EditorToolView({
    super.key,
    required this.tool,
    required this.theme,
    required this.strings,
    required this.controller,
  });

  final EditorTool tool;
  final HaptPickerTheme theme;
  final HaptPickerStrings strings;
  final HaptPickerController controller;

  @override
  Widget build(BuildContext context) {
    final featured = controller.featuredAsset;
    if (featured == null) return const SizedBox.shrink();
    final state = controller.cropFor(featured);
    final filters = controller.config.filters;
    final hasAspect = controller.config.aspectRatios.length > 1;
    switch (tool) {
      case EditorTool.crop:
        return hasAspect
            ? _AspectRatioChips(
                theme: theme,
                strings: strings,
                controller: controller,
              )
            : const SizedBox.shrink();
      case EditorTool.filter:
        if (filters.length < 2) return const SizedBox.shrink();
        return _FilterToolPanel(
          theme: theme,
          strings: strings,
          controller: controller,
          asset: featured,
          state: state,
          filters: filters,
        );
      case EditorTool.rotate:
        return _RotateToolPanel(
          theme: theme,
          strings: strings,
          controller: controller,
        );
      case EditorTool.adjust:
        return _AdjustToolPanel(
          theme: theme,
          strings: strings,
          controller: controller,
          adjustments: state.adjustments,
        );
    }
  }
}

/// Rotate tool — three discrete actions (90°, flip H, flip V) above
/// the fine-rotation dial. Lays out roomier than the old crop-tab
/// did because it has its own full drill-in screen instead of
/// sharing space with aspect chips.
class _RotateToolPanel extends StatelessWidget {
  const _RotateToolPanel({
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
        // Action row — pill buttons evenly spaced, big enough to
        // tap comfortably with the thumb. No detail surface (these
        // are one-shot actions).
        Padding(
          padding: EdgeInsets.symmetric(horizontal: t.spacing.md),
          child: Row(
            children: [
              Expanded(
                child: _RotateActionPill(
                  theme: t,
                  icon: Icons.rotate_right_rounded,
                  label: strings.editorActionRotate,
                  onTap: controller.rotateFeaturedClockwise,
                ),
              ),
              SizedBox(width: t.spacing.sm),
              Expanded(
                child: _RotateActionPill(
                  theme: t,
                  icon: Icons.flip_rounded,
                  label: strings.editorActionFlipH,
                  onTap: controller.toggleFlipHForFeatured,
                ),
              ),
              SizedBox(width: t.spacing.sm),
              Expanded(
                child: _RotateActionPill(
                  theme: t,
                  icon: Icons.flip_to_back_rounded,
                  label: strings.editorActionFlipV,
                  onTap: controller.toggleFlipVForFeatured,
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: t.spacing.md),
        _RotationDial(theme: t, controller: controller),
      ],
    );
  }
}

class _RotateActionPill extends StatelessWidget {
  const _RotateActionPill({
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
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        height: 56,
        decoration: BoxDecoration(
          color: t.colors.surfaceElevated,
          borderRadius: BorderRadius.circular(t.radii.button),
          border: Border.all(color: t.colors.border, width: 1),
        ),
        alignment: Alignment.center,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 20, color: t.colors.textPrimary),
            SizedBox(height: t.spacing.xxs),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: t.typography.label.copyWith(
                color: t.colors.textSecondary,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Compact icon button row used in `HaptPickerSheet`'s gallery mode
/// to launch a drill-in tool screen. One pill per [EditorTool] the
/// config exposes; tapping pushes the corresponding tool view.
class EditorToolLauncher extends StatelessWidget {
  const EditorToolLauncher({
    super.key,
    required this.theme,
    required this.strings,
    required this.controller,
    required this.onLaunch,
  });

  final HaptPickerTheme theme;
  final HaptPickerStrings strings;
  final HaptPickerController controller;
  final ValueChanged<EditorTool> onLaunch;

  @override
  Widget build(BuildContext context) {
    final t = theme;
    final filtersAvailable = controller.config.filters.length >= 2;
    final aspectAvailable = controller.config.aspectRatios.length > 1;
    final tools = <(EditorTool, IconData, String)>[
      if (aspectAvailable)
        (EditorTool.crop, Icons.crop_rounded, strings.editorToolCrop),
      if (filtersAvailable)
        (EditorTool.filter, Icons.auto_awesome_rounded,
            strings.editorToolFilter),
      (EditorTool.rotate, Icons.rotate_right_rounded,
          strings.editorActionRotate),
      (EditorTool.adjust, Icons.tune_rounded, strings.editorToolAdjust),
    ];
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: t.spacing.md,
        vertical: t.spacing.xs,
      ),
      child: Row(
        children: [
          for (var i = 0; i < tools.length; i++) ...[
            if (i > 0) SizedBox(width: t.spacing.sm),
            Expanded(
              child: _LauncherTile(
                theme: t,
                icon: tools[i].$2,
                label: tools[i].$3,
                onTap: () => onLaunch(tools[i].$1),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _LauncherTile extends StatelessWidget {
  const _LauncherTile({
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
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 56,
        decoration: BoxDecoration(
          color: t.colors.surfaceElevated,
          borderRadius: BorderRadius.circular(t.radii.button),
          border: Border.all(color: t.colors.border, width: 1),
        ),
        alignment: Alignment.center,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 20, color: t.colors.textPrimary),
            SizedBox(height: t.spacing.xxs),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: t.typography.label.copyWith(
                color: t.colors.textSecondary,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

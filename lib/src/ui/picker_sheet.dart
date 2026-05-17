import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart' as pm;

import '../api.dart';
import '../config/picker_config.dart';
import '../config/picker_strings.dart';
import '../config/picker_theme.dart';
import '../controller/picker_controller.dart';
import '../data/album.dart';
import '../pipeline/asset_transform.dart';
import '../pipeline/crop_engine.dart';
import '../util/haptics.dart';
import 'asset_grid.dart';
import 'crop_preview.dart';
import 'permission_state.dart';
import 'sheet_chrome.dart';

/// Root of the picker UI. Owns the controller + permission flow +
/// post-pipeline orchestration. Lays out the three rows:
///
///   [chrome: Cancel + title + Done]
///   [crop preview]
///   [aspect ratio chips]
///   [asset grid (scrollable)]
class HaptPickerSheet extends StatefulWidget {
  const HaptPickerSheet({
    super.key,
    required this.config,
    required this.theme,
    required this.strings,
    required this.haptics,
    required this.pipeline,
  });

  final HaptPickerConfig config;
  final HaptPickerTheme theme;
  final HaptPickerStrings strings;
  final HaptHaptics haptics;
  final List<HaptAssetTransform> pipeline;

  @override
  State<HaptPickerSheet> createState() => _HaptPickerSheetState();
}

class _HaptPickerSheetState extends State<HaptPickerSheet> {
  late final HaptPickerController _controller = HaptPickerController(
    config: widget.config,
    haptics: widget.haptics,
  );

  Future<_PermissionGate>? _permissionFuture;

  @override
  void initState() {
    super.initState();
    _permissionFuture = _bootstrap();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Request photo permission, load albums, populate the first
  /// album's assets. Done in a single Future so the UI can render
  /// a clean loading shell.
  Future<_PermissionGate> _bootstrap() async {
    final state = await pm.PhotoManager.requestPermissionExtend();
    if (!state.hasAccess) {
      return _PermissionGate.denied(state);
    }
    final type = _mediaTypeToPm(widget.config.mediaType);
    final pmAlbums = await pm.PhotoManager.getAssetPathList(
      type: type,
      onlyAll: false,
    );
    final albums = <HaptAlbum>[];
    for (final p in pmAlbums) {
      albums.add(await HaptAlbum.fromPath(p));
    }
    // Sort: "All photos" first, then by descending asset count.
    albums.sort((a, b) {
      final aAll = a.name.toLowerCase().contains('all') ||
          a.name.toLowerCase().contains('recent');
      final bAll = b.name.toLowerCase().contains('all') ||
          b.name.toLowerCase().contains('recent');
      if (aAll && !bAll) return -1;
      if (!aAll && bAll) return 1;
      return b.assetCount.compareTo(a.assetCount);
    });
    _controller.albums = albums;
    if (albums.isNotEmpty) {
      _controller.assets = await albums.first.loadAssets();
    }
    return _PermissionGate.granted();
  }

  pm.RequestType _mediaTypeToPm(HaptMediaType t) {
    switch (t) {
      case HaptMediaType.image:
        return pm.RequestType.image;
      case HaptMediaType.video:
        return pm.RequestType.video;
      case HaptMediaType.any:
        return pm.RequestType.common;
    }
  }

  Future<void> _onDone() async {
    // Stash the navigator before awaiting so the lint stops fussing
    // about BuildContext use across async gaps. The State's
    // `mounted` guard still applies — we just don't reach back into
    // `context` after the await.
    final navigator = Navigator.of(context);
    final results = await _runPipeline();
    if (!mounted) return;
    await widget.haptics.fire(HaptHapticEvent.confirm);
    navigator.pop(results);
  }

  /// Apply the per-asset crop/rotate/zoom state first, then thread
  /// the cropped bytes through any user-registered transforms in
  /// order. Single-pass; transforms can no-op via
  /// `HaptTransformResult.passthrough`. The crop engine runs even
  /// when no transforms are registered, so consumers always get
  /// bytes that reflect what the user saw in the preview.
  Future<List<HaptPickerResult>> _runPipeline() async {
    final locale = Localizations.maybeLocaleOf(context)?.toLanguageTag() ?? 'en';
    final selection = _controller.selection;
    final frameRatio = _controller.aspectRatio;
    const crop = HaptCropEngine();
    final out = <HaptPickerResult>[];
    for (var i = 0; i < selection.length; i++) {
      final asset = selection[i];
      final ctx = HaptTransformContext(
        indexInSelection: i,
        totalSelected: selection.length,
        locale: locale,
      );
      Uint8List? bytes = await crop.apply(
        asset: asset,
        state: _controller.cropFor(asset),
        frameRatio: frameRatio,
        // Real viewport size from the crop preview's LayoutBuilder —
        // lets the engine map InteractiveViewer translation back to
        // source pixels with real geometry instead of a heuristic.
        viewportSize: _controller.previewViewportSize,
      );
      for (final t in widget.pipeline) {
        final r = await t.run(
          asset: asset,
          incomingBytes: bytes,
          context: ctx,
        );
        if (r.bytes != null) bytes = r.bytes;
      }
      out.add(HaptPickerResult(asset: asset, processedBytes: bytes));
    }
    return out;
  }

  void _onCancel() => Navigator.of(context).pop(null);

  @override
  Widget build(BuildContext context) {
    final t = widget.theme;
    return Container(
      decoration: BoxDecoration(
        color: t.colors.surface,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(t.radii.sheet),
        ),
        boxShadow: t.shadows.sheet,
      ),
      clipBehavior: Clip.antiAlias,
      child: FractionallySizedBox(
        heightFactor: 0.92,
        child: FutureBuilder<_PermissionGate>(
          future: _permissionFuture,
          builder: (_, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return _Loading(theme: t);
            }
            final gate = snap.data!;
            if (!gate.granted) {
              return PermissionDeniedView(
                theme: t,
                strings: widget.strings,
                onOpenSettings: () => pm.PhotoManager.openSetting(),
                onCancel: _onCancel,
              );
            }
            return _ListenableScaffold(
              controller: _controller,
              theme: t,
              strings: widget.strings,
              onDone: _onDone,
              onCancel: _onCancel,
            );
          },
        ),
      ),
    );
  }
}

class _Loading extends StatelessWidget {
  const _Loading({required this.theme});
  final HaptPickerTheme theme;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: CircularProgressIndicator(color: theme.colors.primary),
    );
  }
}

class _PermissionGate {
  const _PermissionGate._({required this.granted, this.state});
  final bool granted;
  final pm.PermissionState? state;
  factory _PermissionGate.granted() => const _PermissionGate._(granted: true);
  factory _PermissionGate.denied(pm.PermissionState s) =>
      _PermissionGate._(granted: false, state: s);
}

class _ListenableScaffold extends StatefulWidget {
  const _ListenableScaffold({
    required this.controller,
    required this.theme,
    required this.strings,
    required this.onDone,
    required this.onCancel,
  });

  final HaptPickerController controller;
  final HaptPickerTheme theme;
  final HaptPickerStrings strings;
  final VoidCallback onDone;
  final VoidCallback onCancel;

  @override
  State<_ListenableScaffold> createState() => _ListenableScaffoldState();
}

class _ListenableScaffoldState extends State<_ListenableScaffold> {
  /// Active tool screen. `null` = gallery mode (chrome + preview +
  /// launcher row + asset grid). Non-null = drill-in mode (chrome
  /// with Back button + bigger preview + tool controls + Done bar;
  /// asset grid hidden).
  EditorTool? _activeTool;

  void _enterTool(EditorTool t) => setState(() => _activeTool = t);
  void _exitTool() => setState(() => _activeTool = null);

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (_, __) {
        return _activeTool == null
            ? _buildGalleryMode()
            : _buildToolMode(_activeTool!);
      },
    );
  }

  Widget _buildGalleryMode() {
    final t = widget.theme;
    return Column(
      children: [
        PickerChrome(
          theme: t,
          strings: widget.strings,
          controller: widget.controller,
          onCancel: widget.onCancel,
          onDone: widget.onDone,
        ),
        CropPreview(
          theme: t,
          strings: widget.strings,
          controller: widget.controller,
          // Hide the legacy in-preview tabs — gallery mode now uses
          // a dedicated launcher row below the preview that pushes
          // each tool into its own drill-in screen.
          showToolSurface: false,
        ),
        SizedBox(height: t.spacing.xs),
        EditorToolLauncher(
          theme: t,
          strings: widget.strings,
          controller: widget.controller,
          onLaunch: _enterTool,
        ),
        SizedBox(height: t.spacing.xs),
        Expanded(
          child: AssetGrid(
            theme: t,
            strings: widget.strings,
            controller: widget.controller,
          ),
        ),
      ],
    );
  }

  Widget _buildToolMode(EditorTool tool) {
    final t = widget.theme;
    return Column(
      children: [
        // Tool chrome: back arrow on left, tool name in centre,
        // Done on right. Done in tool mode just exits the tool
        // (commits are already in the controller's state) — the
        // final picker-level Done lives in gallery mode and runs
        // the export pipeline.
        _ToolChrome(
          theme: t,
          title: _toolTitle(tool),
          doneLabel: widget.strings.doneLabelEmpty,
          onBack: _exitTool,
          onDone: _exitTool,
        ),
        // Bigger preview — no asset grid below, so we let it
        // breathe. 0.55 fits comfortably above the controls on a
        // standard iPhone 14 vs the 0.42 of gallery mode.
        CropPreview(
          theme: t,
          strings: widget.strings,
          controller: widget.controller,
          showToolSurface: false,
          maxHeightFraction: 0.55,
        ),
        // Tool's controls fill the remaining vertical space.
        Expanded(
          child: SingleChildScrollView(
            padding: EdgeInsets.only(top: t.spacing.md),
            child: EditorToolView(
              tool: tool,
              theme: t,
              strings: widget.strings,
              controller: widget.controller,
            ),
          ),
        ),
      ],
    );
  }

  String _toolTitle(EditorTool tool) {
    final s = widget.strings;
    switch (tool) {
      case EditorTool.crop:
        return s.editorToolCrop;
      case EditorTool.filter:
        return s.editorToolFilter;
      case EditorTool.rotate:
        return s.editorActionRotate;
      case EditorTool.adjust:
        return s.editorToolAdjust;
    }
  }
}

/// Chrome for a drill-in tool screen: back arrow → exits the tool,
/// tool name centred, Done → also exits the tool. Mirrors the
/// gallery-mode `PickerChrome` so the back/forward transition feels
/// like the same surface flipping pages, not a stack push.
class _ToolChrome extends StatelessWidget {
  const _ToolChrome({
    required this.theme,
    required this.title,
    required this.doneLabel,
    required this.onBack,
    required this.onDone,
  });

  final HaptPickerTheme theme;
  final String title;
  final String doneLabel;
  final VoidCallback onBack;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final t = theme;
    const sideSlot = 92.0;
    return Container(
      decoration: BoxDecoration(
        color: t.colors.surfaceElevated,
        border: Border(
          bottom: BorderSide(
            color: t.colors.border.withValues(alpha: 0.5),
            width: 0.5,
          ),
        ),
      ),
      padding: EdgeInsets.fromLTRB(
          t.spacing.md, t.spacing.sm, t.spacing.md, t.spacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: sideSlot,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(t.radii.button),
                  onTap: onBack,
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                        horizontal: t.spacing.xs,
                        vertical: t.spacing.xs),
                    child: Icon(
                      Icons.arrow_back_ios_new_rounded,
                      size: 18,
                      color: t.colors.textPrimary,
                    ),
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: Center(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: t.typography.button.copyWith(
                  color: t.colors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          SizedBox(
            width: sideSlot,
            child: Align(
              alignment: Alignment.centerRight,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(t.radii.button),
                  onTap: onDone,
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                        horizontal: t.spacing.md,
                        vertical: t.spacing.xs),
                    child: Text(
                      doneLabel,
                      style: t.typography.button.copyWith(
                        color: t.colors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

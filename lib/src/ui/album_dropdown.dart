import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../config/picker_strings.dart';
import '../config/picker_theme.dart';
import '../controller/picker_controller.dart';
import '../data/album.dart';

/// Inline pill that shows the current album name + a chevron.
/// Tap opens a modal bottom sheet listing every album. Used in
/// [PickerChrome].
class AlbumDropdown extends StatelessWidget {
  const AlbumDropdown({
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
    final album = controller.currentAlbum;
    return Semantics(
      label: strings.albumSwitcherA11yLabel,
      button: true,
      child: GestureDetector(
        onTap: controller.albums.isEmpty
            ? null
            : () => _openAlbumList(context),
        child: Container(
          padding: EdgeInsets.symmetric(
              horizontal: t.spacing.sm, vertical: t.spacing.xs),
          decoration: BoxDecoration(
            color: t.colors.surfaceElevated,
            borderRadius: BorderRadius.circular(t.radii.button),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  album?.name ?? strings.albumLoadingLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: t.typography.title
                      .copyWith(color: t.colors.textPrimary),
                ),
              ),
              SizedBox(width: t.spacing.xxs),
              Icon(Icons.keyboard_arrow_down_rounded,
                  size: 18, color: t.colors.textPrimary),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openAlbumList(BuildContext context) async {
    final t = theme;
    final picked = await showModalBottomSheet<HaptAlbum>(
      context: context,
      backgroundColor: t.colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(t.radii.sheet),
        ),
      ),
      builder: (_) {
        return SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag handle — visual affordance for the modal sheet
              // pattern. Matches the sheet handles in the rest of
              // most apps' UX.
              Padding(
                padding: EdgeInsets.symmetric(vertical: t.spacing.sm),
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: t.colors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  padding: EdgeInsets.symmetric(vertical: t.spacing.xs),
                  itemCount: controller.albums.length,
                  separatorBuilder: (_, __) =>
                      SizedBox(height: t.spacing.xxs),
                  itemBuilder: (_, i) {
                    final a = controller.albums[i];
                    return _AlbumRow(
                      theme: t,
                      album: a,
                      selected: controller.currentAlbum == a,
                      onTap: () => Navigator.of(context).pop(a),
                    );
                  },
                ),
              ),
              SizedBox(height: t.spacing.xs),
            ],
          ),
        );
      },
    );
    if (picked != null) {
      controller.switchAlbum(picked);
      final assets = await picked.loadAssets();
      controller.assets = assets;
    }
  }
}

/// Single album row — thumbnail + name + count + selected check.
/// The thumbnail is the album's first asset, lazy-loaded.
class _AlbumRow extends StatelessWidget {
  const _AlbumRow({
    required this.theme,
    required this.album,
    required this.selected,
    required this.onTap,
  });

  final HaptPickerTheme theme;
  final HaptAlbum album;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = theme;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(
            horizontal: t.spacing.md, vertical: t.spacing.xs),
        child: Row(
          children: [
            // Thumbnail — 56×56 rounded square showing the album's
            // first asset. Matches iOS Photos / Instagram album list.
            _AlbumCover(theme: t, album: album),
            SizedBox(width: t.spacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    album.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: t.typography.title.copyWith(
                        color: t.colors.textPrimary, fontSize: 15),
                  ),
                  SizedBox(height: t.spacing.xxs / 2),
                  Text(
                    _formatCount(album.assetCount),
                    style: t.typography.label
                        .copyWith(color: t.colors.textSecondary),
                  ),
                ],
              ),
            ),
            if (selected)
              Icon(Icons.check_rounded,
                  color: t.colors.primary, size: 22),
          ],
        ),
      ),
    );
  }

  /// Formats large counts with thousands separators — `5134` → `5,134`,
  /// `1351` → `1,351`. Pure string math, no `intl` dep needed.
  static String _formatCount(int n) {
    final s = n.toString();
    if (s.length <= 3) return s;
    final buf = StringBuffer();
    var read = 0;
    for (var i = s.length - 1; i >= 0; i--) {
      buf.write(s[i]);
      read++;
      if (read % 3 == 0 && i != 0) buf.write(',');
    }
    return buf.toString().split('').reversed.join();
  }
}

/// Lazy-loaded cover thumbnail. Fetches the first asset of the
/// album, renders a placeholder while loading or when empty.
class _AlbumCover extends StatefulWidget {
  const _AlbumCover({required this.theme, required this.album});
  final HaptPickerTheme theme;
  final HaptAlbum album;

  @override
  State<_AlbumCover> createState() => _AlbumCoverState();
}

class _AlbumCoverState extends State<_AlbumCover> {
  Future<Uint8List?>? _coverFuture;

  @override
  void initState() {
    super.initState();
    _coverFuture = _resolveCover();
  }

  Future<Uint8List?> _resolveCover() async {
    final assets = await widget.album.loadAssets(pageSize: 1);
    if (assets.isEmpty) return null;
    return assets.first.readThumbnail(width: 200, height: 200);
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.theme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: FutureBuilder<Uint8List?>(
        future: _coverFuture,
        builder: (_, snap) {
          final bytes = snap.data;
          if (bytes == null) {
            return Container(
              width: 56,
              height: 56,
              color: t.colors.thumbnailPlaceholder,
              alignment: Alignment.center,
              child: Icon(Icons.photo_library_outlined,
                  color: t.colors.textSecondary, size: 20),
            );
          }
          return Image.memory(
            bytes,
            width: 56,
            height: 56,
            fit: BoxFit.cover,
            gaplessPlayback: true,
          );
        },
      ),
    );
  }
}

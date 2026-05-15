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
          child: ListView.builder(
            shrinkWrap: true,
            padding: EdgeInsets.symmetric(vertical: t.spacing.sm),
            itemCount: controller.albums.length,
            itemBuilder: (_, i) {
              final a = controller.albums[i];
              final selected = controller.currentAlbum == a;
              return ListTile(
                title: Text(a.name,
                    style: t.typography.title
                        .copyWith(color: t.colors.textPrimary)),
                subtitle: Text('${a.assetCount}',
                    style: t.typography.label
                        .copyWith(color: t.colors.textSecondary)),
                trailing: selected
                    ? Icon(Icons.check_rounded,
                        color: t.colors.primary)
                    : null,
                onTap: () => Navigator.of(context).pop(a),
              );
            },
          ),
        );
      },
    );
    if (picked != null) {
      controller.switchAlbum(picked);
      // Lazy-load this album's assets — the picker controller's
      // assets list reset to empty during switchAlbum.
      final assets = await picked.loadAssets();
      controller.assets = assets;
    }
  }
}

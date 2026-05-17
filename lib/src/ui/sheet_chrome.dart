import 'package:flutter/material.dart';

import '../config/picker_strings.dart';
import '../config/picker_theme.dart';
import '../controller/picker_controller.dart';
import 'album_dropdown.dart';

/// Top bar of the picker — Cancel (left), album switcher (center),
/// Done (right). Done's label + enabled state read live off the
/// controller's selection.
class PickerChrome extends StatelessWidget {
  const PickerChrome({
    super.key,
    required this.theme,
    required this.strings,
    required this.controller,
    required this.onCancel,
    required this.onDone,
  });

  final HaptPickerTheme theme;
  final HaptPickerStrings strings;
  final HaptPickerController controller;
  final VoidCallback onCancel;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final t = theme;
    final canFinish = controller.canFinish;
    final count = controller.selection.length;
    final isMulti = controller.config.maxSelection > 1;

    // Done button label: in single-pick mode the count adds nothing
    // — the user is picking one item, of course the count is 1.
    // Reserving the digit shows "Done (1)" which feels noisy. Only
    // multi-pick mode surfaces the count.
    final doneLabel = !isMulti || count == 0
        ? strings.doneLabelEmpty
        : strings.doneLabelWithCount(count);

    // Fixed-width side slots (Cancel, Done) so the center
    // AlbumDropdown stays put as the count changes. Without this,
    // every selection tap reflows the entire chrome row. 92 px
    // covers "Done (4)" in every locale at the chosen button font.
    const sideSlot = 92.0;
    // Header sits on `surfaceElevated` (one step lighter in dark
    // mode, one step warmer in light) so it visually separates from
    // the asset grid below. A 1px hairline at the bottom adds the
    // final affordance — without it the elevated colour alone reads
    // as a flat tint on most LCD screens. Both surfaces share the
    // same `surface` token at the theme root (instagram-grade
    // pickers historically merged them); the elevated token is
    // applied locally to the chrome only.
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
          // Left slot — Cancel
          SizedBox(
            width: sideSlot,
            child: Align(
              alignment: Alignment.centerLeft,
              child: _ChromeTextButton(
                theme: t,
                label: strings.cancelLabel,
                onTap: onCancel,
              ),
            ),
          ),
          // Center — album dropdown gets the rest of the row, with
          // overflow ellipsis on long album names.
          Expanded(
            child: Center(
              child: AlbumDropdown(
                theme: t,
                strings: strings,
                controller: controller,
              ),
            ),
          ),
          // Right slot — Done
          SizedBox(
            width: sideSlot,
            child: Align(
              alignment: Alignment.centerRight,
              child: _DoneButton(
                theme: t,
                label: doneLabel,
                enabled: canFinish && count > 0,
                onTap: onDone,
              ),
            ),
          ),
        ],
      ),
    );
  }
}


/// Small chrome-side text button (Cancel). Pulled out so we can use
/// the `button` typography slot (15px) instead of the `label` slot
/// (12px) — the previous version felt cramped + ungrokkable next to
/// the album dropdown title.
class _ChromeTextButton extends StatelessWidget {
  const _ChromeTextButton({
    required this.theme,
    required this.label,
    required this.onTap,
  });

  final HaptPickerTheme theme;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = theme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(t.radii.button),
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(
              horizontal: t.spacing.xs, vertical: t.spacing.xs),
          child: Text(
            label,
            style: t.typography.button.copyWith(
              color: t.colors.textPrimary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}

class _DoneButton extends StatelessWidget {
  const _DoneButton({
    required this.theme,
    required this.label,
    required this.enabled,
    required this.onTap,
  });

  final HaptPickerTheme theme;
  final String label;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = theme;
    // Two distinct visual states (not a washed-out opacity).
    //   - enabled: solid primary fill + onPrimary label + shadow
    //   - disabled: transparent fill + primary outline + primary
    //               label at 40% — reads as "tap a thumbnail
    //               first", not "the button is broken"
    final disabledTint = t.colors.primary.withValues(alpha: 0.4);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        color: enabled ? t.colors.primary : Colors.transparent,
        borderRadius: BorderRadius.circular(t.radii.button),
        border: enabled
            ? null
            : Border.all(color: disabledTint, width: 1.2),
        boxShadow: enabled ? t.shadows.button : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(t.radii.button),
          onTap: enabled ? onTap : null,
          child: Padding(
            padding: EdgeInsets.symmetric(
                horizontal: t.spacing.md, vertical: t.spacing.xs),
            child: Text(
              label,
              style: t.typography.button.copyWith(
                color: enabled ? t.colors.onPrimary : disabledTint,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

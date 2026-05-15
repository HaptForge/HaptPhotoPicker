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
    return Padding(
      padding: EdgeInsets.fromLTRB(
        t.spacing.md, t.spacing.sm, t.spacing.md, t.spacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Cancel
          TextButton(
            onPressed: onCancel,
            style: TextButton.styleFrom(
              foregroundColor: t.colors.textSecondary,
              padding: EdgeInsets.symmetric(
                horizontal: t.spacing.xs, vertical: t.spacing.xxs),
            ),
            child: Text(strings.cancelLabel, style: t.typography.label),
          ),
          const Spacer(),
          AlbumDropdown(
            theme: t,
            strings: strings,
            controller: controller,
          ),
          const Spacer(),
          // Done
          _DoneButton(
            theme: t,
            label: count == 0
                ? strings.doneLabelEmpty
                : strings.doneLabelWithCount(count),
            enabled: canFinish && count > 0,
            onTap: onDone,
          ),
        ],
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

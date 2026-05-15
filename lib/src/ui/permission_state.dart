import 'package:flutter/material.dart';

import '../config/picker_strings.dart';
import '../config/picker_theme.dart';

/// Shown when the underlying photo permission was denied or set to
/// "no access". Provides a soft hand-off to system Settings — we
/// can't grant from inside the app.
class PermissionDeniedView extends StatelessWidget {
  const PermissionDeniedView({
    super.key,
    required this.theme,
    required this.strings,
    required this.onOpenSettings,
    required this.onCancel,
  });

  final HaptPickerTheme theme;
  final HaptPickerStrings strings;
  final VoidCallback onOpenSettings;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final t = theme;
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          t.spacing.lg, t.spacing.xl, t.spacing.lg, t.spacing.lg,
        ),
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: onCancel,
                child: Text(strings.cancelLabel,
                    style: t.typography.label
                        .copyWith(color: t.colors.textSecondary)),
              ),
            ),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.image_not_supported_outlined,
                      size: 56, color: t.colors.textSecondary),
                  SizedBox(height: t.spacing.md),
                  Text(strings.permissionDeniedTitle,
                      textAlign: TextAlign.center,
                      style: t.typography.title
                          .copyWith(color: t.colors.textPrimary)),
                  SizedBox(height: t.spacing.xs),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: t.spacing.lg),
                    child: Text(strings.permissionDeniedBody,
                        textAlign: TextAlign.center,
                        style: t.typography.body
                            .copyWith(color: t.colors.textSecondary)),
                  ),
                ],
              ),
            ),
            GestureDetector(
              onTap: onOpenSettings,
              child: Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(vertical: t.spacing.sm),
                decoration: BoxDecoration(
                  color: t.colors.primary,
                  borderRadius: BorderRadius.circular(t.radii.button),
                  boxShadow: t.shadows.button,
                ),
                child: Center(
                  child: Text(
                    strings.permissionDeniedSettings,
                    style: t.typography.button
                        .copyWith(color: t.colors.onPrimary),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

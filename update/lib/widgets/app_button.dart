import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Single button widget used everywhere in the app, instead of raw
/// ElevatedButton/OutlinedButton/TextButton calls scattered across
/// screens. Two things this guarantees by construction:
///
/// 1. EVERY button sizes to its label/icon rather than stretching to fill
///    its parent — wrap in Center (the default) or Align if you need to
///    position it within a wider row.
/// 2. Every screen gets the same five semantic variants rather than each
///    screen inventing its own ad-hoc styleFrom() override. If a new
///    color/state is needed, add a variant here ONCE rather than as an
///    inline override on whatever screen needs it — that's what keeps
///    this consistent as the app grows.
///
/// USAGE:
///   AppButton(label: 'SIGN IN', onPressed: _submit)                     // primary
///   AppButton.secondary(label: 'CANCEL', onPressed: () {})              // outlined
///   AppButton.text(label: 'Forgot password?', onPressed: () {})         // inline link
///   AppButton.danger(label: 'SIGN OUT', onPressed: _signOut)            // destructive
///   AppButton.success(label: 'UPHOLD', onPressed: _uphold)              // affirmative
///   AppButton(label: 'SAVE', onPressed: _save, isLoading: _isSaving)    // loading spinner
///   AppButton(label: 'EXPORT', icon: Icons.download, onPressed: _export)
///
/// For a button that should visually anchor a screen (a single primary
/// call-to-action at the bottom of a form), wrap it in Center — that's
/// the default — and let it size to its label. Resist the urge to force
/// width: double.infinity on it; that's the exact pattern this widget
/// exists to replace.
enum AppButtonVariant { primary, secondary, text, danger, success }

class AppButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isLoading;
  final AppButtonVariant variant;
  final bool compact; // smaller padding, for inline/dialog/tab contexts

  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.isLoading = false,
    this.variant = AppButtonVariant.primary,
    this.compact = false,
  });

  const AppButton.secondary({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.isLoading = false,
    this.compact = false,
  }) : variant = AppButtonVariant.secondary;

  const AppButton.text({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.isLoading = false,
    this.compact = false,
  }) : variant = AppButtonVariant.text;

  const AppButton.danger({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.isLoading = false,
    this.compact = false,
  }) : variant = AppButtonVariant.danger;

  const AppButton.success({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.isLoading = false,
    this.compact = false,
  }) : variant = AppButtonVariant.success;

  @override
  Widget build(BuildContext context) {
    final isDisabled = onPressed == null || isLoading;
    final child = _buildChild();
    final showIcon = icon != null && !isLoading;

    switch (variant) {
      case AppButtonVariant.primary:
        final style = compact
            ? ElevatedButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                minimumSize: const Size(0, 38),
              )
            : null;
        return showIcon
            ? ElevatedButton.icon(
                onPressed: isDisabled ? null : onPressed,
                icon: Icon(icon, size: compact ? 15 : 18),
                label: child,
                style: style,
              )
            : ElevatedButton(
                onPressed: isDisabled ? null : onPressed,
                style: style,
                child: child,
              );

      case AppButtonVariant.secondary:
        final style = compact
            ? OutlinedButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                minimumSize: const Size(0, 34),
              )
            : null;
        return showIcon
            ? OutlinedButton.icon(
                onPressed: isDisabled ? null : onPressed,
                icon: Icon(icon,
                    size: compact ? 15 : 18,
                    color: isDisabled ? AppTheme.textMuted : null),
                label: child,
                style: style,
              )
            : OutlinedButton(
                onPressed: isDisabled ? null : onPressed,
                style: style,
                child: child,
              );

      case AppButtonVariant.text:
        return showIcon
            ? TextButton.icon(
                onPressed: isDisabled ? null : onPressed,
                icon: Icon(icon,
                    size: compact ? 15 : 18,
                    color: isDisabled ? AppTheme.textMuted : null),
                label: child,
              )
            : TextButton(
                onPressed: isDisabled ? null : onPressed,
                child: child,
              );

      case AppButtonVariant.danger:
        final style = OutlinedButton.styleFrom(
          foregroundColor: AppTheme.dangerRed,
          side: BorderSide(
            color: isDisabled
                ? AppTheme.textMuted.withOpacity(0.4)
                : AppTheme.dangerRed,
            width: 1.5,
          ),
          padding: compact
              ? const EdgeInsets.symmetric(horizontal: 16, vertical: 8)
              : const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          minimumSize: compact ? const Size(0, 34) : const Size(0, 50),
        ).copyWith(
          overlayColor:
              WidgetStateProperty.all(AppTheme.dangerRed.withOpacity(0.08)),
        );
        return showIcon
            ? OutlinedButton.icon(
                onPressed: isDisabled ? null : onPressed,
                icon: Icon(icon,
                    size: compact ? 15 : 18,
                    color: isDisabled ? AppTheme.textMuted : AppTheme.dangerRed),
                label: child,
                style: style,
              )
            : OutlinedButton(
                onPressed: isDisabled ? null : onPressed,
                style: style,
                child: child,
              );

      case AppButtonVariant.success:
        final style = ElevatedButton.styleFrom(
          backgroundColor: AppTheme.successGreen,
          foregroundColor: AppTheme.navyDark,
          disabledBackgroundColor: AppTheme.successGreen.withOpacity(0.35),
          padding: compact
              ? const EdgeInsets.symmetric(horizontal: 18, vertical: 10)
              : const EdgeInsets.symmetric(horizontal: 28, vertical: 15),
          minimumSize: compact ? const Size(0, 38) : const Size(0, 50),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        );
        return showIcon
            ? ElevatedButton.icon(
                onPressed: isDisabled ? null : onPressed,
                icon: Icon(icon, size: compact ? 15 : 18),
                label: child,
                style: style,
              )
            : ElevatedButton(
                onPressed: isDisabled ? null : onPressed,
                style: style,
                child: child,
              );
    }
  }

  Widget _buildChild() {
    if (isLoading) {
      final spinnerColor = switch (variant) {
        AppButtonVariant.primary || AppButtonVariant.success => AppTheme.navyDark,
        AppButtonVariant.secondary || AppButtonVariant.text => AppTheme.goldAccent,
        AppButtonVariant.danger => AppTheme.dangerRed,
      };
      return SizedBox(
        height: 16,
        width: 16,
        child: CircularProgressIndicator(strokeWidth: 2, color: spinnerColor),
      );
    }
    return Text(label);
  }
}

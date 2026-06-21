import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// A step up from a bare CircularProgressIndicator without needing a
/// full skeleton layout — fades in (so it doesn't flash for a
/// near-instant load) and pairs the spinner with a short caption. Use
/// this where a screen's loaded content is too irregular to mock with
/// AppSkeletonBox/AppSkeletonList (e.g. a tab with several differently
/// shaped chart cards) but still deserves more than a plain spinner.
class AppLoadingIndicator extends StatelessWidget {
  final String? caption;

  const AppLoadingIndicator({super.key, this.caption});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.0, end: 1.0),
        duration: const Duration(milliseconds: 300),
        builder: (context, opacity, child) {
          return Opacity(opacity: opacity, child: child);
        },
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: AppTheme.goldAccent,
              ),
            ),
            if (caption != null) ...[
              const SizedBox(height: 14),
              Text(
                caption!,
                style: const TextStyle(
                  color: AppTheme.textMuted,
                  fontSize: 12,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

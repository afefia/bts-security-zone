import 'dart:async';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'app_motion.dart';

/// A brief overlay confirming an action completed — a checkmark that
/// scales/fades in, holds for a moment, then fades out on its own. Use
/// this for moments that deserve more than a SnackBar but shouldn't
/// interrupt the person for long: a recruit was registered, a dispute
/// was filed, a company was approved.
///
/// WHY NOT JUST A SNACKBAR: a SnackBar is correct for routine
/// confirmations and is still used throughout this app for that. This
/// overlay is for the handful of moments where the action is the whole
/// point of the screen the person was just on, and a half-second of
/// visual confirmation makes the "it worked" moment feel real rather
/// than just logged in a toast at the bottom of the screen.
///
/// Deliberately restrained — a checkmark settling into a circle and
/// fading out, no bounce, no confetti, no sound. That reads as
/// professional confirmation, appropriate for a compliance tool, not
/// celebration.
///
/// USAGE:
///   await AppSuccessOverlay.show(context, message: 'Recruit registered');
///   if (context.mounted) Navigator.pop(context);
class AppSuccessOverlay {
  /// Inserts the overlay, waits for its animation to finish (~1.1s total:
  /// fade in, hold, fade out), then removes it and completes. Await this
  /// before navigating away so the person actually sees the confirmation.
  static Future<void> show(
    BuildContext context, {
    required String message,
  }) {
    final overlay = Overlay.of(context);
    final completer = Completer<void>();

    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => _SuccessOverlayContent(message: message),
    );

    overlay.insert(entry);

    // Total visible duration: fade in (~250ms) + hold (~600ms) + fade out
    // (~250ms). Matches the animation timing inside _SuccessOverlayContent.
    Future.delayed(const Duration(milliseconds: 1100), () {
      entry.remove();
      if (!completer.isCompleted) completer.complete();
    });

    return completer.future;
  }
}

class _SuccessOverlayContent extends StatefulWidget {
  final String message;

  const _SuccessOverlayContent({required this.message});

  @override
  State<_SuccessOverlayContent> createState() => _SuccessOverlayContentState();
}

class _SuccessOverlayContentState extends State<_SuccessOverlayContent>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scale;
  late Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );

    // Scale: starts slightly small, settles to full size with a touch of
    // overshoot via AppMotion.confirm, then holds.
    _scale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 0.6, end: 1.0).chain(CurveTween(curve: AppMotion.confirm)),
        weight: 25,
      ),
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 75),
    ]).animate(_controller);

    // Opacity: fade in over the first ~20%, hold, fade out over the last ~20%.
    _opacity = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 20),
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 60),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 20),
    ]).animate(_controller);

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Positioned.fill(
          child: IgnorePointer(
            child: Opacity(
              opacity: _opacity.value,
              child: Container(
                color: AppTheme.navyDark.withOpacity(0.55),
                child: Center(
                  child: Transform.scale(
                    scale: _scale.value,
                    child: Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
                      decoration: BoxDecoration(
                        color: AppTheme.cardBg,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                            color: AppTheme.successGreen.withOpacity(0.5)),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 52,
                            height: 52,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppTheme.successGreen,
                            ),
                            child: const Icon(Icons.check,
                                color: AppTheme.navyDark, size: 30),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            widget.message,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: AppTheme.offWhite,
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

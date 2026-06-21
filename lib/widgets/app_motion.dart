import 'package:flutter/animation.dart';

/// Single source of truth for animation timing/easing — the same reason
/// AppButton and AppMaxWidth exist. Without this, every screen that adds
/// a fade or a transition picks its own duration, and the app ends up
/// feeling inconsistent even if each individual animation looks fine in
/// isolation. Reference these constants rather than writing a fresh
/// Duration(milliseconds: ...) on a new screen.
///
/// The feel here is deliberately restrained — fades and gentle slides,
/// nothing bouncy or playful. This app's job is telling someone whether
/// a person has a termination record on file; it should read like a
/// banking or compliance tool, not a consumer app. Overshoot/elastic
/// curves and anything longer than ~400ms reads as decoration rather
/// than feedback, so none of the curves below use them.
class AppMotion {
  AppMotion._();

  /// Quick state changes — a button's press feedback, a small icon swap.
  static const Duration fast = Duration(milliseconds: 150);

  /// The default for most transitions — screen content fading/sliding in,
  /// a card appearing, a banner showing or hiding.
  static const Duration standard = Duration(milliseconds: 280);

  /// Slightly longer, for full-screen transitions (splash → login,
  /// page-to-page navigation) where standard would feel rushed.
  static const Duration screen = Duration(milliseconds: 350);

  /// Loading skeletons' shimmer sweep — slow and continuous, not meant to
  /// draw attention, just signal "still working" without nagging.
  static const Duration shimmer = Duration(milliseconds: 1400);

  /// Standard easing for anything entering the screen.
  static const Curve enter = Curves.easeOutCubic;

  /// Standard easing for anything leaving.
  static const Curve exit = Curves.easeInCubic;

  /// For success/confirmation moments — a touch of settle without bounce.
  static const Curve confirm = Curves.easeOutBack;
}

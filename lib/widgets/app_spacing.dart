import 'package:flutter/widgets.dart';

/// Single source of truth for screen-edge padding. Every screen's root
/// padding/margin should reference this rather than inventing its own
/// EdgeInsets.all(N) — keeps every screen's left/right breathing room
/// visually identical, which is most of what makes a layout feel
/// "designed" rather than ad-hoc.
class AppSpacing {
  AppSpacing._();

  /// Standard horizontal/vertical padding around a screen's content.
  static const EdgeInsets screen = EdgeInsets.all(16);

  /// For screens with a lot of vertical content (forms, long lists) where
  /// a touch more top breathing room reads better under an AppBar.
  static const EdgeInsets screenWithExtraTop =
      EdgeInsets.fromLTRB(16, 20, 16, 16);

  /// Gap between stacked form fields.
  static const double fieldGap = 16;

  /// Gap between a field group/section and the next.
  static const double sectionGap = 24;
}

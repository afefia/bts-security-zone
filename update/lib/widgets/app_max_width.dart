import 'package:flutter/widgets.dart';

/// Wrap any form's content in this. On a phone-width screen it's
/// invisible — content already fits within the cap. On a wide window
/// (desktop browser, tablet landscape, desktop app build) it caps the
/// form at a sane reading/input width and centers it, which is what
/// every professional desktop form does (Stripe, Linear, every bank
/// login) instead of letting text fields and cards stretch edge to edge
/// just because the window happens to be wide.
///
/// THIS IS THE FIX for "looks fine on phone, looks stretched on desktop
/// browser" — AppButton solved the button half of that problem; this
/// solves the text-field/card half. Wrap the outermost Column/Form of
/// any screen with real input fields in this, the same way every screen
/// already uses AppButton for its buttons.
///
/// USAGE:
///   SingleChildScrollView(
///     child: AppMaxWidth(
///       child: Form(child: Column(children: [...])),
///     ),
///   )
class AppMaxWidth extends StatelessWidget {
  final Widget child;

  /// 440 fits a typical login/registration form (label + field + a
  /// couple inline buttons) without feeling cramped or absurdly wide.
  /// Wider forms (the 3-step company registration with side-by-side
  /// fields) can pass a larger value.
  final double maxWidth;

  const AppMaxWidth({super.key, required this.child, this.maxWidth = 440});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}

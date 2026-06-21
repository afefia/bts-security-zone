import 'package:flutter/material.dart';
import 'app_motion.dart';

/// Wraps a screen's body so it fades and gently slides up on first
/// appearance, instead of popping in instantly. Subtle on purpose — this
/// should feel like the content settling into place, not an effect
/// someone consciously notices.
///
/// USAGE: wrap the top-level child of Scaffold.body (after any
/// AppMaxWidth wrap) in AppScreenEntry. Don't wrap individual list items
/// in this — for staggered list entry use AppListItemEntry instead.
class AppScreenEntry extends StatefulWidget {
  final Widget child;

  const AppScreenEntry({super.key, required this.child});

  @override
  State<AppScreenEntry> createState() => _AppScreenEntryState();
}

class _AppScreenEntryState extends State<AppScreenEntry>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fade;
  late Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: AppMotion.screen);
    _fade = CurvedAnimation(parent: _controller, curve: AppMotion.enter);
    _slide = Tween<Offset>(begin: const Offset(0, 0.03), end: Offset.zero)
        .animate(CurvedAnimation(parent: _controller, curve: AppMotion.enter));
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(position: _slide, child: widget.child),
    );
  }
}

/// Staggered entry for items in a freshly-loaded list (search results,
/// recruit lists, audit entries) — each item fades/slides in slightly
/// after the one before it, so a list of 8 results doesn't all snap into
/// place simultaneously. Wrap each item's builder output in this, passing
/// its index.
class AppListItemEntry extends StatefulWidget {
  final Widget child;
  final int index;

  const AppListItemEntry({super.key, required this.child, required this.index});

  @override
  State<AppListItemEntry> createState() => _AppListItemEntryState();
}

class _AppListItemEntryState extends State<AppListItemEntry>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fade;
  late Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: AppMotion.standard);
    _fade = CurvedAnimation(parent: _controller, curve: AppMotion.enter);
    _slide = Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero)
        .animate(CurvedAnimation(parent: _controller, curve: AppMotion.enter));

    // Cap the stagger so a long list doesn't make the bottom items wait
    // visibly — beyond the 8th item, everything animates together.
    final delayMs = (widget.index.clamp(0, 8)) * 35;
    Future.delayed(Duration(milliseconds: delayMs), () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(position: _slide, child: widget.child),
    );
  }
}

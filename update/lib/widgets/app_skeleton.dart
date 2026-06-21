import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'app_motion.dart';

/// A single shimmering placeholder block — the base unit skeleton screens
/// are built from. Use this directly for one-off placeholders, or use
/// the pre-built layouts below (AppSkeletonList, AppSkeletonCard) for the
/// common cases so every loading screen in the app shimmers the same way.
///
/// WHY THIS INSTEAD OF A SPINNER: a centered spinner tells the person
/// "something is happening" but nothing about what's about to appear, so
/// the layout still jumps the moment data arrives. A skeleton in the
/// shape of the real content arrives "pre-loaded" visually — the jump
/// disappears, and it reads as faster even when the actual fetch time is
/// identical. This is standard practice in banking/professional apps
/// (it's exactly what shows while your bank loads transaction history).
class AppSkeletonBox extends StatefulWidget {
  final double width;
  final double height;
  final double borderRadius;

  const AppSkeletonBox({
    super.key,
    this.width = double.infinity,
    required this.height,
    this.borderRadius = 8,
  });

  @override
  State<AppSkeletonBox> createState() => _AppSkeletonBoxState();
}

class _AppSkeletonBoxState extends State<AppSkeletonBox>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: AppMotion.shimmer)
      ..repeat();
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
      builder: (context, child) {
        // Sweeps a lighter band left-to-right across the base color —
        // subtle on purpose, this should read as "loading" at a glance,
        // not draw the eye.
        final t = _controller.value;
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            gradient: LinearGradient(
              begin: Alignment(-1 + 2 * t - 0.6, 0),
              end: Alignment(-1 + 2 * t + 0.6, 0),
              colors: const [
                AppTheme.steelBlue,
                Color(0xFF2A4A75), // a touch lighter than steelBlue
                AppTheme.steelBlue,
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Pre-built skeleton for a card-style item (the shape used throughout
/// this app for recruits, companies, alerts, audit entries — an avatar
/// circle, a couple of text lines, a status pill). Drop one of these in
/// per expected item while real data loads.
class AppSkeletonCard extends StatelessWidget {
  const AppSkeletonCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.steelBlue.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const AppSkeletonBox(width: 52, height: 52, borderRadius: 26),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                AppSkeletonBox(width: 140, height: 14),
                SizedBox(height: 8),
                AppSkeletonBox(width: 90, height: 11),
              ],
            ),
          ),
          const SizedBox(width: 12),
          const AppSkeletonBox(width: 64, height: 22, borderRadius: 11),
        ],
      ),
    );
  }
}

/// A scrollable column of [count] skeleton cards — drop this in wherever
/// a screen currently shows `Center(child: CircularProgressIndicator())`
/// while fetching a list (recruits, companies, alerts, audit log).
class AppSkeletonList extends StatelessWidget {
  final int count;
  final EdgeInsets padding;

  const AppSkeletonList({
    super.key,
    this.count = 5,
    this.padding = const EdgeInsets.all(16),
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: padding,
      itemCount: count,
      itemBuilder: (_, __) => const AppSkeletonCard(),
    );
  }
}

/// Skeleton for a single stat/summary card (used on the dashboard and
/// admin overview — a small icon, a big number, a label).
class AppSkeletonStat extends StatelessWidget {
  const AppSkeletonStat({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.steelBlue.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          AppSkeletonBox(width: 28, height: 28, borderRadius: 14),
          SizedBox(height: 14),
          AppSkeletonBox(width: 50, height: 20),
          SizedBox(height: 6),
          AppSkeletonBox(width: 70, height: 11),
        ],
      ),
    );
  }
}

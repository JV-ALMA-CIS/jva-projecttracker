import 'package:flutter/material.dart';

/// Wraps [child] with a one-shot fade + upward slide entrance, staggered by
/// [index] so a list of freshly-fetched items animates in progressively
/// instead of popping onto the screen all at once.
class FadeSlideIn extends StatefulWidget {
  const FadeSlideIn({super.key, required this.child, required this.index});

  final Widget child;
  final int index;

  @override
  State<FadeSlideIn> createState() => _FadeSlideInState();
}

class _FadeSlideInState extends State<FadeSlideIn> {
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    final delay = Duration(milliseconds: 30 * widget.index.clamp(0, 12));
    Future.delayed(delay, () {
      if (mounted) setState(() => _visible = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: _visible ? 1 : 0,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
      child: AnimatedSlide(
        offset: _visible ? Offset.zero : const Offset(0, 0.08),
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

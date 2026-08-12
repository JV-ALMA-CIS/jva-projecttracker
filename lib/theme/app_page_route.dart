import 'package:flutter/material.dart';

/// A considered slide-in-from-the-right + fade transition, used in place of
/// the platform-default [MaterialPageRoute] transition for in-app
/// navigation (list → form, screen → Settings).
class SlideFadePageRoute<T> extends PageRouteBuilder<T> {
  SlideFadePageRoute({required WidgetBuilder builder})
    : super(
        pageBuilder: (context, animation, secondaryAnimation) =>
            builder(context),
        transitionDuration: const Duration(milliseconds: 220),
        reverseTransitionDuration: const Duration(milliseconds: 180),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final curved = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
            reverseCurve: Curves.easeInCubic,
          );
          return FadeTransition(
            opacity: curved,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0.05, 0),
                end: Offset.zero,
              ).animate(curved),
              child: child,
            ),
          );
        },
      );
}

/// Pushes [page] using [SlideFadePageRoute] — same destination, a more
/// considered transition than the platform default.
Future<T?> pushSlideFade<T>(BuildContext context, Widget page) {
  return Navigator.of(
    context,
  ).push<T>(SlideFadePageRoute(builder: (_) => page));
}

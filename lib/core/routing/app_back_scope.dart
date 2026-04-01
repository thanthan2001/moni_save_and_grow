import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Centralized back behavior:
/// - Pop when there is a previous route.
/// - Otherwise fallback to dashboard instead of closing the app.
class AppBackScope extends StatelessWidget {
  final Widget child;
  final String fallbackRoute;

  const AppBackScope({
    super.key,
    required this.child,
    this.fallbackRoute = '/dashboard',
  });

  static void handleBack(
    BuildContext context, {
    String fallbackRoute = '/dashboard',
  }) {
    if (context.canPop()) {
      context.pop();
      return;
    }
    context.go(fallbackRoute);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          handleBack(context, fallbackRoute: fallbackRoute);
        }
      },
      child: child,
    );
  }
}

// lib/features/splash/presentation/widgets/splash_title.dart
import 'package:flutter/material.dart';
import '../../../../global/widgets/widgets.dart';

class SplashTitle extends StatelessWidget {
  const SplashTitle({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // App name
        AppText(
          'MONI',
          style: TextStyle(
            fontSize: 48,
            fontWeight: FontWeight.bold,
            letterSpacing: 2,
            color: const Color(0xFF9598B0),
            shadows: [
              Shadow(
                // ignore: deprecated_member_use
                color: Colors.black.withOpacity(0.1),
                offset: const Offset(0, 2),
                blurRadius: 4,
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        // Slogan
        AppText(
          'Save & Grow',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            letterSpacing: 3,
            color: Colors.white.withOpacity(0.9),
          ),
        ),
      ],
    );
  }
}

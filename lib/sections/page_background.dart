import 'package:flutter/material.dart';

class PageBackground extends StatelessWidget {
  const PageBackground({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) {
    return Container(
      // Updated to remove green/teal tint and use a cleaner deep blue gradient.
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF2563EB), // Blue 600
            Color(0xFF1E3A8A), // Indigo 800
          ],
        ),
      ),
      child: child,
    );
  }
}

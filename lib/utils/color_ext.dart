import 'package:flutter/material.dart';

// Minimal compatibility extension to preserve the project's existing
// `withValues(alpha: ...)` callsites. Implemented without calling
// deprecated APIs by constructing a new Color with adjusted alpha.
extension ColorWithValues on Color {
  /// Returns a copy of this color with the provided alpha (0.0 - 1.0).
  Color withValues({double? alpha}) {
    if (alpha == null) return this;
    // Compose new ARGB without using deprecated members
  final a = (alpha.clamp(0.0, 1.0) * 255.0).round() & 0xFF;
    final r = (this.r * 255.0).round() & 0xFF;
    final g = (this.g * 255.0).round() & 0xFF;
    final b = (this.b * 255.0).round() & 0xFF;
    return Color.fromARGB(a, r, g, b);
  }
}

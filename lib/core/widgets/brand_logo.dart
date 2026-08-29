import 'package:flutter/material.dart';

class BrandLogo extends StatelessWidget {
  final double height;
  final bool light;
  final bool compact;

  const BrandLogo({
    super.key,
    this.height = 54,
    this.light = false,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Tulasi Solutions',
      image: true,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(height * 0.16),
        child: Image.asset(
          'assets/logo.png',
          width: height,
          height: height,
          fit: BoxFit.cover,
          filterQuality: FilterQuality.high,
        ),
      ),
    );
  }
}

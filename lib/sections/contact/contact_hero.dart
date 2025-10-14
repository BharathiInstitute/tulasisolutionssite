import 'package:flutter/material.dart';
// Note: assets removed; using a gradient placeholder instead of SVG.

/// Contact hero illustration: "Contact — Let's Talk Growth"
/// Renders the vector with a pleasant vertical gradient background and plenty of left negative space for text.
class ContactHero extends StatelessWidget {
  const ContactHero({super.key, this.onTalkTap});
  final VoidCallback? onTalkTap;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        SizedBox(
          width: double.infinity,
          child: AspectRatio(
            aspectRatio: 1200 / 600,
            child: DecoratedBox(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFFE6F4FF), Color(0xFFE6FFFB)],
                ),
              ),
              child: const SizedBox.expand(),
            ),
          ),
        ),
        if (onTalkTap != null)
          Positioned(
            left: 16,
            bottom: 16,
            child: FilledButton(
              onPressed: onTalkTap,
              child: const Text("Let's talk"),
            ),
          ),
      ],
    );
  }
}

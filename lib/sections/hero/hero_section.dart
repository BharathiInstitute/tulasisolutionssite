import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_feather_icons/flutter_feather_icons.dart';
import 'package:google_fonts/google_fonts.dart';

class HeroSection extends StatelessWidget {
  const HeroSection({super.key, this.onPrimary, this.onSecondary});

  final VoidCallback? onPrimary;
  final VoidCallback? onSecondary;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final isMobile = size.width < 700;


    // Colors
    const bgStart = Color(0xFF3A7BD5); // blue
    const bgEnd = Color(0xFF3A6073); // purple
    const headlineColor = Color(0xFF443F3F);
    const subheadColor = Color(0xFFF78CA2);
  // gold color used in buttons; defined in button widgets

    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 420),
      padding: EdgeInsets.symmetric(
        vertical: isMobile ? 80 : 110,
        horizontal: 16,
      ),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [bgStart, bgEnd],
        ),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Positioned.fill(
                child: IgnorePointer(
                  ignoring: true,
                  child: _FloatingIconsLayer(isMobile: isMobile),
                ),
              ),
              LayoutBuilder(
                builder: (context, c) {
                  if (isMobile) {
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          'Tulasi Solutions — One partner for Branding, Marketing, Websites, Software & Automation.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.josefinSans(
                            color: headlineColor,
                            fontWeight: FontWeight.w700,
                            fontSize: 32,
                            height: 1.2,
                            letterSpacing: 0.2,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          'Launch fast, grow steadily, and scale with clarity.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.nunito(
                            color: subheadColor,
                            fontWeight: FontWeight.w600,
                            fontSize: 18,
                            height: 1.35,
                          ),
                        ),
                        const SizedBox(height: 24),
                        _CtasVertical(onPrimary: onPrimary, onSecondary: onSecondary),
                      ],
                    );
                  }
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        flex: 6,
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 820),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Tulasi Solutions — One partner for Branding, Marketing, Websites, Software & Automation.',
                                  style: GoogleFonts.josefinSans(
                                    color: headlineColor,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 46,
                                    height: 1.15,
                                    letterSpacing: 0.2,
                                  ),
                                ),
                                const SizedBox(height: 18),
                                Text(
                                  'Launch fast, grow steadily, and scale with clarity.',
                                  style: GoogleFonts.nunito(
                                    color: subheadColor,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 20,
                                    height: 1.35,
                                  ),
                                ),
                                const SizedBox(height: 28),
                                _CtasHorizontal(onPrimary: onPrimary, onSecondary: onSecondary),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 60),
                      const Expanded(flex: 5, child: _HeroImage()),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeroImage extends StatelessWidget {
  const _HeroImage();
  static const _assetPath = 'assets/home_page.png';
  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: AspectRatio(
        aspectRatio: 1.1,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              _assetPath,
              fit: BoxFit.cover,
              filterQuality: FilterQuality.medium,
              errorBuilder: (context, error, stack) => Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.white.withValues(alpha: .12),
                      Colors.white.withValues(alpha: .06),
                    ],
                  ),
                ),
                alignment: Alignment.center,
                child: Icon(Icons.broken_image, color: Colors.white.withValues(alpha: .7), size: 48),
              ),
            ),
            // Subtle overlay for contrast with text
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.20),
                    Colors.black.withValues(alpha: 0.05),
                    Colors.black.withValues(alpha: 0.24),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CtasHorizontal extends StatelessWidget {
  const _CtasHorizontal({required this.onPrimary, required this.onSecondary});
  final VoidCallback? onPrimary;
  final VoidCallback? onSecondary;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _PrimaryGoldButton(label: 'Book Free Demo', onPressed: onPrimary),
        const SizedBox(width: 12),
        _SecondaryGoldButton(label: 'Chat on WhatsApp', onPressed: onSecondary),
      ],
    );
  }
}

class _CtasVertical extends StatelessWidget {
  const _CtasVertical({required this.onPrimary, required this.onSecondary});
  final VoidCallback? onPrimary;
  final VoidCallback? onSecondary;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _PrimaryGoldButton(label: 'Book Free Demo', onPressed: onPrimary),
        const SizedBox(height: 10),
        _SecondaryGoldButton(label: 'Chat on WhatsApp', onPressed: onSecondary),
      ],
    );
  }
}

class _PrimaryGoldButton extends StatefulWidget {
  const _PrimaryGoldButton({required this.label, this.onPressed});
  final String label;
  final VoidCallback? onPressed;

  @override
  State<_PrimaryGoldButton> createState() => _PrimaryGoldButtonState();
}

class _PrimaryGoldButtonState extends State<_PrimaryGoldButton> {
  bool _hover = false;
  @override
  Widget build(BuildContext context) {
    const gold = Color(0xFFD4AF37);
    final darkerGold = HSLColor.fromColor(gold).withLightness(0.42).toColor();
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          color: _hover ? darkerGold : gold,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: gold.withValues(alpha: 0.35),
              blurRadius: 16,
              spreadRadius: 1,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
        child: Text(
          widget.label,
          style: GoogleFonts.poppins(
            color: Colors.black,
            fontWeight: FontWeight.w700,
            fontSize: 14,
            letterSpacing: 0.2,
          ),
        ),
      )._asButton(widget.onPressed),
    );
  }
}

class _SecondaryGoldButton extends StatelessWidget {
  const _SecondaryGoldButton({required this.label, this.onPressed});
  final String label;
  final VoidCallback? onPressed;
  @override
  Widget build(BuildContext context) {
    const gold = Color(0xFFD4AF37);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: gold, width: 2),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Text(
          label,
          style: GoogleFonts.poppins(
            color: gold,
            fontWeight: FontWeight.w700,
            fontSize: 14,
            letterSpacing: 0.2,
          ),
        ),
      )._asButton(onPressed),
    );
  }
}

extension on Widget {
  Widget _asButton(VoidCallback? onPressed) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(28),
      child: this,
    );
  }
}

class _FloatingIconsLayer extends StatelessWidget {
  const _FloatingIconsLayer({required this.isMobile});
  final bool isMobile;

  @override
  Widget build(BuildContext context) {
  final color = Colors.white.withValues(alpha: 0.28);
    final glow = [
  Shadow(color: Colors.white.withValues(alpha: 0.2), blurRadius: 8),
  Shadow(color: Colors.white.withValues(alpha: 0.08), blurRadius: 16),
    ];

    final icons = <_FloatingIconSpec>[
      _FloatingIconSpec(icon: FeatherIcons.penTool, dx: -0.72, dy: -0.10, size: isMobile ? 28 : 36), // Branding 🎨
      _FloatingIconSpec(icon: FeatherIcons.volume2, dx: 0.70, dy: -0.06, size: isMobile ? 26 : 34), // Marketing 📢
      _FloatingIconSpec(icon: FeatherIcons.globe, dx: -0.58, dy: 0.24, size: isMobile ? 28 : 36), // Websites 🌐
      _FloatingIconSpec(icon: FeatherIcons.settings, dx: 0.64, dy: 0.22, size: isMobile ? 28 : 36), // Software ⚙️
      _FloatingIconSpec(icon: FeatherIcons.cpu, dx: -0.16, dy: -0.26, size: isMobile ? 26 : 34), // Automation 🤖
      _FloatingIconSpec(icon: FeatherIcons.trendingUp, dx: 0.18, dy: 0.28, size: isMobile ? 28 : 36), // Growth 📈
    ];

    return LayoutBuilder(
      builder: (context, c) {
        final w = c.maxWidth;
        final h = c.maxHeight;
        return Stack(
          children: [
            for (final spec in icons)
              Positioned(
                left: (w / 2) + (spec.dx * (isMobile ? w * 0.40 : w * 0.44)) - spec.size / 2,
                top: (h / 2) + (spec.dy * (isMobile ? h * 0.40 : h * 0.42)) - spec.size / 2,
                child: _SoftIcon(icon: spec.icon, size: spec.size, color: color, glow: glow),
              ),
          ],
        );
      },
    );
  }
}

class _SoftIcon extends StatefulWidget {
  const _SoftIcon({required this.icon, required this.size, required this.color, required this.glow});
  final IconData icon;
  final double size;
  final Color color;
  final List<Shadow> glow;

  @override
  State<_SoftIcon> createState() => _SoftIconState();
}

class _SoftIconState extends State<_SoftIcon> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 6),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) {
        final t = Curves.easeInOut.transform(_c.value);
        final dy = (math.sin(t * math.pi * 2) * 4);
        final scale = 0.96 + (t * 0.08);
        return Transform.translate(
          offset: Offset(0, dy),
          child: Transform.scale(
            scale: scale,
            child: child,
          ),
        );
      },
      child: Icon(
        widget.icon,
        size: widget.size,
        color: widget.color,
        shadows: widget.glow,
      ),
    );
  }
}

class _FloatingIconSpec {
  const _FloatingIconSpec({required this.icon, required this.dx, required this.dy, required this.size});
  final IconData icon;
  final double dx; // -1..1 left/right positioning relative to center
  final double dy; // -1..1 up/down positioning relative to center
  final double size;
}

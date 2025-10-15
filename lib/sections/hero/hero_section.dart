import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class HeroSection extends StatelessWidget {
  const HeroSection({super.key, this.onPrimary, this.onSecondary});

  final VoidCallback? onPrimary;
  final VoidCallback? onSecondary;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final isMobile = size.width < 700;

    // Colors (light background variant)
    const bgLightA = Color(0xFFF4F8FB); // very light blue/gray
    const bgLightB = Color(0xFFE9F1F7); // soft blue tint
    const headlineColor = Color(0xFF0F2741); // dark navy for headlines
    const subheadColor = Color(0xFF4D6B88); // mid-slate blue for subhead

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
          colors: [bgLightA, bgLightB],
        ),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: LayoutBuilder(
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
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 880),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Tulasi Solutions — One partner for Branding, Marketing, Websites, Software & Automation.',
                              style: GoogleFonts.josefinSans(
                                color: headlineColor,
                                fontWeight: FontWeight.w700,
                                fontSize: 48,
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
                ],
              );
            },
          ),
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

import 'package:flutter/material.dart';
import 'package:flutter_feather_icons/flutter_feather_icons.dart';
import 'package:google_fonts/google_fonts.dart';

class WhatWeDoSection extends StatelessWidget {
  const WhatWeDoSection({super.key});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final isMobile = size.width < 720;

  final bg = Theme.of(context).scaffoldBackgroundColor;
    const titleColor = Color(0xFF443F3F);
    const subtitleColor = Color(0xFF7D5B4C);

    final steps = <_StepData>[
      _StepData('Branding', FeatherIcons.penTool),
      _StepData('Marketing', FeatherIcons.volume2),
      _StepData('Website', FeatherIcons.globe),
      _StepData('Software', FeatherIcons.settings),
      _StepData('Automation', FeatherIcons.cpu),
      _StepData('Training', FeatherIcons.bookOpen),
      _StepData('Growth', FeatherIcons.trendingUp),
    ];

    return Container(
  color: bg,
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: isMobile ? 56 : 80),
      child: isMobile
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _SectionHeadline(isMobile: true, titleColor: titleColor, subtitleColor: subtitleColor),
                    const SizedBox(height: 28),
                    _VerticalTimeline(steps: steps),
                  ],
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Left: Headline/subtitle (text)
                    Expanded(
                      flex: 1,
                      child: Padding(
                        // Move text further down
                        padding: const EdgeInsets.fromLTRB(93, 110, 24, 0),
                        child: const _SectionHeadline(isMobile: false, titleColor: titleColor, subtitleColor: subtitleColor),
                      ),
                    ),
                    // Right: Container with icons/cards
                    Expanded(
                      flex: 1,
                      child: Align(
                        alignment: Alignment.topCenter,
                        child: FractionallySizedBox(
                          widthFactor: 0.82, // narrower than the column width
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: Theme.of(context).cardColor,
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(color: Colors.black.withValues(alpha: .06)),
                              boxShadow: [
                                BoxShadow(color: Colors.black.withValues(alpha: .08), blurRadius: 12, offset: const Offset(0, 6)),
                              ],
                            ),
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(24, 22, 24, 24),
                              child: _HorizontalTimeline(steps: steps),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }
}

class _SectionHeadline extends StatelessWidget {
  const _SectionHeadline({required this.isMobile, required this.titleColor, required this.subtitleColor});
  final bool isMobile; final Color titleColor; final Color subtitleColor;
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'What We Do (End-to-End Stack)',
          textAlign: TextAlign.left,
          style: GoogleFonts.openSans(
            fontSize: isMobile ? 30 : 40,
            fontWeight: FontWeight.w700,
            color: titleColor,
            height: 1.15,
            letterSpacing: .3,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'Less vendor chaos, faster go-to-market.',
          textAlign: TextAlign.left,
          style: GoogleFonts.openSans(
            fontSize: isMobile ? 18 : 20,
            fontWeight: FontWeight.w600,
            color: subtitleColor,
            height: 1.35,
          ),
        ),
      ],
    );
  }
}

// Note: Removed the decorative image widget as requested.

class _HorizontalTimeline extends StatelessWidget {
  const _HorizontalTimeline({required this.steps});
  final List<_StepData> steps;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 14,
      runSpacing: 18,
      crossAxisAlignment: WrapCrossAlignment.center,
      alignment: WrapAlignment.center,
      children: [
        for (int i = 0; i < steps.length; i++)
          _StepCard(
            data: steps[i],
            showArrow: false,
            direction: Axis.horizontal,
          ),
      ],
    );
  }
}

class _VerticalTimeline extends StatelessWidget {
  const _VerticalTimeline({required this.steps});
  final List<_StepData> steps;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (int i = 0; i < steps.length; i++)
          _StepCard(
            data: steps[i],
            showArrow: false,
            direction: Axis.vertical,
          ),
      ],
    );
  }
}

class _StepCard extends StatefulWidget {
  const _StepCard({required this.data, required this.showArrow, required this.direction});
  final _StepData data;
  final bool showArrow;
  final Axis direction;

  @override
  State<_StepCard> createState() => _StepCardState();
}

class _StepCardState extends State<_StepCard> {
  bool _hover = false;
  @override
  Widget build(BuildContext context) {
    const gold = Color(0xFFD4AF37);
    final isHorizontal = widget.direction == Axis.horizontal;

    final card = AnimatedContainer(
      duration: const Duration(milliseconds: 140),
      curve: Curves.easeOut,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: _hover ? 0.08 : 0.05),
            blurRadius: _hover ? 14 : 10,
            offset: const Offset(0, 6),
          ),
        ],
        border: Border.all(color: gold.withValues(alpha: 0.2)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [gold.withValues(alpha: 0.25), Colors.transparent],
                radius: 0.8,
              ),
            ),
            child: Icon(
              widget.data.icon,
              size: 22,
              color: gold,
              shadows: _hover
                  ? [
                      Shadow(color: gold.withValues(alpha: 0.5), blurRadius: 14),
                      Shadow(color: gold.withValues(alpha: 0.2), blurRadius: 8),
                    ]
                  : const [],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            widget.data.label,
            style: GoogleFonts.openSans(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: gold,
              height: 1.1,
            ),
          ),
        ],
      ),
    );

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: Padding(
        padding: EdgeInsets.only(bottom: isHorizontal ? 0 : 16),
        child: card,
      ),
    );
  }
}

class _StepData {
  const _StepData(this.label, this.icon);
  final String label;
  final IconData icon;
}

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
      padding: EdgeInsets.fromLTRB(
        16,
        isMobile ? 40 : 56,
        16,
        isMobile ? 20 : 30,
      ),
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
                        alignment: Alignment.topLeft,
                        child: FractionallySizedBox(
                          widthFactor: 0.72, // make the container a bit narrower
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(minHeight: 320),
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: Theme.of(context).cardColor,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: Colors.black.withValues(alpha: .06)),
                                boxShadow: [
                                  BoxShadow(color: Colors.black.withValues(alpha: .08), blurRadius: 12, offset: const Offset(0, 6)),
                                ],
                              ),
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(12, 28, 18, 28),
                                child: _HorizontalTimeline(steps: steps, compact: true),
                              ),
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
  const _HorizontalTimeline({required this.steps, this.compact = false});
  final List<_StepData> steps;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: compact ? 12 : 14,
      runSpacing: compact ? 16 : 18,
      crossAxisAlignment: WrapCrossAlignment.center,
      alignment: WrapAlignment.center,
      children: [
        for (int i = 0; i < steps.length; i++)
          _StepCard(
            data: steps[i],
            showArrow: false,
            direction: Axis.horizontal,
            compact: compact,
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
  const _StepCard({required this.data, required this.showArrow, required this.direction, this.compact = false});
  final _StepData data;
  final bool showArrow;
  final Axis direction;
  final bool compact;

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
      padding: EdgeInsets.symmetric(horizontal: widget.compact ? 14 : 16, vertical: widget.compact ? 12 : 14),
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
            width: widget.compact ? 38 : 44,
            height: widget.compact ? 38 : 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [gold.withValues(alpha: 0.25), Colors.transparent],
                radius: 0.8,
              ),
            ),
            child: Icon(
              widget.data.icon,
              size: widget.compact ? 20 : 22,
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
              fontSize: widget.compact ? 14.5 : 16,
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

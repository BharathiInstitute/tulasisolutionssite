import 'package:flutter/material.dart';
import 'package:flutter_feather_icons/flutter_feather_icons.dart';
import 'package:google_fonts/google_fonts.dart';

class WhatWeDoSection extends StatelessWidget {
  const WhatWeDoSection({super.key});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final isMobile = size.width < 720;

    const bg = Color(0xFFF8F8F8);
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
      child: Align(
        alignment: Alignment.centerLeft,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: isMobile
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _SectionHeadline(isMobile: true, titleColor: titleColor, subtitleColor: subtitleColor),
                    const SizedBox(height: 28),
                    _VerticalTimeline(steps: steps),
                    const SizedBox(height: 40),
                    const _WhatWeDoImage(maxHeight: 300, radius: 28),
                  ],
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Left text + timeline
                    Expanded(
                      flex: 6,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const _SectionHeadline(isMobile: false, titleColor: titleColor, subtitleColor: subtitleColor),
                          const SizedBox(height: 32),
                          _HorizontalTimeline(steps: steps),
                        ],
                      ),
                    ),
                    const SizedBox(width: 28),
                    // Right image (What We Do main image)
                        Expanded(
                          flex: 5,
                          child: Align(
                            alignment: Alignment.topRight,
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 520),
                              child: const _WhatWeDoImage(maxHeight: 420, radius: 32),
                            ),
                          ),
                        ),
                  ],
                ),
        ),
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
          style: GoogleFonts.lora(
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
          style: GoogleFonts.nunito(
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

class _WhatWeDoImage extends StatelessWidget {
  const _WhatWeDoImage({required this.maxHeight, required this.radius});
  final double maxHeight; final double radius;
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final dpr = MediaQuery.of(context).devicePixelRatio;
        // Target decode width ~ visible width * DPR, with sane bounds to avoid jank
        final targetWidth = (constraints.maxWidth.isFinite
                ? constraints.maxWidth
                : 520.0) // fallback to our typical max width
            * dpr;
        final cacheWidth = targetWidth.clamp(300, 1600).round();

        return AspectRatio(
          aspectRatio: 1.25,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(radius),
            child: Image.asset(
              'assets/what.we.do.section.png',
              fit: BoxFit.contain,
              filterQuality: FilterQuality.medium,
              cacheWidth: cacheWidth,
              errorBuilder: (ctx, err, stack) => Image.asset(
                'assets/home_page.png',
                fit: BoxFit.contain,
                filterQuality: FilterQuality.medium,
                cacheWidth: cacheWidth,
                errorBuilder: (ctx2, err2, stack2) => Container(
                  color: Colors.grey.shade100,
                  alignment: Alignment.center,
                  child: Icon(Icons.broken_image, color: Colors.grey.shade400, size: 48),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _HorizontalTimeline extends StatelessWidget {
  const _HorizontalTimeline({required this.steps});
  final List<_StepData> steps;

  @override
  Widget build(BuildContext context) {
    const gold = Color(0xFFD4AF37);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Accent line behind steps
        Positioned.fill(
          top: 46,
          child: Align(
            alignment: Alignment.topCenter,
            child: Container(
              height: 2,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [gold.withValues(alpha: 0.15), gold.withValues(alpha: 0.45), gold.withValues(alpha: 0.15)],
                ),
              ),
            ),
          ),
        ),
        Wrap(
          spacing: 14,
          runSpacing: 18,
          crossAxisAlignment: WrapCrossAlignment.center,
          alignment: WrapAlignment.center,
          children: [
            for (int i = 0; i < steps.length; i++)
              _StepCard(
                data: steps[i],
                showArrow: i < steps.length - 1,
                direction: Axis.horizontal,
              ),
          ],
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
            showArrow: i < steps.length - 1,
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
            style: GoogleFonts.playfairDisplay(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: gold,
              height: 1.1,
            ),
          ),
        ],
      ),
    );

    final arrow = widget.showArrow
        ? (isHorizontal
            ? const Icon(Icons.arrow_forward_ios, size: 16, color: Color(0xFFD4AF37))
            : const Icon(Icons.arrow_downward, size: 18, color: Color(0xFFD4AF37)))
        : const SizedBox.shrink();

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: Padding(
        padding: EdgeInsets.only(bottom: isHorizontal ? 0 : 16),
        child: isHorizontal
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [card, const SizedBox(width: 8), arrow, const SizedBox(width: 8)],
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [card, const SizedBox(height: 8), arrow, const SizedBox(height: 8)],
              ),
      ),
    );
  }
}

class _StepData {
  const _StepData(this.label, this.icon);
  final String label;
  final IconData icon;
}

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_feather_icons/flutter_feather_icons.dart';
import 'package:google_fonts/google_fonts.dart';

class HowItWorksSection extends StatelessWidget {
  const HowItWorksSection({super.key});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final isTablet = size.width < 1100 && size.width >= 700;
    final isMobile = size.width < 700;

    const bg = Color(0xFFF8F8F8);
    const titleColor = Color(0xFF443F3F);
    const subtitleColor = Color(0xFF7D5B4C);

    final steps = <_HowStep>[
      _HowStep('Discover', FeatherIcons.search, 'Understand goals & audience.'),
      _HowStep('Design', FeatherIcons.edit3, 'Craft strategy & visuals.'),
      _HowStep('Deploy', FeatherIcons.send, 'Launch campaigns & platforms.'),
      _HowStep('Grow', FeatherIcons.trendingUp, 'Measure KPIs & scale.'),
    ];

    return Container(
      color: bg,
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: isMobile ? 80 : 100),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                'How It Works',
                textAlign: TextAlign.center,
                style: GoogleFonts.lora(
                  fontSize: isMobile ? 26 : 30,
                  fontWeight: FontWeight.w700,
                  color: titleColor,
                ),
              ),
              const SizedBox(height: 14),
              // Newly added illustrative image under the heading
              LayoutBuilder(
                builder: (context, constraints) {
                  final maxW = constraints.maxWidth;
                  final double imgWidth = maxW.clamp(240, isMobile ? 420 : 560);
                  return Semantics(
                    label: 'Process phases illustration: Discover, Design, Deploy, Grow',
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                          child: Image.asset(
                            'assets/how.it.works.section.png',
                        width: imgWidth.toDouble(),
                        fit: BoxFit.cover,
                        filterQuality: FilterQuality.medium,
                        // Provide a modest cacheWidth to avoid decoding huge source on web/mobile
                        cacheWidth: (imgWidth * (MediaQuery.devicePixelRatioOf(context))).toInt().clamp(600, 1400),
                            errorBuilder: (c, e, st) => Container(
                              width: imgWidth.toDouble(),
                              height: (imgWidth * 0.55),
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: Colors.grey.shade200,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: Colors.grey.shade300),
                              ),
                              child: const Text('Image missing', style: TextStyle(color: Colors.black54)),
                            ),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 18),
              Text(
                'Clear milestones & KPIs at each step.',
                textAlign: TextAlign.center,
                style: GoogleFonts.nunito(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: subtitleColor,
                ),
              ),
              const SizedBox(height: 28),
              if (!isMobile && !isTablet)
                _HorizontalSteps(steps: steps)
              else if (isTablet)
                _GridSteps(steps: steps)
              else
                _VerticalSteps(steps: steps),
            ],
          ),
        ),
      ),
    );
  }
}

class _HorizontalSteps extends StatelessWidget {
  const _HorizontalSteps({required this.steps});
  final List<_HowStep> steps;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 16,
      runSpacing: 18,
      crossAxisAlignment: WrapCrossAlignment.center,
      alignment: WrapAlignment.center,
      children: [
        for (int i = 0; i < steps.length; i++) ...[
          _HowStepCard(step: steps[i], index: i, direction: Axis.horizontal),
          if (i < steps.length - 1)
            const Icon(Icons.arrow_forward_ios, size: 18, color: Color(0xFFD4AF37)),
        ],
      ],
    );
  }
}

class _VerticalSteps extends StatelessWidget {
  const _VerticalSteps({required this.steps});
  final List<_HowStep> steps;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (int i = 0; i < steps.length; i++) ...[
          _HowStepCard(step: steps[i], index: i, direction: Axis.vertical),
          if (i < steps.length - 1)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8.0),
              child: Icon(Icons.arrow_downward, size: 20, color: Color(0xFFD4AF37)),
            ),
        ],
      ],
    );
  }
}

class _GridSteps extends StatelessWidget {
  const _GridSteps({required this.steps});
  final List<_HowStep> steps;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      itemCount: steps.length,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisExtent: 200,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemBuilder: (context, i) => _HowStepCard(step: steps[i], index: i, direction: Axis.horizontal),
    );
  }
}

class _HowStepCard extends StatefulWidget {
  const _HowStepCard({required this.step, required this.index, required this.direction});
  final _HowStep step;
  final int index;
  final Axis direction;

  @override
  State<_HowStepCard> createState() => _HowStepCardState();
}

class _HowStepCardState extends State<_HowStepCard> with SingleTickerProviderStateMixin {
  bool _hover = false;
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 500),
  );
  late final Animation<double> _opacity = CurvedAnimation(parent: _c, curve: Curves.easeOut);
  late final Animation<Offset> _offset = Tween(
    begin: const Offset(0, 0.15),
    end: Offset.zero,
  ).animate(CurvedAnimation(parent: _c, curve: Curves.easeOutCubic));

  @override
  void initState() {
    super.initState();
    // Stagger number entrance based on index
    unawaited(Future.delayed(Duration(milliseconds: 120 * widget.index), () {
      if (mounted) _c.forward();
    }));
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const gold = Color(0xFFD4AF37);

    final number = Stack(
      alignment: Alignment.center,
      children: [
        // subtle glow behind number
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [gold.withValues(alpha: 0.25), Colors.transparent],
              radius: 0.8,
            ),
          ),
        ),
        FadeTransition(
          opacity: _opacity,
          child: SlideTransition(
            position: _offset,
            child: Text(
              '${widget.index + 1}',
              style: GoogleFonts.poppins(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: gold,
                height: 1.0,
              ),
            ),
          ),
        ),
      ],
    );

    final card = AnimatedContainer(
      duration: const Duration(milliseconds: 140),
      curve: Curves.easeOut,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: _hover ? 0.08 : 0.05),
            blurRadius: _hover ? 16 : 10,
            offset: const Offset(0, 6),
          ),
        ],
        border: Border.all(color: gold.withValues(alpha: 0.15)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          number,
          const SizedBox(height: 8),
          Icon(widget.step.icon, size: 28, color: gold),
          const SizedBox(height: 8),
          Text(
            widget.step.label,
            textAlign: TextAlign.center,
            style: GoogleFonts.playfairDisplay(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: gold,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            widget.step.desc,
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(fontSize: 12.5, color: Colors.black87),
          ),
        ],
      ),
    );

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedScale(
        scale: _hover ? 1.03 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: card,
      ),
    );
  }
}

class _HowStep {
  const _HowStep(this.label, this.icon, this.desc);
  final String label;
  final IconData icon;
  final String desc;
}

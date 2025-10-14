import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class CaseStudiesTestimonialsSection extends StatefulWidget {
  const CaseStudiesTestimonialsSection({super.key});

  @override
  State<CaseStudiesTestimonialsSection> createState() => _CaseStudiesTestimonialsSectionState();
}

class _CaseStudiesTestimonialsSectionState extends State<CaseStudiesTestimonialsSection> with TickerProviderStateMixin {
  late final AnimationController _introController;
  late final Animation<double> _statsFade;
  late final Animation<double> _statsScale;
  late final Animation<double> _testFade;
  late final Animation<Offset> _testSlide;

  final _testimonials = const [
    (
      quote: 'Tulasi grew our qualified leads and doubled conversions within a quarter.',
      client: 'Priya S, Growth Lead',
      company: 'Acme Retail'
    ),
    (
      quote: 'Clear strategy, crisp execution. Our site is fast and funnels perform.',
      client: 'Rahul M, Founder',
      company: 'HealthPlus'
    ),
    (
      quote: 'From chaos to clarity—dashboards, automations, and real results.',
      client: 'Nandini K, COO',
      company: 'LogiTrans'
    ),
  ];
  int _currentTestimonial = 0;
  Timer? _rotator;

  @override
  void initState() {
    super.initState();
    _introController = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..forward();
    _statsFade = CurvedAnimation(parent: _introController, curve: const Interval(0.0, 0.6, curve: Curves.easeOut));
    _statsScale = Tween<double>(begin: .96, end: 1).animate(CurvedAnimation(parent: _introController, curve: const Interval(0.0, 0.6, curve: Curves.easeOutBack)));
    _testFade = CurvedAnimation(parent: _introController, curve: const Interval(0.25, 1.0, curve: Curves.easeOut));
    _testSlide = Tween<Offset>(begin: const Offset(.06, 0), end: Offset.zero)
        .animate(CurvedAnimation(parent: _introController, curve: const Interval(0.25, 1.0, curve: Curves.easeOut)));

    // Rotate testimonials every 6 seconds (simple timer; no scroll visibility listener to avoid per-frame setState during scroll)
    _rotator = Timer.periodic(const Duration(seconds: 6), (_) {
      if (!mounted) return;
      setState(() => _currentTestimonial = (_currentTestimonial + 1) % _testimonials.length);
    });
  }

  @override
  void dispose() {
    _rotator?.cancel();
    _introController.dispose();
    super.dispose();
  }

  // Visibility tracking removed to eliminate expensive globalToLocal calls each scroll.

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    final isDesktop = w >= 1000;
    final isTablet = w >= 600 && w < 1000;

    final EdgeInsets horizontal = EdgeInsets.symmetric(horizontal: isDesktop ? 32 : (isTablet ? 28 : 20));
    final EdgeInsets vertical = EdgeInsets.symmetric(vertical: isDesktop ? 80 : (isTablet ? 64 : 52));

    final content = ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 1240),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          Text(
            'Case Studies & Testimonials',
            style: TextStyle(
              fontSize: isDesktop ? 24 : (isTablet ? 22 : 20),
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 18),
          _buildCardsLayout(context, isDesktop: isDesktop, isTablet: isTablet),
        ],
      ),
    );

    final double sectionHeight = isDesktop ? 560 : (isTablet ? 600 : 640);
    return SizedBox(
        height: sectionHeight,
        width: double.infinity,
        child: Stack(
          children: [
            // Collage background (abstract without external assets)
            Positioned.fill(child: IgnorePointer(child: RepaintBoundary(child: _BackgroundCollage()))),
            // Gradient readability overlay
            Positioned.fill(
              child: IgnorePointer(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFF2D89FF).withValues(alpha: 0.38),
                        const Color(0xFF7B3AED).withValues(alpha: 0.38),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                ),
              ),
            ),
            // Foreground content
            Positioned.fill(
              child: Padding(
                padding: horizontal + vertical,
                child: Center(child: content),
              ),
            ),
          ],
        ),
      );
  }

  Widget _buildCardsLayout(BuildContext context, {required bool isDesktop, required bool isTablet}) {
    final cards = <Widget>[
      FadeTransition(
        opacity: _statsFade,
        child: ScaleTransition(
          scale: _statsScale,
          child: _HoverLift(
            child: Semantics(
              container: true,
              label: 'Case Study: traffic increased from 12 thousand to 48 thousand; leads from 320 to 980; conversions from 2.1 percent to 4.5 percent.',
              child: _CaseStudyCard(),
            ),
          ),
        ),
      ),
      FadeTransition(
        opacity: _testFade,
        child: SlideTransition(
          position: _testSlide,
          child: _HoverLift(
            child: _TestimonialCard(
              data: _testimonials[_currentTestimonial],
            ),
          ),
        ),
      ),
    ];

    if (isDesktop) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: cards[0]),
          const SizedBox(width: 20),
          Expanded(child: cards[1]),
        ],
      );
    }

    // Tablet & Mobile: stacked
    return Column(
      children: [
        cards[0],
        const SizedBox(height: 16),
        cards[1],
      ],
    );
  }
}

class _BackgroundCollage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: Stack(
        children: [
          // Base gradient wash
          const IgnorePointer(
            ignoring: true,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF0F172A), Color(0xFF111827)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ),
          // Faux "screenshots" as soft panels
          ...[
            const Offset(60, 80),
            const Offset(260, 40),
            const Offset(520, 120),
            const Offset(860, 70),
            const Offset(1080, 160),
          ].map((o) => _panel(o)),
        ],
      ),
    );
  }

  Widget _panel(Offset origin) {
    return Positioned(
      left: origin.dx,
      top: origin.dy,
      child: Container(
        width: 220,
        height: 110,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: Colors.white.withValues(alpha: 0.06),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
          ],
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(height: 8, width: 70, color: Colors.white24),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: Container(height: 8, color: Colors.white12)),
                const SizedBox(width: 6),
                Expanded(child: Container(height: 8, color: Colors.white12)),
              ],
            ),
            const Spacer(),
            Row(
              children: [
                Container(width: 36, height: 8, color: Colors.white24),
                const SizedBox(width: 6),
                Container(width: 20, height: 8, color: Colors.white12),
                const Spacer(),
                Container(width: 44, height: 8, color: Colors.white24),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _HoverLift extends StatefulWidget {
  const _HoverLift({required this.child});
  final Widget child;

  @override
  State<_HoverLift> createState() => _HoverLiftState();
}

class _HoverLiftState extends State<_HoverLift> {
  bool _hovering = false;
  @override
  Widget build(BuildContext context) {
    final child = AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      transform: _hovering ? (Matrix4.identity()..translate(0.0, -6.0)) : Matrix4.identity(),
      child: widget.child,
    );
    if (!kIsWeb) return child; // hover effect mainly for web/desktop
    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: child,
    );
  }
}

class _GlassCard extends StatelessWidget {
  const _GlassCard({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    // Removed BackdropFilter blur (expensive during scroll). Using solid card with light opacity.
    return RepaintBoundary(
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.95),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.10),
              blurRadius: 12,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 22),
        child: child,
      ),
    );
  }
}

class _CaseStudyCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    const labelStyle = TextStyle(fontSize: 13, color: Colors.black54);
    const beforeStyle = TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: Color(0xFFDC2626)); // red-600
    const afterStyle = TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: Color(0xFF16A34A)); // green-600
    const gold = Color(0xFFD4AF37);

    Widget stat(String label, String before, String after, {double beforePct = .4, double afterPct = .8}) {
      return Semantics(
        label: '$label before: $before, after: $after',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: labelStyle),
            const SizedBox(height: 6),
            Row(
              children: [
                Text(before, style: beforeStyle),
                const SizedBox(width: 6),
                const Icon(Icons.arrow_forward_rounded, size: 18, color: Color(0xFF16A34A)),
                const SizedBox(width: 6),
                Text(after, style: afterStyle),
              ],
            ),
            const SizedBox(height: 8),
            // mini bars
            Row(
              children: [
                Expanded(
                  flex: (beforePct * 100).toInt(),
                  child: Container(
                    height: 6,
                    decoration: BoxDecoration(
                      color: const Color(0xFFDC2626).withValues(alpha: .25),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  flex: (afterPct * 100).toInt(),
                  child: Container(
                    height: 6,
                    decoration: BoxDecoration(
                      color: const Color(0xFF16A34A),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
                const Spacer(),
              ],
            ),
          ],
        ),
      );
    }

    return _GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.analytics_outlined, size: 22, color: gold),
              SizedBox(width: 8),
              Text('Before vs After', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 14),
          stat('Traffic', '12k', '48k', beforePct: .3, afterPct: .9),
          const SizedBox(height: 14),
          stat('Leads', '320', '980', beforePct: .4, afterPct: .85),
          const SizedBox(height: 14),
          stat('Conversions', '2.1%', '4.5%', beforePct: .35, afterPct: .7),
        ],
      ),
    );
  }
}

class _TestimonialCard extends StatelessWidget {
  const _TestimonialCard({
    required this.data,
  });

  final ({String quote, String client, String company}) data;

  @override
  Widget build(BuildContext context) {
    const quoteStyle = TextStyle(fontStyle: FontStyle.italic, color: Color(0xFF1F2937), fontSize: 16);
    const gold = Color(0xFFD4AF37);
    const nameStyle = TextStyle(fontWeight: FontWeight.w700, fontSize: 15);
    const labelStyle = TextStyle(fontSize: 13, color: Colors.black54);

    return _GlassCard(
      child: Semantics(
        container: true,
        label: 'Testimonial from ${data.client} at ${data.company}',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: const [
                Icon(Icons.chat_bubble_outline, size: 22, color: gold),
                SizedBox(width: 8),
                Text('What clients say', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              ],
            ),
            const SizedBox(height: 14),
            // Centered quote, keep punctuation decorative but expose semantics below
            ExcludeSemantics(
              child: Text('“${data.quote}”', style: quoteStyle, textAlign: TextAlign.center),
            ),
            Semantics(label: 'Quote: ${data.quote}'),
            const SizedBox(height: 12),
            // Ratings row with Material stars, plus semantic value
            Row(
              children: const [
                Icon(Icons.star, color: Colors.amber, size: 18),
                Icon(Icons.star, color: Colors.amber, size: 18),
                Icon(Icons.star, color: Colors.amber, size: 18),
                Icon(Icons.star, color: Colors.amber, size: 18),
                Icon(Icons.star, color: Colors.amber, size: 18),
                SizedBox(width: 8),
              ],
            ),
            Semantics(label: 'Rating 5 out of 5 stars'),
            const SizedBox(height: 12),
            Text(data.client, style: nameStyle),
            Text(data.company, style: labelStyle),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import '../sections/layout/site_scaffold.dart';

class PricingPage extends StatelessWidget {
  const PricingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return SiteScaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      body: const SingleChildScrollView(
        physics: ClampingScrollPhysics(),
        child: Padding(
          padding: EdgeInsets.fromLTRB(16, 20, 16, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _IntroSection(),
              SizedBox(height: 20),
              _PlansSection(),
              SizedBox(height: 28),
              _FinalCtaSection(),
            ],
          ),
        ),
      ),
    );
  }
}

class _IntroSection extends StatelessWidget {
  const _IntroSection();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1100),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                scheme.primary.withValues(alpha: .08),
                scheme.secondary.withValues(alpha: .05),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Text(
                'Simple Plans, Transparent Pricing',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 10),
              Text(
                'Choose the plan that fits your stage of growth. No hidden costs — hosting, ad spend, and paid tools billed at actuals.',
                style: TextStyle(color: Colors.black.withValues(alpha: .7), height: 1.4),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 14),
              const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('💡', style: TextStyle(fontSize: 22)),
                  SizedBox(width: 8),
                  Text('⚖️', style: TextStyle(fontSize: 22)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlansSection extends StatelessWidget {
  const _PlansSection();

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final isMobile = width < 760;

    final plans = <_PlanModel>[
      _PlanModel(
        id: 'starter',
        title: 'Starter',
        price: '₹3,000/month',
        bestFor: 'New businesses & solopreneurs',
        icon: '🌱',
        gradient: const LinearGradient(colors: [Color(0xFFE7F7EC), Color(0xFFCCF1DA)]),
        chipBg: const Color(0xFF2E7D32),
        features: const [
          'Branding basics',
          '1-page site or landing page',
          'Google My Business setup',
          'CRM lite',
          '2 automations (WhatsApp/Email/SMS)',
          'Monthly review',
        ],
        mockupHint: 'Small business store mockup',
      ),
      _PlanModel(
        id: 'growth',
        title: 'Growth',
        price: '₹5,000/month',
        bestFor: 'Growing SMBs ready for regular marketing',
        icon: '🌿',
        gradient: const LinearGradient(colors: [Color(0xFFE6F0FF), Color(0xFFD4E3FF)]),
        chipBg: const Color(0xFF0D47A1),
        features: const [
          'Full website',
          'Monthly content calendar (8–12 posts/reels)',
          'WhatsApp + Email automations',
          'CRM + Inventory setup',
          '2 training sessions',
          'Monthly review & strategy',
        ],
        mockupHint: 'Branded social posts + CRM dashboard',
      ),
      _PlanModel(
        id: 'expansion',
        title: 'Expansion',
        price: '₹10,000/month',
        bestFor: 'Scaling into multi-location or advanced automation',
        icon: '🚀',
        gradient: const LinearGradient(colors: [Color(0xFFF0E6FF), Color(0xFFE6D9FF)]),
        chipBg: const Color(0xFF6F42C1),
        features: const [
          'Multi-landing funnels',
          'Paid ads management',
          'Advanced automations (WA/Email/SMS)',
          'HR & Accounts workflows',
          'Service desk',
          'Weekly reviews & quarterly planning',
        ],
        mockupHint: 'Map pins + analytics dashboard',
      ),
      _PlanModel(
        id: 'enterprise',
        title: 'Enterprise / Custom',
        price: null,
        bestFor: 'Need custom solutions?',
        icon: '🏢',
        gradient: const LinearGradient(colors: [Color(0xFF0F172A), Color(0xFF1F2937)], begin: Alignment.topLeft, end: Alignment.bottomRight),
        chipBg: const Color(0xFF0F172A),
        features: const [
          'Enterprise pricing on request',
          'Build exactly what you need',
          'Priority support & governance',
        ],
        mockupHint: 'Corporate suite & governance',
        dark: true,
      ),
    ];

  if (isMobile) {
      return Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: SizedBox(
      height: 440,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 8),
              itemCount: plans.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, i) => _AppearOnBuild(
                delayMs: 80 * i,
                child: _PlanCard(model: plans[i], width: 300),
              ),
            ),
          ),
        ),
      );
    }

    // Tablet/Web: responsive grid
    int crossAxisCount;
    double mainAxisExtent;
    if (width >= 1200) {
      crossAxisCount = 3;
      mainAxisExtent = 460; // taller to prevent overflow on wide screens
    } else if (width >= 900) {
      crossAxisCount = 2;
      mainAxisExtent = 500; // text wraps more; give extra height
    } else {
      crossAxisCount = 2;
      mainAxisExtent = 520;
    }

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1200),
        child: GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            mainAxisSpacing: 14,
            crossAxisSpacing: 14,
            mainAxisExtent: mainAxisExtent,
          ),
          itemCount: plans.length,
          itemBuilder: (context, i) => _AppearOnBuild(
            delayMs: 90 * i,
            child: _PlanCard(model: plans[i]),
          ),
        ),
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({required this.model, this.width});
  final _PlanModel model;
  final double? width;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = model.dark;
    final baseText = TextStyle(color: dark ? Colors.white : Colors.black87);

    final card = Container(
      width: width,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .06),
            blurRadius: 14,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          children: [
            // Background gradient per plan
            Container(
              decoration: BoxDecoration(
                gradient: model.gradient,
              ),
            ),
            // Content
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(model.icon, style: const TextStyle(fontSize: 24)),
                      const SizedBox(width: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: (model.dark ? Colors.white : model.chipBg).withValues(alpha: model.dark ? .1 : .12),
                          borderRadius: BorderRadius.circular(30),
                          border: Border.all(color: (model.dark ? Colors.white70 : model.chipBg).withValues(alpha: .25)),
                        ),
                        child: Text(
                          model.title,
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            color: dark ? Colors.white : model.chipBg,
                          ),
                        ),
                      ),
                      const Spacer(),
                      if (model.price != null)
                        Text(
                          model.price!,
                          style: baseText.copyWith(fontSize: 14, fontWeight: FontWeight.w700),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(model.bestFor, style: baseText.copyWith(color: baseText.color!.withValues(alpha: .8))),
                  const SizedBox(height: 10),
                  // Feature list
                  ...model.features.take(6).map((f) => Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.check_circle, size: 16, color: dark ? Colors.white70 : scheme.primary),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                f,
                                style: baseText.copyWith(fontSize: 13.5, height: 1.3),
                              ),
                            ),
                          ],
                        ),
                      )),
                  const SizedBox(height: 12),
                  // Visual mockup placeholder
                  _MockupHint(text: model.mockupHint, dark: dark),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (model.id == 'enterprise')
                        FilledButton(
                          onPressed: () => _showSnack(context, 'Talk to a Business Manager'),
                          style: FilledButton.styleFrom(
                            backgroundColor: dark ? Colors.white : scheme.primary,
                            foregroundColor: dark ? Colors.black : Colors.white,
                          ),
                          child: const Text('Talk to a Business Manager →'),
                        )
                      else
                        FilledButton(
                          onPressed: () => _showSnack(context, 'Selected ${model.title}'),
                          child: const Text('Choose Plan'),
                        ),
                      TextButton(
                        onPressed: () => _showSnack(context, 'Book a Free Demo'),
                        style: TextButton.styleFrom(foregroundColor: dark ? Colors.white : scheme.primary),
                        child: const Text('Book a Free Demo'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: TweenAnimationBuilder<double>(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        tween: Tween(begin: 1.0, end: 1.0),
        builder: (context, v, child) => AnimatedScale(
          scale: 1.0,
          duration: const Duration(milliseconds: 120),
          child: child,
        ),
        child: card,
      ),
    );
  }

  static void _showSnack(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }
}

class _MockupHint extends StatelessWidget {
  const _MockupHint({required this.text, this.dark = false});
  final String text;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 80,
      decoration: BoxDecoration(
  color: dark ? Colors.white.withValues(alpha: .05) : Colors.white.withValues(alpha: .7),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: dark ? Colors.white24 : Colors.black12),
      ),
      child: Row(
        children: [
          const SizedBox(width: 12),
          Icon(Icons.widgets_outlined, color: dark ? Colors.white70 : Colors.black45),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: dark ? Colors.white70 : Colors.black54),
            ),
          ),
          const SizedBox(width: 12),
        ],
      ),
    );
  }
}

class _FinalCtaSection extends StatelessWidget {
  const _FinalCtaSection();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 900),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: .95),
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: .05), blurRadius: 12, offset: const Offset(0, 6)),
            ],
          ),
          child: Column(
            children: [
              const Text(
                'Not sure which plan fits you?',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 12),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.icon(
                    onPressed: () => _showSnack(context, 'Book a Free Demo'),
                    icon: const Icon(Icons.calendar_month),
                    label: const Text('Book a Free Demo'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => _showSnack(context, 'Chat with us'),
                    style: OutlinedButton.styleFrom(foregroundColor: scheme.primary),
                    icon: const Icon(Icons.chat_bubble_outline),
                    label: const Text('Chat with us'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  static void _showSnack(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }
}

class _PlanModel {
  const _PlanModel({
    required this.id,
    required this.title,
    required this.price,
    required this.bestFor,
    required this.icon,
    required this.gradient,
    required this.chipBg,
    required this.features,
    required this.mockupHint,
    this.dark = false,
  });
  final String id;
  final String title;
  final String? price;
  final String bestFor;
  final String icon; // using emoji for quick visuals
  final LinearGradient gradient;
  final Color chipBg;
  final List<String> features;
  final String mockupHint;
  final bool dark;
}

class _AppearOnBuild extends StatefulWidget {
  const _AppearOnBuild({required this.child, this.delayMs = 0});
  final Widget child;
  final int delayMs;

  @override
  State<_AppearOnBuild> createState() => _AppearOnBuildState();
}

class _AppearOnBuildState extends State<_AppearOnBuild> {
  double _t = 0;

  @override
  void initState() {
    super.initState();
    Future.delayed(Duration(milliseconds: widget.delayMs), () {
      if (mounted) setState(() => _t = 1);
    });
  }

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: _t),
      duration: const Duration(milliseconds: 380),
      curve: Curves.easeOutCubic,
      builder: (context, v, c) => Transform.scale(
        scale: 0.98 + (0.02 * v),
        child: Opacity(opacity: v, child: c),
      ),
      child: widget.child,
    );
  }
}

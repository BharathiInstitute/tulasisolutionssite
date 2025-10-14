import 'package:flutter/material.dart';
import '../sections/layout/site_scaffold.dart';
// (Reference page only; detailed industry widgets now under lib/sections/industries/*)
import '../sections/industries/models/bullet_item.dart';
import '../sections/industries/retail_playbook_card.dart';
import '../sections/industries/education_landing.dart';
import '../sections/industries/services_landing.dart';
import '../sections/industries/printing_packaging_landing.dart';
import '../sections/industries/cosmetics_landing.dart';
import '../sections/industries/startup_landing.dart';

// Consolidated: Industries overview + all sub-industry pages in one file.

class IndustriesPage extends StatelessWidget {
  const IndustriesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return SiteScaffold(
      body: SingleChildScrollView(
        physics: const ClampingScrollPhysics(),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 60),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: const [
                  _IndustriesHeader(),
                  SizedBox(height: 42),
                  _IndustryLink(label: 'Retail Growth Playbook', icon: Icons.store, route: '/industries/retail'),
                  SizedBox(height: 18),
                  _IndustryLink(label: 'Education Growth Playbook', icon: Icons.school, route: '/industries/education'),
                  SizedBox(height: 18),
                  _IndustryLink(label: 'Cosmetics Growth Playbook', icon: Icons.brush, route: '/industries/cosmetics'),
                  SizedBox(height: 18),
                  _IndustryLink(label: 'Printing & Packaging Growth Playbook', icon: Icons.print, route: '/industries/printing'),
                  SizedBox(height: 18),
                  _IndustryLink(label: 'Services Growth Playbook', icon: Icons.settings_suggest, route: '/industries/services'),
                  SizedBox(height: 18),
                  _IndustryLink(label: 'Startup Growth Playbook', icon: Icons.rocket_launch, route: '/industries/startup'),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _IndustriesHeader extends StatelessWidget {
  const _IndustriesHeader();
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Text('Industries We Support', style: TextStyle(fontSize: 36, fontWeight: FontWeight.w800)),
        const SizedBox(height: 14),
        Text(
          'Choose a playbook below to explore tailored systems, assets & growth levers.',
          style: TextStyle(fontSize: 16, color: Colors.black.withValues(alpha: .70)),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _IndustryLink extends StatefulWidget {
  const _IndustryLink({required this.label, required this.icon, required this.route});
  final String label;
  final IconData icon;
  final String route;
  @override
  State<_IndustryLink> createState() => _IndustryLinkState();
}

class _IndustryLinkState extends State<_IndustryLink> {
  bool _hover = false;
  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    final radius = BorderRadius.circular(18);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOut,
        transform: Matrix4.identity()
          ..translate(0.0, _hover ? -2.0 : 0.0)
          ..scale(_hover ? 1.01 : 1.0),
        child: TweenAnimationBuilder<double>(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOut,
          tween: Tween<double>(begin: 3, end: _hover ? 8 : 3),
          builder: (context, elevation, child) => Material(
            color: Colors.white,
            elevation: elevation,
            clipBehavior: Clip.antiAlias,
            shape: RoundedRectangleBorder(
              borderRadius: radius,
              side: BorderSide(color: Colors.black.withValues(alpha: .08)),
            ),
            child: InkWell(
              onTap: () => Navigator.of(context).pushNamed(widget.route),
              onHover: (h) => setState(() => _hover = h),
              customBorder: RoundedRectangleBorder(borderRadius: radius),
              hoverColor: accent.withValues(alpha: 0.05),
              splashColor: accent.withValues(alpha: 0.10),
              highlightColor: accent.withValues(alpha: 0.08),
              child: Semantics(
                button: true,
                label: widget.label,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 160),
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: _hover ? accent.withValues(alpha: .16) : accent.withValues(alpha: .10),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(widget.icon, color: accent),
                      ),
                      const SizedBox(width: 18),
                      Expanded(
                        child: Text(widget.label, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                      ),
                      Icon(Icons.arrow_forward_rounded, color: accent, size: 20),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// Small reusable industry card for quick access grid
class IndustriesRetailPage extends StatelessWidget {
  const IndustriesRetailPage({super.key});

  @override
  Widget build(BuildContext context) {
    final bullets = const [
      BulletItem(text: 'Persona packs (walk-in shoppers, repeat buyers)', icon: Icons.person_outline),
      BulletItem(text: 'Website sections that sell (POS + offers)', icon: Icons.point_of_sale_outlined),
      BulletItem(text: 'Promotions & loyalty SOPs', icon: Icons.campaign_outlined),
      BulletItem(text: 'Retail KPIs (footfall, conversion, basket size)', icon: Icons.show_chart),
    ];

    return SiteScaffold(
      backgroundColor: Colors.transparent,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: RetailPlaybookCard(
              title: 'Retail Growth Playbook',
              subtitle: 'We streamline billing, inventory, and promotions for shops of all sizes.',
              bullets: bullets,
              onPrimaryTap: () {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Open Retail Playbook')));
              },
              onSecondaryTap: () {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Contact sales')));
              },
            ),
          ),
        ),
      ),
    );
  }
}

class IndustriesEducationPage extends StatelessWidget {
  const IndustriesEducationPage({super.key});

  @override
  Widget build(BuildContext context) {
    return SiteScaffold(
      backgroundColor: Colors.transparent,
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1200),
              child: EducationPlaybookLanding(
                data: sampleEducationContent(
                  onPrimary: () {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Open Education Playbook')));
                  },
                  onSecondary: () {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Open sample persona')));
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class IndustriesServicesPage extends StatelessWidget {
  const IndustriesServicesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return SiteScaffold(
      backgroundColor: Colors.transparent,
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1200),
              child: ServicesPlaybookLanding(
                data: sampleServicesContent(
                  onPrimary: () {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Open Services Playbook')));
                  },
                  onSecondary: () {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('See sample packages')));
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class IndustriesPrintingPage extends StatelessWidget {
  const IndustriesPrintingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return SiteScaffold(
      backgroundColor: Colors.transparent,
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1200),
              child: PrintingPlaybookLanding(
                data: samplePrintingContent(
                  onPrimary: () {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Open Printing & Packaging Playbook')));
                  },
                  onSecondary: () {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('See sample catalog')));
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class IndustriesCosmeticsPage extends StatelessWidget {
  const IndustriesCosmeticsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return SiteScaffold(
      backgroundColor: Colors.transparent,
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1200),
              child: CosmeticsPlaybookLanding(
                data: sampleCosmeticsContent(
                  onPrimary: () {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Buy Now (Cosmetics)')));
                  },
                  onSecondary: () {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Open campaign ideas')));
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class IndustriesStartupPage extends StatelessWidget {
  const IndustriesStartupPage({super.key});

  @override
  Widget build(BuildContext context) {
    return SiteScaffold(
      backgroundColor: const Color(0xFFF7F7F7),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1200),
              child: StartupPlaybookLanding(
                data: sampleStartupContent(
                  onPrimary: () {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Open Startup Playbook')));
                  },
                  onSecondary: () {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('See sample templates')));
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Hero right-side image widget for IndustriesPage

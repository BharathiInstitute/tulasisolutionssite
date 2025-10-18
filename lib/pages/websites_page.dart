import 'package:flutter/material.dart';
import '../sections/layout/site_scaffold.dart';
import '../sections/services/page_background.dart';
import '../sections/services/websites/main_website_hero_section.dart';
import '../sections/services/websites/landing_pages_hero_section.dart';
import '../sections/services/websites/forms_lead_capture_hero_section.dart';
// Navigation between services is via global header now; remove per-page nav imports

class WebsitesPage extends StatefulWidget {
  const WebsitesPage({super.key});

  @override
  State<WebsitesPage> createState() => _WebsitesPageState();
}

class _WebsitesPageState extends State<WebsitesPage> {
  final _mainKey = GlobalKey();
  final _landingKey = GlobalKey();
  final _formsKey = GlobalKey();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final arg = ModalRoute.of(context)?.settings.arguments;
    if (arg is String) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollTo(arg));
    }
  }

  void _scrollTo(String id) {
    final l = id.toLowerCase();
    GlobalKey? key;
    if (l.contains('main')) {
      key = _mainKey;
    } else if (l.contains('landing')) {
      key = _landingKey;
    } else if (l.contains('form') || l.contains('lead')) {
      key = _formsKey;
    }
    final ctx = key?.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(ctx, duration: const Duration(milliseconds: 400), curve: Curves.easeInOutCubic, alignment: 0.05);
    }
  }
  // Removed per-page services nav; uses global header only

  @override
  Widget build(BuildContext context) {
    final neutralCard = BoxDecoration(
      color: Colors.black.withValues(alpha: 0.04),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: Colors.black12),
    );
    return SiteScaffold(
      body: PageBackground(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Websites Hero Header (keeps its gradient)
              Container(
                margin: const EdgeInsets.only(left: 16, right: 16, bottom: 20),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  gradient: const LinearGradient(
                    colors: [Color(0xFF0B63FF), Color(0xFF22D3EE)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: const [
                    BoxShadow(color: Color(0x33000000), blurRadius: 24, offset: Offset(0, 12)),
                  ],
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Websites & Funnels',
                      style: TextStyle(fontSize: 34, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: 0.5),
                    ),
                    SizedBox(height: 10),
                    Text(
                      'High-performance main site, targeted landing pages, and integrated lead capture forms working together.',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Colors.white70, height: 1.5),
                    ),
                  ],
                ),
              ),
              // Inline CTA links
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    _InlineNavLink(
                      label: 'Go to Training →',
                      semantics: 'Go to Training services',
                      onTap: () => Navigator.of(context).pushReplacementNamed('/services/training'),
                    ),
                    const SizedBox(width: 18),
                    _InlineNavLink(
                      label: 'Go to Growth →',
                      semantics: 'Go to Growth services',
                      onTap: () => Navigator.of(context).pushReplacementNamed('/services/growth'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              // Before / After summary - neutral on light background
              Container(
                padding: const EdgeInsets.all(16),
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: neutralCard,
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Before Changes', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.black87)),
                    SizedBox(height: 8),
                    Text(
                      'Old state: generic template site, slow loading pages, unclear messaging, weak lead capture.',
                      style: TextStyle(fontSize: 14, color: Colors.black87),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(16),
                margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green.withValues(alpha: 0.18)),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('After Changes', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.green)),
                    SizedBox(height: 8),
                    Text(
                      'New state: fast, conversion-focused website + dedicated landing pages + integrated lead forms.',
                      style: TextStyle(fontSize: 14, color: Colors.green),
                    ),
                  ],
                ),
              ),
              Container(key: _mainKey, child: const MainWebsiteHeroSection()),
              const SizedBox(height: 24),
              Container(key: _landingKey, child: const LandingPagesHeroSection()),
              const SizedBox(height: 24),
              Container(key: _formsKey, child: const FormsLeadCaptureHeroSection()),
              const SizedBox(height: 40),
              const Center(
                child: Padding(
                  padding: EdgeInsets.only(bottom: 16),
                  child: Text(
                    'End of Websites Overview',
                    style: TextStyle(color: Colors.black54, fontSize: 12, letterSpacing: 0.6),
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

class _InlineNavLink extends StatefulWidget {
  const _InlineNavLink({required this.label, required this.onTap, required this.semantics});
  final String label;
  final VoidCallback onTap;
  final String semantics;
  @override
  State<_InlineNavLink> createState() => _InlineNavLinkState();
}

class _InlineNavLinkState extends State<_InlineNavLink> {
  bool _hover = false;
  bool _down = false;
  @override
  Widget build(BuildContext context) {
    final decoration = TextDecoration.underline;
    final color = Colors.white;
    return Semantics(
      button: true,
      label: widget.semantics,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          onTapDown: (_) => setState(() => _down = true),
          onTapCancel: () => setState(() => _down = false),
          onTapUp: (_) => setState(() => _down = false),
          onTap: widget.onTap,
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 140),
            opacity: _down ? 0.7 : (_hover ? 0.85 : 1.0),
            child: Text(
              widget.label,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w600,
                decoration: decoration,
                letterSpacing: 0.3,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

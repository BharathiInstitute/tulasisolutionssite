import 'package:flutter/material.dart';
import '../sections/services/page_background.dart';
import '../sections/services/responsive_nav_bar.dart';
// Updated imports to new consolidated services path
import '../sections/services/branding/logo_design_section.dart';
import '../sections/services/branding/brochure_hero_section.dart';
import '../sections/services/branding/social_templates_hero_section.dart';
import 'marketing_page.dart';
import 'websites_page.dart';
import 'automation_page.dart';
import 'software_page.dart';
import 'training_page.dart';
import 'growth_page.dart';
import 'home_page.dart';

class BrandingPage extends StatefulWidget {
  const BrandingPage({super.key});

  @override
  State<BrandingPage> createState() => _BrandingPageState();
}

class _BrandingPageState extends State<BrandingPage> {
  final _scrollController = ScrollController();
  final _logoKey = GlobalKey();
  final _brochureKey = GlobalKey();
  final _socialKey = GlobalKey();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final arg = ModalRoute.of(context)?.settings.arguments;
    if (arg is String) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollTo(arg);
      });
    }
  }

  void _scrollTo(String id) {
    final lower = id.toLowerCase();
    GlobalKey? key;
    if (lower.contains('logo')) {
      key = _logoKey;
    } else if (lower.contains('brochure')) {
      key = _brochureKey;
    } else if (lower.contains('social')) {
      key = _socialKey;
    }
    final ctx = key?.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(ctx, duration: const Duration(milliseconds: 400), curve: Curves.easeInOutCubic, alignment: 0.05);
    }
  }
  void _onNavSelect(int index, String label) {
    if (label == 'Business Setup' || index == 0) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const HomePage()),
      );
      return;
    }
    if (label == 'Branding' || index == 1) {
      // already here
      return;
    }
    if (label == 'Marketing' || index == 2) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const MarketingPage()),
      );
      return;
    }
    if (label == 'Websites' || index == 3) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const WebsitesPage()),
      );
      return;
    }
    if (label == 'Software' || index == 4) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const SoftwarePage()),
      );
      return;
    }
    if (label == 'Automation' || index == 5) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const AutomationPage()),
      );
      return;
    }
    if (label == 'Training' || index == 6) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const TrainingPage()),
      );
      return;
    }
    if (label == 'Growth' || index == 7) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const GrowthPage()),
      );
      return;
    }
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: PageBackground(
          child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ResponsiveNavBar(title: 'Tulasi Site Services', activeLabel: 'Branding', onItemSelected: _onNavSelect),
            Expanded(
              child: SingleChildScrollView(
                controller: _scrollController,
                child: DefaultTextStyle.merge(
                  style: const TextStyle(color: Colors.white),
                  child: IconTheme(
                    data: const IconThemeData(color: Colors.white70),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Container(key: _logoKey, child: const LogoDesignSection()),
                          const SizedBox(height: 24),
                          Container(key: _brochureKey, child: const BrochureHeroSection()),
                          const SizedBox(height: 24),
                          Container(key: _socialKey, child: const SocialTemplatesHeroSection()),
                        ],
                      ),
                    ),
                  ),
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

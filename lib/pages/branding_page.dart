import 'package:flutter/material.dart';
import '../sections/layout/site_scaffold.dart';
import '../sections/services/page_background.dart';
// Updated imports to new consolidated services path
import '../sections/services/branding/logo_design_section.dart';
import '../sections/services/branding/brochure_hero_section.dart';
import '../sections/services/branding/social_templates_hero_section.dart';

class BrandingPage extends StatefulWidget {
  const BrandingPage({super.key});

  @override
  State<BrandingPage> createState() => _BrandingPageState();
}

class _BrandingPageState extends State<BrandingPage> {
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
  @override
  Widget build(BuildContext context) {
    return SiteScaffold(
      body: PageBackground(
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
    );
  }
}

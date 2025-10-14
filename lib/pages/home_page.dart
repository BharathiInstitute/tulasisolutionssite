import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import '../sections/layout/site_scaffold.dart';
import '../sections/hero/hero_section.dart';
import '../sections/home/featured_services_section.dart';
import '../sections/home/tooling_integrations_section.dart';
import '../sections/home/faq_final_cta_section.dart';
import '../sections/home/what_we_do_section.dart';
import '../sections/home/who_we_serve_section.dart';
import '../sections/home/how_it_works_section.dart';
import '../sections/footer/footer.dart';
import '../sections/home/case_studies_testimonials_section.dart';
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Unified scroll behavior: enables mouse, touch, trackpad, stylus drag.
    return SiteScaffold(
      body: ScrollConfiguration(
        behavior: const _HomeScrollBehavior(),
        child: PrimaryScrollController(
          controller: _scrollController,
          child: Scrollbar(
            controller: _scrollController,
            thumbVisibility: true,
            trackVisibility: true,
            interactive: true,
            radius: const Radius.circular(6),
            child: ListView(
              controller: _scrollController,
              physics: const ClampingScrollPhysics(),
              cacheExtent: 1400,
              addAutomaticKeepAlives: false,
              addSemanticIndexes: false,
              children: const [
                HeroSection(
                  onPrimary: null, // placeholder actions
                  onSecondary: null,
                ),
                FeaturedServicesSection(),
                WhatWeDoSection(),
                WhoWeServeSection(),
                HowItWorksSection(),
                CaseStudiesTestimonialsSection(),
                ToolingIntegrationsSection(),
                SizedBox(height: 16),
                FaqFinalCtaSection(),
                SizedBox(height: 64),
                FooterArea(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Custom scroll behavior to ensure all pointer device types can drag the list.
class _HomeScrollBehavior extends MaterialScrollBehavior {
  const _HomeScrollBehavior();
  @override
  Set<PointerDeviceKind> get dragDevices => const {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.trackpad,
        PointerDeviceKind.stylus,
        PointerDeviceKind.invertedStylus,
      };
}
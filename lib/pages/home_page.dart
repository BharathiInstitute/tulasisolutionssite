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
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {

  @override
  Widget build(BuildContext context) {
    // SiteScaffold now provides SingleChildScrollView + Scrollbar for the whole page.
    return const SiteScaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          HeroSection(
            onPrimary: null, // placeholder actions
            onSecondary: null,
          ),
          FeaturedServicesSection(),
          WhatWeDoSection(),
          WhoWeServeSection(),
          HowItWorksSection(),
          // CaseStudiesTestimonialsSection removed
          ToolingIntegrationsSection(),
          SizedBox(height: 16),
          FaqFinalCtaSection(),
          SizedBox(height: 64),
          FooterArea(),
        ],
      ),
    );
  }
}

// Custom scroll behavior to ensure all pointer device types can drag the list.
// Removed custom Home scroll behavior; SiteScaffold provides a unified behavior
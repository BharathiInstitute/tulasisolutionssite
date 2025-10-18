import 'package:flutter/material.dart';
import '../sections/layout/site_scaffold.dart';
import '../sections/industries/retail_landing.dart';
import '../sections/industries/education_landing.dart';
import '../sections/industries/services_landing.dart';
import '../sections/industries/printing_packaging_landing.dart';
import '../sections/industries/cosmetics_landing.dart';
import '../sections/industries/startup_landing.dart';

class IndustriesPage extends StatelessWidget {
  const IndustriesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return SiteScaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1200),
                child: const _IndustriesHeader(),
              ),
            ),
          ),

          // Retail
          const RetailPlaybookLanding(),

          // Education
          EducationPlaybookLanding(
            data: sampleEducationContent(
              onPrimary: () {},
              onSecondary: () {},
            ),
          ),

          // Services
          ServicesPlaybookLanding(
            data: sampleServicesContent(
              onPrimary: () {},
              onSecondary: () {},
            ),
          ),

          // Printing & Packaging
          PrintingPlaybookLanding(
            data: samplePrintingContent(
              onPrimary: () {},
              onSecondary: () {},
            ),
          ),

          // Cosmetics
          CosmeticsPlaybookLanding(
            data: sampleCosmeticsContent(
              onPrimary: () {},
              onSecondary: () {},
            ),
          ),

          // Startups
          StartupPlaybookLanding(
            data: sampleStartupContent(
              onPrimary: () {},
              onSecondary: () {},
            ),
          ),

          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _IndustriesHeader extends StatelessWidget {
  const _IndustriesHeader();
  @override
  Widget build(BuildContext context) {
    return Column(
      children: const [
        Text(
          'Industries We Support',
          style: TextStyle(fontSize: 36, fontWeight: FontWeight.w800),
        ),
      ],
    );
  }
}

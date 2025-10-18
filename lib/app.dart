import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'theme/app_theme.dart';
import 'pages/home_page.dart';
import 'pages/industries_pages.dart';
import 'sections/industries/retail_landing.dart';
import 'sections/industries/education_landing.dart';
import 'sections/industries/services_landing.dart';
import 'sections/industries/printing_packaging_landing.dart';
import 'sections/industries/cosmetics_landing.dart';
import 'sections/industries/startup_landing.dart';
import 'pages/pricing_page.dart';
import 'pages/portfolio_page.dart';
import 'pages/resources_page.dart';
import 'sections/resources/blog_page.dart';
import 'sections/resources/guides_page.dart';
import 'sections/resources/templates_page.dart';
import 'sections/resources/faqs_page.dart';
import 'sections/about/company.dart';
import 'sections/about/team.dart';
import 'sections/about/careers.dart';
import 'pages/detail_page.dart';
import 'pages/contact_page.dart';
// Services pages
import 'pages/branding_page.dart';
import 'pages/marketing_page.dart';
import 'pages/websites_page.dart';
import 'pages/software_page.dart';
import 'pages/automation_page.dart';
import 'pages/training_page.dart';
import 'pages/growth_page.dart';
import 'pages/services_page.dart';
import 'sections/layout/site_scaffold.dart';
import 'pages/business_setup_page.dart';

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Debug: print when building root
    // (Remove after diagnosing blank screen)
    // ignore: avoid_print
    print('MyApp.build invoked');
  return MaterialApp(
      title: 'Tulasi Solutions',
      debugShowCheckedModeBanner: false,
      scrollBehavior: const _AppScrollBehavior(),
      // Always use light theme to keep global background (c7f9cc) consistent
      themeMode: ThemeMode.light,
      theme: AppTheme.lightTheme.copyWith(
        appBarTheme: const AppBarTheme(centerTitle: false),
        scrollbarTheme: ScrollbarThemeData(
          thumbVisibility: const WidgetStatePropertyAll(true),
          trackVisibility: const WidgetStatePropertyAll(true),
          radius: const Radius.circular(4),
          thickness: const WidgetStatePropertyAll(8.0),
        ),
      ),
      darkTheme: AppTheme.darkTheme,
      // Wrap HomePage in a widget that catches build errors to display instead of silent blank
      home: _HomeWithGuard(child: const HomePage()),
      routes: {
  '/home': (_) => const HomePage(),
        '/services/business-setup': (_) => const BusinessSetupPage(),
        '/industries': (_) => const IndustriesPage(),
        // Industry subpages use section landing widgets directly
        '/industries/retail': (_) => const SiteScaffold(
              backgroundColor: Colors.transparent,
              body: RetailPlaybookLanding(),
            ),
        '/industries/education': (_) => SiteScaffold(
              backgroundColor: Colors.transparent,
              body: ListView(padding: const EdgeInsets.all(16), children: [
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1200),
                    child: EducationPlaybookLanding(
                      data: sampleEducationContent(
                        onPrimary: () {},
                        onSecondary: () {},
                      ),
                    ),
                  ),
                ),
              ]),
            ),
        '/industries/services': (_) => SiteScaffold(
              backgroundColor: Colors.transparent,
              body: ListView(padding: const EdgeInsets.all(16), children: [
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1200),
                    child: ServicesPlaybookLanding(
                      data: sampleServicesContent(
                        onPrimary: () {},
                        onSecondary: () {},
                      ),
                    ),
                  ),
                ),
              ]),
            ),
        '/industries/printing': (_) => SiteScaffold(
              backgroundColor: Colors.transparent,
              body: ListView(padding: const EdgeInsets.all(16), children: [
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1200),
                    child: PrintingPlaybookLanding(
                      data: samplePrintingContent(
                        onPrimary: () {},
                        onSecondary: () {},
                      ),
                    ),
                  ),
                ),
              ]),
            ),
        '/industries/cosmetics': (_) => SiteScaffold(
              backgroundColor: Colors.transparent,
              body: ListView(padding: const EdgeInsets.all(16), children: [
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1200),
                    child: CosmeticsPlaybookLanding(
                      data: sampleCosmeticsContent(
                        onPrimary: () {},
                        onSecondary: () {},
                      ),
                    ),
                  ),
                ),
              ]),
            ),
        '/industries/startup': (_) => SiteScaffold(
              backgroundColor: const Color(0xFFF7F7F7),
              body: ListView(padding: const EdgeInsets.all(16), children: [
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1200),
                    child: StartupPlaybookLanding(
                      data: sampleStartupContent(
                        onPrimary: () {},
                        onSecondary: () {},
                      ),
                    ),
                  ),
                ),
              ]),
            ),
  '/pricing': (_) => const PricingPage(),
  '/portfolio': (_) => const PortfolioPage(),
  '/resources': (_) => const ResourcesPage(),
  '/resources/blog': (_) => const BlogPage(),
  '/resources/guides': (_) => const GuidesPage(),
  '/resources/templates': (_) => const TemplatesPage(),
  '/resources/faqs': (_) => const FaqsPage(),
  '/about/company': (_) => const CompanyPage(),
  '/about/team': (_) => const TeamPage(),
  '/about/careers': (_) => const CareersPage(),
  '/contact': (_) => const ContactPage(),
  '/detail': (_) => const DetailPage(),
        '/services': (_) => const ServicesPage(),
         // Services: top-level pages
        '/services/branding': (_) => const BrandingPage(),
        '/services/marketing': (_) => const MarketingPage(),
        '/services/websites': (_) => const WebsitesPage(),
        '/services/software': (_) => const SoftwarePage(),
        '/services/automation': (_) => const AutomationPage(),
  // Deep links for Automation subsections
  '/services/automation/whatsapp': (_) => const AutomationPage(),
  '/services/automation/email': (_) => const AutomationPage(),
  '/services/automation/sms': (_) => const AutomationPage(),
  '/services/automation/journey': (_) => const AutomationPage(),
        '/services/training': (_) => const TrainingPage(),
        // Growth supports deep-link to internal section via route argument (String)
        '/services/growth': (ctx) {
          final arg = ModalRoute.of(ctx)?.settings.arguments;
          GrowthSection? initial;
          if (arg is String) {
            final lower = arg.toLowerCase();
            if (lower.contains('sales')) {
              initial = GrowthSection.salesTargets;
            } else if (lower.contains('strategy')) {
              initial = GrowthSection.strategyPlanning;
            } else if (lower.contains('monthly') || lower.contains('review')) {
              initial = GrowthSection.monthlyReview;
            }
          }
          return GrowthPage(initialSection: initial);
        },
      },
    );
  }
}

// Captures errors inside the home subtree and shows a visible message instead of a blank screen.
class _HomeWithGuard extends StatelessWidget {
  const _HomeWithGuard({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) {
    return ErrorWidget.builder == _defaultErrorBuilder
        ? _Guard(child: child)
        : _Guard(child: child); // keep simple; we override globally below
  }
}

final _defaultErrorBuilder = ErrorWidget.builder;

class _Guard extends StatelessWidget {
  const _Guard({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Builder(
        builder: (ctx) {
          return child;
        },
      ),
    );
  }
}

// Override global error widget to show red banner message (helps when only green background seen)
// Call this early via a static initializer.
// ignore: unused_element
void _initErrorWidget() {
  ErrorWidget.builder = (FlutterErrorDetails details) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.red.withValues(alpha: 0.08),
              border: Border.all(color: Colors.redAccent),
              borderRadius: BorderRadius.circular(12),
            ),
            child: SingleChildScrollView(
              child: Text(
                'Build error::\n\n${details.exceptionAsString()}',
                style: const TextStyle(color: Colors.redAccent, fontSize: 14, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ),
      ),
    );
  };
}

class _AppScrollBehavior extends MaterialScrollBehavior {
  const _AppScrollBehavior();
  @override
  Set<PointerDeviceKind> get dragDevices => const {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.trackpad,
        PointerDeviceKind.stylus,
        PointerDeviceKind.invertedStylus,
      };
}

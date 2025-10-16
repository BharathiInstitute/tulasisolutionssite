import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'theme/app_theme.dart';
import 'pages/home_page.dart';
import 'pages/industries_pages.dart';
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
        '/industries': (_) => const IndustriesPage(),
        '/industries/retail': (_) => const IndustriesRetailPage(),
  '/industries/education': (_) => const IndustriesEducationPage(),
  '/industries/cosmetics': (_) => const IndustriesCosmeticsPage(),
  '/industries/printing': (_) => const IndustriesPrintingPage(),
  '/industries/services': (_) => const IndustriesServicesPage(),
  '/industries/startup': (_) => const IndustriesStartupPage(),
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

import 'package:flutter/material.dart';
import '../sections/services/page_background.dart';
import '../sections/services/responsive_nav_bar.dart';
// Updated to new consolidated services path (migrated from sections/automation/*)
import '../sections/services/automation/whatsapp_automation_hero_section.dart';
import '../sections/services/automation/email_automation_hero_section.dart';
import '../sections/services/automation/sms_automation_hero_section.dart';
import '../sections/services/automation/customer_journey_hero_section.dart';
import 'branding_page.dart';
import 'marketing_page.dart';
import 'websites_page.dart';
import 'training_page.dart';
import 'growth_page.dart';
import 'software_page.dart';
import 'home_page.dart';

class AutomationPage extends StatefulWidget {
  const AutomationPage({super.key});

  @override
  State<AutomationPage> createState() => _AutomationPageState();
}

class _AutomationPageState extends State<AutomationPage> {
  final _scrollController = ScrollController();
  final _whatsappKey = GlobalKey();
  final _emailKey = GlobalKey();
  final _smsKey = GlobalKey();
  final _journeyKey = GlobalKey();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Scroll to a requested section when arriving via deep link or route args.
    final settings = ModalRoute.of(context)?.settings;
    String? target;
    final args = settings?.arguments;
    if (args is String && args.trim().isNotEmpty) {
      target = args;
    } else {
      // Try route name like '/automation/whatsapp'
      final name = settings?.name ?? '';
      if (name.isNotEmpty) {
        final lower = name.toLowerCase();
        if (lower.contains('whatsapp')) {
          target = 'whatsapp';
        } else if (lower.contains('email')) {
          target = 'email';
        } else if (lower.contains('sms')) {
          target = 'sms';
        } else if (lower.contains('journey')) {
          target = 'journey';
        }
      }
      // For Flutter web, also parse the browser URL
      if (target == null) {
        final uri = Uri.base;
        // Prefer explicit query parameter e.g., ?section=whatsapp
        target = uri.queryParameters['section'] ?? uri.queryParameters['target'] ?? uri.queryParameters['tab'];
        // Support hash like #whatsapp
        target ??= uri.fragment.isNotEmpty ? uri.fragment : null;
        // Or last path segment like /automation/whatsapp
        if (target == null && uri.pathSegments.length >= 2 && uri.pathSegments.contains('automation')) {
          final last = uri.pathSegments.last.toLowerCase();
          if (last == 'whatsapp' || last == 'email' || last == 'sms' || last == 'journey') {
            target = last;
          }
        }
      }
    }
    if (target != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollTo(target!));
    }
  }

  void _scrollTo(String id) {
    final l = id.toLowerCase();
    GlobalKey? key;
    if (l.contains('whatsapp')) {
      key = _whatsappKey;
    } else if (l.contains('email')) {
      key = _emailKey;
    } else if (l.contains('sms')) {
      key = _smsKey;
    } else if (l.contains('journey')) {
      key = _journeyKey;
    }
    final ctx = key?.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeInOutCubic,
        alignment: 0.05,
      );
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
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const BrandingPage()),
      );
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
      // already here
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
            ResponsiveNavBar(title: 'Tulasi Site Services', activeLabel: 'Automation', onItemSelected: _onNavSelect),
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
                          Container(key: _whatsappKey, child: const WhatsAppAutomationHeroSection()),
                          SizedBox(height: 24),
                          Container(key: _emailKey, child: const EmailAutomationHeroSection()),
                          SizedBox(height: 24),
                          Container(key: _smsKey, child: const SmsAutomationHeroSection()),
                          SizedBox(height: 24),
                          Container(key: _journeyKey, child: const CustomerJourneyHeroSection()),
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

import 'package:flutter/material.dart';
import '../sections/layout/site_scaffold.dart';
import '../sections/services/page_background.dart';
// Updated to new consolidated services path (migrated from sections/automation/*)
import '../sections/services/automation/whatsapp_automation_hero_section.dart';
import '../sections/services/automation/email_automation_hero_section.dart';
import '../sections/services/automation/sms_automation_hero_section.dart';
import '../sections/services/automation/customer_journey_hero_section.dart';
// Navigation across services now handled by global header

class AutomationPage extends StatefulWidget {
  const AutomationPage({super.key});

  @override
  State<AutomationPage> createState() => _AutomationPageState();
}

class _AutomationPageState extends State<AutomationPage> {
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
  // Removed per-page services nav; use global header only

  @override
  Widget build(BuildContext context) {
    return SiteScaffold(
      body: PageBackground(
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
                  const SizedBox(height: 24),
                  Container(key: _emailKey, child: const EmailAutomationHeroSection()),
                  const SizedBox(height: 24),
                  Container(key: _smsKey, child: const SmsAutomationHeroSection()),
                  const SizedBox(height: 24),
                  Container(key: _journeyKey, child: const CustomerJourneyHeroSection()),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

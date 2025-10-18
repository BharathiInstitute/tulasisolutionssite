import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import '../header/data/menu_data.dart';
import '../header/header_bar.dart';
import '../header/mobile_drawer.dart';

class SiteScaffold extends StatefulWidget {
  const SiteScaffold({super.key, required this.body, this.backgroundColor, this.scrollable = true});
  final Widget body;
  final Color? backgroundColor;
  // When false, do not wrap body in SingleChildScrollView/Scrollbar.
  final bool scrollable;

  @override
  State<SiteScaffold> createState() => _SiteScaffoldState();
}

class _SiteScaffoldState extends State<SiteScaffold> {
  String? _activeTitle;
  late final ScrollController _scrollController;

  void _setActive(String? v) => setState(() => _activeTitle = v);

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

  void _navigateIfNotCurrent(String route, {Object? arguments}) {
    final current = ModalRoute.of(context)?.settings.name;
    // If already on the same route:
    if (current == route) {
      // When arguments differ or are present, replace so About can re-handle deep link
      Navigator.of(context).pushReplacementNamed(route, arguments: arguments);
      return;
    }
    // Otherwise push normally
    Navigator.of(context).pushNamed(route, arguments: arguments);
  }

  void _onMenuTap(String id) {
    // Debug log for menu taps to help diagnose navigation issues
    // ignore: avoid_print
    print('Menu tapped: $id');
    _setActive(id);
    final ctx = context;
    if (id == 'Home') {
      // Always return to the first (home) route.
      Navigator.of(ctx).popUntil((route) => route.isFirst);
      return;
    } else if (id == 'Services') {
      // Default to first services page
      _navigateIfNotCurrent('/services/branding');
      return;
    } else if (id == 'Industries') {
      _navigateIfNotCurrent('/industries');
    } else if (id == 'Retail') {
      _navigateIfNotCurrent('/industries/retail');
    } else if (id == 'Education') {
      _navigateIfNotCurrent('/industries/education');
    } else if (id == 'Cosmetics') {
      _navigateIfNotCurrent('/industries/cosmetics');
    } else if (id == 'Printing & Packaging') {
      _navigateIfNotCurrent('/industries/printing');
    } else if (id == 'Services (Industry)') {
      _navigateIfNotCurrent('/industries/services');
    } else if (id == 'Startup') {
      _navigateIfNotCurrent('/industries/startup');
    } else if (id == 'Pricing' || id == 'View Pricing') {
      // Pricing page removed; redirect to Contact instead
      _navigateIfNotCurrent('/contact');
    } else if (id == 'Portfolio' || id == 'View Portfolio') {
      _navigateIfNotCurrent('/portfolio');
    } else if (id == 'Resources' || id == 'Blog' || id == 'Guides' || id == 'Templates' || id == 'FAQs') {
      // Resources and its subsections removed; route to Home
      _navigateIfNotCurrent('/home');
    } else if (id == 'About') {
      // About landing page exists; go to About directory
      _navigateIfNotCurrent('/about');
    } else if (id == 'Company') {
      _navigateIfNotCurrent('/about');
    } else if (id == 'Team') {
      _navigateIfNotCurrent('/about');
    } else if (id == 'Tools & Partners') {
      _navigateIfNotCurrent('/about');
    } else if (id == 'Careers') {
      _navigateIfNotCurrent('/about');
    } else if (id == 'Contact') {
      _navigateIfNotCurrent('/contact');
    } else if (id == 'Form') {
      _navigateIfNotCurrent('/contact', arguments: 'form');
    } else if (id == 'WhatsApp') {
      _navigateIfNotCurrent('/contact', arguments: 'whatsapp');
    } else if (id == 'Phone') {
      _navigateIfNotCurrent('/contact', arguments: 'phone');
    } else if (id == 'Business Setup') {
      _navigateIfNotCurrent('/services/business-setup');
    } else if (id == 'Business Category / Track') {
      _navigateIfNotCurrent('/services/business-setup', arguments: 'category');
    } else if (id == 'Business Manager / In-Charge') {
      _navigateIfNotCurrent('/services/business-setup', arguments: 'manager');
    } else if (id == 'Business Pitch / USP') {
      _navigateIfNotCurrent('/services/business-setup', arguments: 'pitch');
    } else if (id == 'Business Onboarding') {
      _navigateIfNotCurrent('/services/business-setup', arguments: 'onboarding');
    } else if (id == 'Business Analysis') {
      _navigateIfNotCurrent('/services/business-setup', arguments: 'analysis');
    } else if (id == 'Pain Points Identification') {
      _navigateIfNotCurrent('/services/business-setup', arguments: 'pain');
    } else if (id == 'Goal Setting') {
      _navigateIfNotCurrent('/services/business-setup', arguments: 'goal');
    } else if (id == 'Branding') {
      _navigateIfNotCurrent('/services/branding');
    } else if (id == 'Logo Design') {
      _navigateIfNotCurrent('/services/branding', arguments: 'logo');
    } else if (id == 'Business Cards') {
      _navigateIfNotCurrent('/services/branding', arguments: 'cards');
    } else if (id == 'Brochures') {
      _navigateIfNotCurrent('/services/branding', arguments: 'brochure');
    } else if (id == 'Social Media Templates') {
      _navigateIfNotCurrent('/services/branding', arguments: 'social');
    } else if (id == 'Marketing') {
      _navigateIfNotCurrent('/services/marketing');
    } else if (id == 'Pamphlets') {
      _navigateIfNotCurrent('/services/marketing', arguments: 'pamphlet');
    } else if (id == 'Hoardings') {
      _navigateIfNotCurrent('/services/marketing', arguments: 'hoardings');
    } else if (id == 'Reels') {
      _navigateIfNotCurrent('/services/marketing', arguments: 'reels');
    } else if (id == 'Promotional Videos') {
      _navigateIfNotCurrent('/services/marketing', arguments: 'videos');
    } else if (id == 'Google My Business (GMB)') {
      _navigateIfNotCurrent('/services/marketing', arguments: 'gmb');
    } else if (id == 'FB / Insta / YouTube / X / LinkedIn') {
      _navigateIfNotCurrent('/services/marketing', arguments: 'channels');
    } else if (id == 'WhatsApp Marketing') {
      _navigateIfNotCurrent('/services/marketing', arguments: 'whatsapp');
    } else if (id == 'Google Ads') {
      _navigateIfNotCurrent('/services/marketing', arguments: 'ads');
    } else if (id == 'Websites') {
      _navigateIfNotCurrent('/services/websites');
    } else if (id == 'Main Website') {
      _navigateIfNotCurrent('/services/websites', arguments: 'main');
    } else if (id == 'Landing Pages') {
      _navigateIfNotCurrent('/services/websites', arguments: 'landing');
    } else if (id == 'Forms & Lead Capture') {
      _navigateIfNotCurrent('/services/websites', arguments: 'forms');
    } else if (id == 'Software') {
      _navigateIfNotCurrent('/services/software');
    } else if (id == 'CRM Setup') {
      _navigateIfNotCurrent('/services/software', arguments: 'crm');
    } else if (id == 'HR Management') {
      _navigateIfNotCurrent('/services/software', arguments: 'hr');
    } else if (id == 'Accounts Management') {
      _navigateIfNotCurrent('/services/software', arguments: 'accounts');
    } else if (id == 'Inventory System') {
      _navigateIfNotCurrent('/services/software', arguments: 'inventory');
    } else if (id == 'Customer Service Tools') {
      _navigateIfNotCurrent('/services/software', arguments: 'customer');
    } else if (id == 'Automation') {
      _navigateIfNotCurrent('/services/automation');
    } else if (id == 'WhatsApp Automation') {
      _navigateIfNotCurrent('/services/automation', arguments: 'whatsapp');
    } else if (id == 'Email') {
      _navigateIfNotCurrent('/services/automation', arguments: 'email');
    } else if (id == 'SMS') {
      _navigateIfNotCurrent('/services/automation', arguments: 'sms');
    } else if (id == 'Customer Journey Setup') {
      _navigateIfNotCurrent('/services/automation', arguments: 'journey');
    } else if (id == 'Training') {
      _navigateIfNotCurrent('/services/training');
    } else if (id == 'CRM Usage') {
      _navigateIfNotCurrent('/services/training', arguments: 'crm');
    } else if (id == 'Lead Management') {
      _navigateIfNotCurrent('/services/training', arguments: 'lead');
    } else if (id == 'Follow-up Process') {
      _navigateIfNotCurrent('/services/training', arguments: 'follow-up');
    } else if (id == 'Deal Closings') {
      _navigateIfNotCurrent('/services/training', arguments: 'deal');
    } else if (id == 'Growth') {
      _navigateIfNotCurrent('/services/growth');
    } else if (id == 'Sales Target Setting' || id == 'Sales Targets') {
      _navigateIfNotCurrent('/services/growth', arguments: 'sales');
    } else if (id == 'Strategy Planning') {
      _navigateIfNotCurrent('/services/growth', arguments: 'strategy');
    } else if (id == 'Monthly Review') {
      _navigateIfNotCurrent('/services/growth', arguments: 'monthly review');
    } else {
      _navigateIfNotCurrent('/detail', arguments: id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final bg = Theme.of(context).scaffoldBackgroundColor;
    return Scaffold(
      backgroundColor: widget.backgroundColor ?? bg,
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(width > 1200 ? 76 : 64),
        child: HeaderBar(
          onMenuTap: _onMenuTap,
          activeTitle: _activeTitle,
          onActiveChange: _setActive,
        ),
      ),
      drawer: width <= 1200
          ? MobileDrawer(
              menuData: menuData,
              onMenuTap: (t) {
                // Ensure drawer is closed before performing navigation to avoid
                // context/route conflicts on some platforms.
                Navigator.of(context).maybePop().then((_) {
                  _onMenuTap(t);
                  _setActive(t);
                });
              },
              activeTitle: _activeTitle,
            )
          : null,
      body: widget.scrollable
          ? ScrollConfiguration(
              behavior: const _SiteScrollBehavior(),
              child: PrimaryScrollController(
                controller: _scrollController,
                child: Scrollbar(
                  controller: _scrollController,
                  thumbVisibility: true,
                  trackVisibility: true,
                  interactive: true,
                  radius: const Radius.circular(6),
                  child: SingleChildScrollView(
                    controller: _scrollController,
                    physics: const ClampingScrollPhysics(),
                    child: widget.body,
                  ),
                ),
              ),
            )
          : widget.body,
    );
  }
}

// Ensure smooth drag scrolling across devices at the site level
class _SiteScrollBehavior extends MaterialScrollBehavior {
  const _SiteScrollBehavior();
  @override
  Set<PointerDeviceKind> get dragDevices => const {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.trackpad,
        PointerDeviceKind.stylus,
        PointerDeviceKind.invertedStylus,
      };
}

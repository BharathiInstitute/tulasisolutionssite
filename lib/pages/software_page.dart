import 'package:flutter/material.dart';
import 'branding_page.dart';
import 'marketing_page.dart';
import 'websites_page.dart';
import 'automation_page.dart';
import 'training_page.dart';
import 'growth_page.dart';
// crm_setup_hero_section removed
import '../sections/services/page_background.dart';
import '../sections/services/responsive_nav_bar.dart';
import '../sections/services/software/hr_management_hero_section.dart';
import '../sections/services/software/inventory_system_hero_section.dart';
import '../sections/services/software/customer_service_tools_hero_section.dart';
import 'home_page.dart';

class SoftwarePage extends StatefulWidget {
  const SoftwarePage({super.key});

  @override
  State<SoftwarePage> createState() => _SoftwarePageState();
}

class _SoftwarePageState extends State<SoftwarePage> {
  final _scrollController = ScrollController();
  final _crmKey = GlobalKey();
  final _hrKey = GlobalKey();
  final _accountsKey = GlobalKey();
  final _inventoryKey = GlobalKey();
  final _customerKey = GlobalKey();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final arg = ModalRoute.of(context)?.settings.arguments;
    if (arg is String) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollTo(arg));
    }
  }

  void _scrollTo(String id) {
    final l = id.toLowerCase();
    GlobalKey? key;
    if (l.contains('crm')) {
      key = _crmKey;
    } else if (l.contains('hr')) {
      key = _hrKey;
    } else if (l.contains('account')) {
      key = _accountsKey;
    } else if (l.contains('inventory')) {
      key = _inventoryKey;
    } else if (l.contains('customer')) {
      key = _customerKey;
    }
    final ctx = key?.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(ctx, duration: const Duration(milliseconds: 400), curve: Curves.easeInOutCubic, alignment: 0.05);
    }
  }
  void _onNavSelect(int index, String label) {
    if (label == 'Business Setup' || index == 0) {
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => const HomePage()));
      return;
    }
    if (label == 'Branding' || index == 1) {
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => const BrandingPage()));
      return;
    }
    if (label == 'Marketing' || index == 2) {
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => const MarketingPage()));
      return;
    }
    if (label == 'Websites' || index == 3) {
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => const WebsitesPage()));
      return;
    }
    if (label == 'Software' || index == 4) {
      // already here
      return;
    }
    if (label == 'Automation' || index == 5) {
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AutomationPage()));
      return;
    }
    if (label == 'Training' || index == 6) {
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => const TrainingPage()));
      return;
    }
    if (label == 'Growth' || index == 7) {
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => const GrowthPage()));
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
            ResponsiveNavBar(title: 'Tulasi Site Services', activeLabel: 'Software', onItemSelected: _onNavSelect),
            Expanded(
              child: SingleChildScrollView(
                controller: _scrollController,
                child: DefaultTextStyle.merge(
                  style: const TextStyle(color: Colors.white),
                  child: IconTheme(
                    data: const IconThemeData(color: Colors.white70),
                      child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // CrmSetupHeroSection removed. See software folder for remaining sections.
                        SizedBox(height: 6),
                        Container(key: _hrKey, child: HrManagementHeroSection()),
                        SizedBox(height: 24),
                        // AccountsManagementHeroSection removed
                        SizedBox(height: 12),
                        Container(key: _inventoryKey, child: InventorySystemHeroSection()),
                        SizedBox(height: 24),
                        Container(key: _customerKey, child: CustomerServiceToolsHeroSection()),
                      ],
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

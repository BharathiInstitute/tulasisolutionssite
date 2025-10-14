import 'package:flutter/material.dart';
import 'home_page.dart';
import 'branding_page.dart';
import 'marketing_page.dart';
import 'websites_page.dart';
import 'software_page.dart';
import 'automation_page.dart';
import 'training_page.dart';
import '../sections/services/responsive_nav_bar.dart';
import '../sections/services/page_background.dart';
import '../sections/services/growth/sales_target_setting_section.dart';
import '../sections/services/growth/strategy_planning_section.dart';
import '../sections/services/growth/monthly_review_section.dart';

/// Enum representing internal sections for deep linking / scroll.
enum GrowthSection { salesTargets, strategyPlanning, monthlyReview }

/// GrowthPage with internal quick links and deep-link scrolling to sections.
class GrowthPage extends StatefulWidget {
  const GrowthPage({super.key, this.initialSection});
  final GrowthSection? initialSection;

  @override
  State<GrowthPage> createState() => _GrowthPageState();
}

class _GrowthPageState extends State<GrowthPage> {
  final _scrollController = ScrollController();
  final _salesKey = GlobalKey();
  final _strategyKey = GlobalKey();
  final _monthlyKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    if (widget.initialSection != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollTo(widget.initialSection!));
    }
  }

  void _onNavSelect(BuildContext context, int index, String label) {
    Widget? page;
    switch (label) {
      case 'Business Setup':
        page = const HomePage();
        break;
      case 'Branding':
        page = const BrandingPage();
        break;
      case 'Marketing':
        page = const MarketingPage();
        break;
      case 'Websites':
        page = const WebsitesPage();
        break;
      case 'Software':
        page = const SoftwarePage();
        break;
      case 'Automation':
        page = const AutomationPage();
        break;
      case 'Training':
        page = const TrainingPage();
        break;
      case 'Growth':
      default:
        return; // already here
    }
    Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => page!));
  }

  void _scrollTo(GrowthSection section) {
    final key = switch (section) {
      GrowthSection.salesTargets => _salesKey,
      GrowthSection.strategyPlanning => _strategyKey,
      GrowthSection.monthlyReview => _monthlyKey,
    };
    final ctx = key.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOutCubic,
        alignment: 0.05,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            ResponsiveNavBar(title: 'Tulasi Site Services', activeLabel: 'Growth', onItemSelected: (i, l) => _onNavSelect(context, i, l)),
            // In-page quick links
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Wrap(
                spacing: 12,
                runSpacing: 8,
                children: [
                  _SectionLink(label: 'Sales Targets', onTap: () => _scrollTo(GrowthSection.salesTargets)),
                  _SectionLink(label: 'Strategy Planning', onTap: () => _scrollTo(GrowthSection.strategyPlanning)),
                  _SectionLink(label: 'Monthly Review', onTap: () => _scrollTo(GrowthSection.monthlyReview)),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: PageBackground(
                child: Scrollbar(
                  controller: _scrollController,
                  thumbVisibility: true,
                  trackVisibility: true,
                  interactive: true,
                  child: SingleChildScrollView(
                    controller: _scrollController,
                    padding: const EdgeInsets.only(bottom: 48),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: 12),
                        // Sections with keys for deep links
                        Container(key: _salesKey, child: SalesTargetSettingSection()),
                        const SizedBox(height: 32),
                        Container(key: _strategyKey, child: StrategyPlanningSection()),
                        const SizedBox(height: 32),
                        Container(key: _monthlyKey, child: MonthlyReviewSection()),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionLink extends StatelessWidget {
  const _SectionLink({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
      ),
      onPressed: onTap,
      child: Text(label),
    );
  }
}

import 'package:flutter/material.dart';

import '../responsive_nav_bar.dart';
import '../../pages/branding_page.dart';
import '../../pages/marketing_page.dart';
import '../../pages/websites_page.dart';
import '../../pages/automation_page.dart';
import '../../pages/software_page.dart';
import '../../pages/training_page.dart';
import '../../pages/growth_page.dart';
import '../../pages/home_page.dart';

/// HomeHeader
/// Extracted header (navigation bar) logic from HomePage for cleaner structure.
/// Handles navigation to top-level pages.
class HomeHeader extends StatelessWidget {
  const HomeHeader({super.key});

  void _onNavSelect(BuildContext context, int index, String label) {
    // Normalize label logic to index mapping to avoid mismatch.
    // Use pushReplacement for top-level navigation to avoid deep stack buildup
    switch (label) {
      case 'Business Setup':
        if (index != 0) {
          Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const HomePage()));
        }
        break;
      case 'Branding':
        Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const BrandingPage()));
        break;
      case 'Marketing':
        Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const MarketingPage()));
        break;
      case 'Websites':
        Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const WebsitesPage()));
        break;
      case 'Software':
        Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const SoftwarePage()));
        break;
      case 'Automation':
        Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const AutomationPage()));
        break;
      case 'Training':
        Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const TrainingPage()));
        break;
      case 'Growth':
        // Ensure Growth menu always routes to GrowthPage
        Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const GrowthPage()));
        break;
      default:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return ResponsiveNavBar(
      title: 'Tulasi Site Services',
      onItemSelected: (i, label) => _onNavSelect(context, i, label),
    );
  }
}

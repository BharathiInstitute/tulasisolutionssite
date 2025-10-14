import 'package:flutter/material.dart';
import 'branding_page.dart';
import 'marketing_page.dart';
import 'websites_page.dart';
import 'software_page.dart';
import 'automation_page.dart';
import 'growth_page.dart';
import 'home_page.dart';
// Updated imports to point directly to implementation files in training/ subfolder.
import '../sections/services/page_background.dart';
import '../sections/services/responsive_nav_bar.dart';
// Import canonical training section implementations from services directory.
import 'package:tulasisolutionssite/sections/services/training/crm_training_section_impl.dart';
import 'package:tulasisolutionssite/sections/services/training/lead_management_section_impl.dart';
import 'package:tulasisolutionssite/sections/services/training/follow_up_process_section_impl.dart';
import 'package:tulasisolutionssite/sections/services/training/deal_closings_section_impl.dart';

/// Enum for internal Training sections (for quick navigation / deep link style scroll).
enum TrainingSection { crm, lead, followUp, deal }

class TrainingPage extends StatefulWidget {
  const TrainingPage({super.key});

  @override
  State<TrainingPage> createState() => _TrainingPageState();
}

class _TrainingPageState extends State<TrainingPage> {
  final ScrollController _scrollController = ScrollController();
  // Keys for internal section scroll targets
  final _crmKey = GlobalKey();
  final _leadKey = GlobalKey();
  final _followKey = GlobalKey();
  final _dealKey = GlobalKey();
  String? _lastDeepLinkArg; // prevents repeated scroll triggering that can cause jank

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onNavSelect(int index, String label) {
    if (label == 'Business Setup' || index == 0) {
  Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const HomePage()));
      return;
    }
    if (label == 'Branding' || index == 1) {
  Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const BrandingPage()));
      return;
    }
    if (label == 'Marketing' || index == 2) {
  Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const MarketingPage()));
      return;
    }
    if (label == 'Websites' || index == 3) {
  Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const WebsitesPage()));
      return;
    }
    if (label == 'Software' || index == 4) {
  Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const SoftwarePage()));
      return;
    }
    if (label == 'Automation' || index == 5) {
  Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const AutomationPage()));
      return;
    }
    if (label == 'Training' || index == 6) {
      // already here
      return;
    }
    if (label == 'Growth' || index == 7) {
  Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const GrowthPage()));
      return;
    }
  }

  void _scrollTo(TrainingSection section) {
    final key = switch (section) {
      TrainingSection.crm => _crmKey,
      TrainingSection.lead => _leadKey,
      TrainingSection.followUp => _followKey,
      TrainingSection.deal => _dealKey,
    };
    final ctx = key.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(ctx, duration: const Duration(milliseconds: 400), curve: Curves.easeInOutCubic, alignment: 0.05);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Handle deep link only when the argument changes to avoid continuous post-frame scroll scheduling.
    final arg = ModalRoute.of(context)?.settings.arguments;
    if (arg is String && arg != _lastDeepLinkArg) {
      _lastDeepLinkArg = arg;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final l = arg.toLowerCase();
        if (l.contains('crm')) {
          _scrollTo(TrainingSection.crm);
        } else if (l.contains('lead')) {
          _scrollTo(TrainingSection.lead);
        } else if (l.contains('follow')) {
          _scrollTo(TrainingSection.followUp);
        } else if (l.contains('deal')) {
          _scrollTo(TrainingSection.deal);
        }
      });
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
              ResponsiveNavBar(title: 'Tulasi Site Services', activeLabel: 'Training', onItemSelected: _onNavSelect),
              // Quick in-page links
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    _SectionLink(label: 'CRM Foundations', onTap: () => _scrollTo(TrainingSection.crm)),
                    _SectionLink(label: 'Lead Management', onTap: () => _scrollTo(TrainingSection.lead)),
                    _SectionLink(label: 'Follow-Up Process', onTap: () => _scrollTo(TrainingSection.followUp)),
                    _SectionLink(label: 'Deal Closings', onTap: () => _scrollTo(TrainingSection.deal)),
                  ],
                ),
              ),
              const Divider(height: 1),
                Expanded(
                  // Always-visible internal scrollbar for Training content
                  child: RawScrollbar(
                    controller: _scrollController,
                    thumbVisibility: true, // Always show for clarity
                    trackVisibility: true, // Show track so user notices scrollbar is added
                    interactive: true,
                    thickness: 10,
                    radius: const Radius.circular(8),
                    thumbColor: const Color(0xFF64748B),
                    trackColor: const Color(0xFFCBD5E1),
                    trackBorderColor: const Color(0xFF94A3B8),
                    child: SingleChildScrollView(
                    controller: _scrollController,
                    padding: const EdgeInsets.only(bottom: 48),
                    child: DefaultTextStyle.merge(
                      style: const TextStyle(color: Colors.white),
                      child: IconTheme(
                        data: const IconThemeData(color: Colors.white70),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // Sections with keys
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                                child: Text('CRM Foundations', style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: Colors.white)),
                              ),
                              const SizedBox(height: 12),
                              Container(
                                key: _crmKey,
                                child: CrmTrainingSection(
                                  onBookDemoTap: () {
                                    showDialog(
                                      context: context,
                                      builder: (context) => AlertDialog(
                                        title: const Text('Book a Demo'),
                                        content: const Text('Thanks for your interest! A booking form will be added here.'),
                                        actions: [
                                          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Close')),
                                        ],
                                      ),
                                    );
                                  },
                                  onSeeSampleTap: () {
                                    showDialog(
                                      context: context,
                                      builder: (context) => AlertDialog(
                                        title: const Text('Training Sample'),
                                        content: const Text('A sample training preview will appear here.'),
                                        actions: [
                                          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Close')),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                              ),
                              const SizedBox(height: 40),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                                child: Text('Lead Management', style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: Colors.white)),
                              ),
                              const SizedBox(height: 12),
                              Container(key: _leadKey, child: const LeadManagementSection()),
                              const SizedBox(height: 32),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                                child: Text('Follow-Up Process', style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: Colors.white)),
                              ),
                              const SizedBox(height: 12),
                              Container(key: _followKey, child: const FollowUpProcessSection()),
                              const SizedBox(height: 40),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                                child: Text('Deal Closings', style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: Colors.white)),
                              ),
                              const SizedBox(height: 12),
                              Container(key: _dealKey, child: const DealClosingsSection()),
                            ],
                          ),
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

import 'package:flutter/material.dart';
import '../sections/layout/site_scaffold.dart';
import '../sections/services/page_background.dart';
// Business Setup sections
import '../sections/services/business_setup/business_category_section.dart';
import '../sections/services/business_setup/business_manager_section.dart';
import '../sections/services/business_setup/business_pitch_section.dart';
import '../sections/services/business_setup/business_onboarding_section.dart';
import '../sections/services/business_setup/business_analysis_section.dart';
import '../sections/services/business_setup/pain_points_section.dart';
import '../sections/services/business_setup/goal_setting_section.dart';

class BusinessSetupPage extends StatefulWidget {
  const BusinessSetupPage({super.key});

  @override
  State<BusinessSetupPage> createState() => _BusinessSetupPageState();
}

class _BusinessSetupPageState extends State<BusinessSetupPage> {
  final _categoryKey = GlobalKey();
  final _managerKey = GlobalKey();
  final _pitchKey = GlobalKey();
  final _onboardingKey = GlobalKey();
  final _analysisKey = GlobalKey();
  final _painPointsKey = GlobalKey();
  final _goalSettingKey = GlobalKey();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final arg = ModalRoute.of(context)?.settings.arguments;
    if (arg is String) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollTo(arg));
    }
  }

  void _scrollTo(String id) {
    final lower = id.toLowerCase();
    GlobalKey? key;
    if (lower.contains('category') || lower.contains('track')) {
      key = _categoryKey;
    } else if (lower.contains('manager') || lower.contains('in-charge') || lower.contains('incharge')) {
      key = _managerKey;
    } else if (lower.contains('pitch') || lower.contains('usp')) {
      key = _pitchKey;
    } else if (lower.contains('onboarding')) {
      key = _onboardingKey;
    } else if (lower.contains('analysis') || lower.contains('audit')) {
      key = _analysisKey;
    } else if (lower.contains('pain')) {
      key = _painPointsKey;
    } else if (lower.contains('goal')) {
      key = _goalSettingKey;
    }
    final ctx = key?.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeInOutCubic,
        alignment: 0.06,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return SiteScaffold(
      body: PageBackground(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Order: Category, Manager, Pitch, Onboarding, Analysis, Pain Points, Goal Setting
              Container(key: _categoryKey, child: const BusinessCategorySection()),
              const SizedBox(height: 24),
              Container(key: _managerKey, child: const BusinessManagerSection()),
              const SizedBox(height: 24),
              Container(key: _pitchKey, child: const BusinessPitchSection()),
              const SizedBox(height: 24),
              Container(key: _onboardingKey, child: const BusinessOnboardingSection()),
              const SizedBox(height: 24),
              Container(key: _analysisKey, child: const BusinessAnalysisSection()),
              const SizedBox(height: 24),
              Container(key: _painPointsKey, child: const PainPointsSection()),
              const SizedBox(height: 24),
              Container(key: _goalSettingKey, child: const GoalSettingSection()),
            ],
          ),
        ),
      ),
    );
  }
}

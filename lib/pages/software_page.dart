import 'package:flutter/material.dart';
import '../sections/layout/site_scaffold.dart';
// crm_setup_hero_section removed
import '../sections/services/page_background.dart';
import '../sections/services/software/hr_management_hero_section.dart';
import '../sections/services/software/inventory_system_hero_section.dart';
import '../sections/services/software/customer_service_tools_hero_section.dart';
// Navigation handled by global header; no per-page imports needed

class SoftwarePage extends StatefulWidget {
  const SoftwarePage({super.key});

  @override
  State<SoftwarePage> createState() => _SoftwarePageState();
}

class _SoftwarePageState extends State<SoftwarePage> {
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
  // Removed per-page services nav; using global header only

  @override
  Widget build(BuildContext context) {
    return SiteScaffold(
      body: PageBackground(
        child: DefaultTextStyle.merge(
          style: const TextStyle(color: Colors.white),
          child: IconTheme(
            data: const IconThemeData(color: Colors.white70),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 6),
                Container(key: _hrKey, child: HrManagementHeroSection()),
                const SizedBox(height: 24),
                // AccountsManagementHeroSection removed
                const SizedBox(height: 12),
                Container(key: _inventoryKey, child: InventorySystemHeroSection()),
                const SizedBox(height: 24),
                Container(key: _customerKey, child: CustomerServiceToolsHeroSection()),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tulasisolutionssite/core/models/models.dart';
import 'package:tulasisolutionssite/core/providers/providers.dart';
import 'package:tulasisolutionssite/core/constants/enums.dart';
import 'package:tulasisolutionssite/core/widgets/shared_widgets.dart';

class SoftwareStageScreen extends ConsumerStatefulWidget {
  final String clientId;

  const SoftwareStageScreen({super.key, required this.clientId});

  @override
  ConsumerState<SoftwareStageScreen> createState() =>
      _SoftwareStageScreenState();
}

class _SoftwareStageScreenState extends ConsumerState<SoftwareStageScreen> {
  @override
  Widget build(BuildContext context) {
    final softwareStageAsync = ref.watch(
      softwareStageProvider(widget.clientId),
    );

    return softwareStageAsync.when(
      data: (softwareStage) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Software Delivery Stage',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              if (softwareStage == null)
                Center(
                  child: Column(
                    children: [
                      const Icon(Icons.laptop, size: 64, color: Colors.grey),
                      const SizedBox(height: 16),
                      const Text('No software stage configured yet'),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () {},
                        child: const Text('Setup Software'),
                      ),
                    ],
                  ),
                )
              else
                _buildSoftwareStageContent(context, softwareStage),
            ],
          ),
        );
      },
      loading: () => const LoadingWidget(),
      error: (error, stackTrace) =>
          CustomErrorWidget(message: 'Error loading software stage: $error'),
    );
  }

  Widget _buildSoftwareStageContent(
    BuildContext context,
    SoftwareStageData softwareStage,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Current Stage',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    ElevatedButton.icon(
                      onPressed: () => _showStageSelector(context),
                      icon: const Icon(Icons.edit),
                      label: const Text('Change'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                StageChip(label: softwareStage.stage.displayName),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'Panels Configuration',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _buildPanelToggle(
                  'Billing Panel',
                  'billing',
                  softwareStage.panelsEnabled.contains('billing'),
                ),
                const Divider(),
                _buildPanelToggle(
                  'CRM Panel',
                  'crm',
                  softwareStage.panelsEnabled.contains('crm'),
                ),
                const Divider(),
                _buildPanelToggle(
                  'Inventory Panel',
                  'inventory',
                  softwareStage.panelsEnabled.contains('inventory'),
                ),
                const Divider(),
                _buildPanelToggle(
                  'Payments Panel',
                  'payments',
                  softwareStage.panelsEnabled.contains('payments'),
                ),
                const Divider(),
                _buildPanelToggle(
                  'Staff Panel',
                  'staff',
                  softwareStage.panelsEnabled.contains('staff'),
                ),
                const Divider(),
                _buildPanelToggle(
                  'Reports Panel',
                  'reports',
                  softwareStage.panelsEnabled.contains('reports'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        Text('Free Period', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Free Period Status',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 12),
                if (softwareStage.freePeriodStart != null) ...[
                  ListTile(
                    title: const Text('Start Date'),
                    subtitle: Text(
                      softwareStage.freePeriodStart.toString().split(' ')[0],
                    ),
                    trailing: ElevatedButton(
                      onPressed: () {},
                      child: const Text('Change'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ListTile(
                    title: const Text('End Date'),
                    subtitle: Text(
                      softwareStage.freePeriodEnd.toString().split(' ')[0],
                    ),
                    trailing: Chip(
                      label: Text(
                        '${softwareStage.freePeriodEnd?.difference(DateTime.now()).inDays ?? 0} days left',
                      ),
                    ),
                  ),
                ] else
                  ListTile(
                    title: const Text('Free Period'),
                    subtitle: const Text('Not set'),
                    trailing: ElevatedButton(
                      onPressed: () {},
                      child: const Text('Set'),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'Customization Level',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  softwareStage.customizationLevel,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: () {},
                  child: const Text('Change Customization Level'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPanelToggle(String label, String panelKey, bool isEnabled) {
    return CheckboxListTile(
      value: isEnabled,
      onChanged: (value) {
        // Update panel state
      },
      title: Text(label),
      controlAffinity: ListTileControlAffinity.leading,
    );
  }

  void _showStageSelector(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Software Stage'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView(
            shrinkWrap: true,
            children: SoftwareStage.values
                .map(
                  (stage) => ListTile(
                    title: Text(stage.displayName),
                    onTap: () {
                      Navigator.pop(context);
                      // Update stage
                    },
                  ),
                )
                .toList(),
          ),
        ),
      ),
    );
  }
}

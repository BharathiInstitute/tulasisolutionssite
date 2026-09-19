import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'package:tulasisolutionssite/core/constants/enums.dart';
import 'package:tulasisolutionssite/core/models/models.dart';
import 'package:tulasisolutionssite/core/providers/providers.dart';
import 'package:tulasisolutionssite/core/widgets/app_drawer.dart';
import 'package:tulasisolutionssite/core/widgets/feature_progress_widgets.dart';
import 'package:tulasisolutionssite/core/widgets/shared_widgets.dart';

/// A single editable feature row: an optional category + the feature text.
class _FeatureFieldControllers {
  final TextEditingController category;
  final TextEditingController text;

  _FeatureFieldControllers({String category = '', String text = ''})
    : category = TextEditingController(text: category),
      text = TextEditingController(text: text);

  factory _FeatureFieldControllers.fromRaw(String raw) {
    final separatorIndex = raw.indexOf(': ');
    final category = separatorIndex > 0 ? raw.substring(0, separatorIndex) : '';
    final text = separatorIndex > 0 ? raw.substring(separatorIndex + 2) : raw;
    return _FeatureFieldControllers(category: category, text: text);
  }

  void dispose() {
    category.dispose();
    text.dispose();
  }
}

/// Editable list of feature rows (category + text), used by both the
/// Template dialog and the Assign Plan dialog.
class _FeatureListEditor extends StatelessWidget {
  final List<_FeatureFieldControllers> controllers;
  final PlanType planType;
  final VoidCallback onAdd;
  final void Function(int index) onRemove;
  final String addLabel;

  const _FeatureListEditor({
    required this.controllers,
    required this.planType,
    required this.onAdd,
    required this.onRemove,
    this.addLabel = 'Add feature',
  });

  @override
  Widget build(BuildContext context) {
    final categories = planType == PlanType.subscription
        ? subscriptionPlanFeatureCategories
        : setupPlanFeatureCategories;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Features', style: Theme.of(context).textTheme.titleSmall),
            TextButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add, size: 18),
              label: Text(addLabel),
            ),
          ],
        ),
        ...List.generate(controllers.length, (index) {
          final row = controllers[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 2,
                  child: DropdownButtonFormField<String>(
                    initialValue: categories.contains(row.category.text)
                        ? row.category.text
                        : null,
                    decoration: const InputDecoration(labelText: 'Category'),
                    hint: const Text('Select category'),
                    items: categories
                        .map(
                          (category) => DropdownMenuItem(
                            value: category,
                            child: Text(category),
                          ),
                        )
                        .toList(),
                    onChanged: (category) {
                      row.category.text = category ?? '';
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: row.text,
                    decoration: InputDecoration(
                      hintText: 'e.g. 6 photos + 6 short videos',
                      labelText: 'Feature ${index + 1}',
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: controllers.length > 1
                      ? () => onRemove(index)
                      : null,
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
}

/// Plans panel with two tabs:
/// - Templates: reusable master pricing plans (name, price, feature list)
///   that apply to every client, fully editable/creatable.
/// - Client Plans: assign a template (or a fully custom plan) to a specific
///   client, with the price/features customizable per client.
class PlansScreen extends ConsumerWidget {
  const PlansScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 2,
      child: AppShell(
        isAdmin: true,
        currentRoute: '/admin/plans',
        title: 'Plans',
        bottom: const TabBar(
          tabs: [
            Tab(text: 'Templates'),
            Tab(text: 'Client Plans'),
          ],
        ),
        body: const TabBarView(children: [_TemplatesTab(), _ClientPlansTab()]),
      ),
    );
  }
}

// ============================== TEMPLATES TAB ==============================

class _TemplatesTab extends ConsumerWidget {
  const _TemplatesTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final templatesAsync = ref.watch(planTemplatesProvider);

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'add-template',
        onPressed: () => showDialog(
          context: context,
          builder: (context) => const _PlanTemplateDialog(),
        ),
        icon: const Icon(Icons.add),
        label: const Text('New Template'),
      ),
      body: templatesAsync.when(
        data: (templates) {
          if (templates.isEmpty) {
            return const Center(
              child: Text('No plan templates yet — create your first one'),
            );
          }
          final setupTemplates = templates
              .where((t) => t.type == PlanType.setup)
              .toList();
          final subscriptionTemplates = templates
              .where((t) => t.type == PlanType.subscription)
              .toList();

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _CategoryExpansion(
                icon: Icons.build_circle_outlined,
                title: 'Setup Plans',
                subtitle: 'One-time plans — pay once, we build it',
                count: setupTemplates.length,
                children: setupTemplates.isEmpty
                    ? [
                        const _EmptyCategoryCard(
                          label: 'No setup templates yet',
                        ),
                      ]
                    : setupTemplates
                          .map((t) => _TemplateCard(template: t, ref: ref))
                          .toList(),
              ),
              const SizedBox(height: 16),
              _CategoryExpansion(
                icon: Icons.autorenew,
                title: 'Subscription Plans',
                subtitle: 'Ongoing monthly plans — ongoing growth support',
                count: subscriptionTemplates.length,
                children: subscriptionTemplates.isEmpty
                    ? [
                        const _EmptyCategoryCard(
                          label: 'No subscription templates yet',
                        ),
                      ]
                    : subscriptionTemplates
                          .map((t) => _TemplateCard(template: t, ref: ref))
                          .toList(),
              ),
            ],
          );
        },
        loading: () => const LoadingWidget(),
        error: (error, stackTrace) =>
            CustomErrorWidget(message: 'Error loading templates: $error'),
      ),
    );
  }
}

/// Collapsible category section — a card whose header expands/collapses to
/// reveal the templates or client plans within that category.
class _CategoryExpansion extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final int count;
  final List<Widget> children;

  const _CategoryExpansion({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.count,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        initiallyExpanded: true,
        leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
        title: Text(title, style: Theme.of(context).textTheme.titleMedium),
        subtitle: Text(subtitle),
        trailing: Chip(label: Text('$count')),
        childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        children: [
          for (final child in children) ...[child, const SizedBox(height: 8)],
        ],
      ),
    );
  }
}

class _EmptyCategoryCard extends StatelessWidget {
  final String label;

  const _EmptyCategoryCard({required this.label});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
      ),
    );
  }
}

class _TemplateCard extends StatelessWidget {
  final PlanTemplate template;
  final WidgetRef ref;

  const _TemplateCard({required this.template, required this.ref});

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        leading: Icon(
          template.type == PlanType.subscription
              ? Icons.autorenew
              : Icons.build_circle_outlined,
        ),
        title: Text(template.name),
        subtitle: Text(
          template.price == 0
              ? 'Custom'
              : '₹${template.price.toStringAsFixed(0)}',
        ),
        trailing: Text('${template.features.length} features'),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        children: [
          GroupedFeatureList(
            features: template.features,
            categoryOrder: template.type == PlanType.subscription
                ? subscriptionPlanFeatureCategories
                : setupPlanFeatureCategories,
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton.icon(
                onPressed: () => showDialog(
                  context: context,
                  builder: (context) => _PlanTemplateDialog(existing: template),
                ),
                icon: const Icon(Icons.edit_outlined),
                label: const Text('Edit'),
              ),
              TextButton.icon(
                onPressed: () => _confirmDelete(context),
                icon: const Icon(Icons.delete_outline, color: Colors.red),
                label: const Text(
                  'Delete',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete template?'),
        content: Text(
          'Existing client plans created from "${template.name}" are not affected.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.read(firestoreServiceProvider).deletePlanTemplate(template.id);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }
}

class _PlanTemplateDialog extends ConsumerStatefulWidget {
  final PlanTemplate? existing;

  const _PlanTemplateDialog({this.existing});

  @override
  ConsumerState<_PlanTemplateDialog> createState() =>
      _PlanTemplateDialogState();
}

class _PlanTemplateDialogState extends ConsumerState<_PlanTemplateDialog> {
  final _nameController = TextEditingController();
  final _priceController = TextEditingController();
  late PlanType _type;
  late List<_FeatureFieldControllers> _featureRows;
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _nameController.text = widget.existing?.name ?? '';
    _priceController.text = widget.existing?.price.toStringAsFixed(0) ?? '';
    _type = widget.existing?.type ?? PlanType.setup;
    _featureRows = (widget.existing?.features ?? const [''])
        .map((f) => _FeatureFieldControllers.fromRaw(f))
        .toList();
    if (_featureRows.isEmpty) {
      _featureRows.add(_FeatureFieldControllers());
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    for (final row in _featureRows) {
      row.dispose();
    }
    super.dispose();
  }

  void _addFeatureField() {
    setState(
      () => _featureRows.add(
        _FeatureFieldControllers(
          category: _type == PlanType.subscription
              ? visionAndPlanFeatureCategory
              : '',
        ),
      ),
    );
  }

  void _removeFeatureField(int index) {
    setState(() {
      _featureRows[index].dispose();
      _featureRows.removeAt(index);
    });
  }

  Future<void> _save() async {
    final price = double.tryParse(_priceController.text.trim());
    if (_nameController.text.trim().isEmpty || price == null) {
      setState(() => _error = 'Enter a name and a valid price');
      return;
    }
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final features = _featureRows
          .where((row) => row.text.text.trim().isNotEmpty)
          .map((row) => encodeFeature(row.category.text, row.text.text))
          .toList();
      final template = PlanTemplate(
        id: widget.existing?.id ?? const Uuid().v4(),
        type: _type,
        name: _nameController.text.trim(),
        price: price,
        features: features,
        createdDate: widget.existing?.createdDate ?? DateTime.now(),
      );
      final service = ref.read(firestoreServiceProvider);
      if (widget.existing != null) {
        await service.updatePlanTemplate(template);
      } else {
        await service.createPlanTemplate(template);
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) setState(() => _error = 'Error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.existing != null ? 'Edit Template' : 'New Template'),
      content: SizedBox(
        width: 440,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Plan name (e.g. Starter, Growth)',
                ),
              ),
              const SizedBox(height: 16),
              Text('Category', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              SegmentedButton<PlanType>(
                segments: const [
                  ButtonSegment(
                    value: PlanType.setup,
                    label: Text('Setup'),
                    icon: Icon(Icons.build_circle_outlined),
                  ),
                  ButtonSegment(
                    value: PlanType.subscription,
                    label: Text('Subscription'),
                    icon: Icon(Icons.autorenew),
                  ),
                ],
                selected: {_type},
                onSelectionChanged: (selection) =>
                    setState(() => _type = selection.first),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _priceController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Price (₹)',
                  prefixText: '₹ ',
                ),
              ),
              const SizedBox(height: 16),
              _FeatureListEditor(
                controllers: _featureRows,
                planType: _type,
                onAdd: _addFeatureField,
                onRemove: _removeFeatureField,
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(_error!, style: const TextStyle(color: Colors.red)),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _save,
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Save'),
        ),
      ],
    );
  }
}

// ============================== CLIENT PLANS TAB ==============================

class _ClientPlansTab extends ConsumerWidget {
  const _ClientPlansTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plansAsync = ref.watch(allPlansProvider);
    final clientsAsync = ref.watch(clientsListProvider);
    final templatesAsync = ref.watch(planTemplatesProvider);

    return Scaffold(
      floatingActionButton: clientsAsync.maybeWhen(
        data: (clients) => templatesAsync.maybeWhen(
          data: (templates) => FloatingActionButton.extended(
            heroTag: 'assign-plan',
            onPressed: clients.isEmpty
                ? null
                : () => _showAssignDialog(context, clients, templates),
            icon: const Icon(Icons.add),
            label: const Text('Assign Plan'),
          ),
          orElse: () => null,
        ),
        orElse: () => null,
      ),
      body: plansAsync.when(
        data: (plans) {
          if (plans.isEmpty) {
            return const Center(child: Text('No plans assigned yet'));
          }
          return clientsAsync.when(
            data: (clients) {
              final clientNames = {for (final c in clients) c.id: c.name};
              return templatesAsync.when(
                data: (templates) {
                  final setupPlans = plans
                      .where((p) => p.type == PlanType.setup)
                      .toList();
                  final subscriptionPlans = plans
                      .where((p) => p.type == PlanType.subscription)
                      .toList();

                  return ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _CategoryExpansion(
                        icon: Icons.build_circle_outlined,
                        title: 'Setup Plans',
                        subtitle: 'Clients on a one-time setup plan',
                        count: setupPlans.length,
                        children: setupPlans.isEmpty
                            ? [
                                const _EmptyCategoryCard(
                                  label: 'No setup plans assigned yet',
                                ),
                              ]
                            : setupPlans
                                  .map(
                                    (plan) => _ClientPlanTile(
                                      plan: plan,
                                      clientName:
                                          clientNames[plan.clientId] ??
                                          'Unknown client',
                                      onTap: () => _showAssignDialog(
                                        context,
                                        clients,
                                        templates,
                                        existing: plan,
                                      ),
                                      onDelete: () => _confirmDeletePlan(
                                        context,
                                        ref,
                                        plan,
                                      ),
                                    ),
                                  )
                                  .toList(),
                      ),
                      const SizedBox(height: 16),
                      _CategoryExpansion(
                        icon: Icons.autorenew,
                        title: 'Subscription Plans',
                        subtitle: 'Clients on an ongoing monthly plan',
                        count: subscriptionPlans.length,
                        children: subscriptionPlans.isEmpty
                            ? [
                                const _EmptyCategoryCard(
                                  label: 'No subscription plans assigned yet',
                                ),
                              ]
                            : subscriptionPlans
                                  .map(
                                    (plan) => _ClientPlanTile(
                                      plan: plan,
                                      clientName:
                                          clientNames[plan.clientId] ??
                                          'Unknown client',
                                      onTap: () => _showAssignDialog(
                                        context,
                                        clients,
                                        templates,
                                        existing: plan,
                                      ),
                                      onDelete: () => _confirmDeletePlan(
                                        context,
                                        ref,
                                        plan,
                                      ),
                                    ),
                                  )
                                  .toList(),
                      ),
                    ],
                  );
                },
                loading: () => const LoadingWidget(),
                error: (error, stackTrace) => CustomErrorWidget(
                  message: 'Error loading templates: $error',
                ),
              );
            },
            loading: () => const LoadingWidget(),
            error: (error, stackTrace) =>
                CustomErrorWidget(message: 'Error loading clients: $error'),
          );
        },
        loading: () => const LoadingWidget(),
        error: (error, stackTrace) =>
            CustomErrorWidget(message: 'Error loading plans: $error'),
      ),
    );
  }

  void _showAssignDialog(
    BuildContext context,
    List<Client> clients,
    List<PlanTemplate> templates, {
    Plan? existing,
  }) {
    showDialog(
      context: context,
      builder: (context) => AssignPlanDialog(
        clients: clients,
        templates: templates,
        existing: existing,
      ),
    );
  }

  Future<void> _confirmDeletePlan(
    BuildContext context,
    WidgetRef ref,
    Plan plan,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete plan?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.read(firestoreServiceProvider).deletePlan(plan.id);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }
}

class _ClientPlanTile extends ConsumerWidget {
  final Plan plan;
  final String clientName;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _ClientPlanTile({
    required this.plan,
    required this.clientName,
    required this.onTap,
    required this.onDelete,
  });

  Future<void> _toggleFeature(
    WidgetRef ref,
    String rawFeature,
    bool done,
  ) async {
    final updatedCompleted = List<String>.from(plan.completedFeatures);
    if (done) {
      if (!updatedCompleted.contains(rawFeature)) {
        updatedCompleted.add(rawFeature);
      }
    } else {
      updatedCompleted.remove(rawFeature);
    }
    await ref
        .read(firestoreServiceProvider)
        .updatePlan(plan.copyWith(completedFeatures: updatedCompleted));
  }

  Future<void> _updateFeatureProgress(
    WidgetRef ref,
    String rawFeature,
    int percent,
  ) async {
    final updatedProgress = Map<String, int>.from(plan.featureProgress);
    updatedProgress[rawFeature] = percent;
    final updatedCompleted = List<String>.from(plan.completedFeatures);
    if (percent >= 100) {
      if (!updatedCompleted.contains(rawFeature)) {
        updatedCompleted.add(rawFeature);
      }
    } else {
      updatedCompleted.remove(rawFeature);
    }
    await ref
        .read(firestoreServiceProvider)
        .updatePlan(
          plan.copyWith(
            featureProgress: updatedProgress,
            completedFeatures: updatedCompleted,
          ),
        );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isExpired =
        plan.endDate != null && plan.endDate!.isBefore(DateTime.now());
    final progressPercent = (plan.progress * 100).round();
    return Card(
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        leading: Icon(
          plan.type == PlanType.subscription
              ? Icons.autorenew
              : Icons.build_circle_outlined,
        ),
        title: Text('$clientName — ${plan.name}'),
        subtitle: Text(
          plan.price == 0 ? 'Custom' : '₹${plan.price.toStringAsFixed(0)}',
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (plan.isCompleted)
              const Chip(
                label: Text('Completed'),
                backgroundColor: Color(0x1A2E7D32),
                labelStyle: TextStyle(
                  color: Colors.green,
                  fontWeight: FontWeight.w700,
                ),
              )
            else
              Chip(label: Text('$progressPercent% done')),
            const SizedBox(width: 8),
            Chip(
              label: Text(isExpired ? 'Expired' : 'Active'),
              backgroundColor: isExpired
                  ? Colors.red.withValues(alpha: 0.15)
                  : Colors.green.withValues(alpha: 0.15),
              labelStyle: TextStyle(
                color: isExpired ? Colors.red : Colors.green,
              ),
            ),
          ],
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Starts ${DateFormat('MMM d, y').format(plan.startDate)}'
              '${plan.endDate != null ? ' • Ends ${DateFormat('MMM d, y').format(plan.endDate!)}' : ''}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: plan.progress,
              minHeight: 8,
              backgroundColor: Colors.grey.withValues(alpha: 0.2),
              valueColor: AlwaysStoppedAnimation<Color>(
                plan.isCompleted ? Colors.green : Colors.orange,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${plan.completedFeatures.length} / ${plan.features.length} features completed'
            '${plan.isCompleted ? ' — Plan Completed' : ''}',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: plan.isCompleted ? Colors.green : null,
              fontWeight: plan.isCompleted ? FontWeight.w700 : null,
            ),
          ),
          const SizedBox(height: 8),
          TrackableFeatureList(
            features: plan.features,
            completedFeatures: plan.completedFeatures,
            featureProgress: plan.featureProgress,
            categoryOrder: plan.type == PlanType.subscription
                ? subscriptionPlanFeatureCategories
                : setupPlanFeatureCategories,
            onToggle: (raw, done) => _toggleFeature(ref, raw, done),
            onProgressChange: (raw, percent) =>
                _updateFeatureProgress(ref, raw, percent),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton.icon(
                onPressed: onTap,
                icon: const Icon(Icons.edit_outlined),
                label: const Text('Change Plan'),
              ),
              TextButton.icon(
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline, color: Colors.red),
                label: const Text(
                  'Delete',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class AssignPlanDialog extends ConsumerStatefulWidget {
  final List<Client> clients;
  final List<PlanTemplate> templates;
  final Plan? existing;

  const AssignPlanDialog({
    super.key,
    required this.clients,
    required this.templates,
    this.existing,
  });

  @override
  ConsumerState<AssignPlanDialog> createState() => _AssignPlanDialogState();
}

class _AssignPlanDialogState extends ConsumerState<AssignPlanDialog> {
  late String _clientId;
  String? _templateId;
  late PlanType _type;
  final _nameController = TextEditingController();
  final _priceController = TextEditingController();
  late List<_FeatureFieldControllers> _featureRows;
  late List<ClientTask> _tasks;
  late DateTime _startDate;
  DateTime? _endDate;
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _clientId = widget.existing?.clientId ?? widget.clients.first.id;
    _templateId = widget.existing?.templateId;
    _type = widget.existing?.type ?? PlanType.setup;
    _nameController.text = widget.existing?.name ?? '';
    _priceController.text = widget.existing?.price.toStringAsFixed(0) ?? '';
    _featureRows = (widget.existing?.features ?? const [''])
        .map((f) => _FeatureFieldControllers.fromRaw(f))
        .toList();
    _tasks = List<ClientTask>.from(widget.existing?.tasks ?? const []);
    if (_featureRows.isEmpty) {
      _featureRows.add(_FeatureFieldControllers());
    }
    _startDate = widget.existing?.startDate ?? DateTime.now();
    _endDate = widget.existing?.endDate;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    for (final row in _featureRows) {
      row.dispose();
    }
    super.dispose();
  }

  void _applyTemplate(String? templateId) {
    setState(() {
      _templateId = templateId;
      if (templateId == null) return;
      final template = widget.templates.firstWhere((t) => t.id == templateId);
      _type = template.type;
      _nameController.text = template.name;
      _priceController.text = template.price.toStringAsFixed(0);
      for (final row in _featureRows) {
        row.dispose();
      }
      if (widget.existing != null) {
        final merged = widget.existing!.mergeTemplateTasks(template);
        _tasks = merged.tasks;
        _featureRows = merged.features
            .map((feature) => _FeatureFieldControllers.fromRaw(feature))
            .toList();
      } else {
        _tasks = template.tasks.map(ClientTask.fromTemplate).toList();
        _featureRows = template.features
            .map((f) => _FeatureFieldControllers.fromRaw(f))
            .toList();
      }
      if (_featureRows.isEmpty) {
        _featureRows.add(_FeatureFieldControllers());
      }
    });
  }

  void _addFeatureField() {
    setState(
      () => _featureRows.add(
        _FeatureFieldControllers(
          category: _type == PlanType.subscription
              ? visionAndPlanFeatureCategory
              : '',
        ),
      ),
    );
  }

  void _removeFeatureField(int index) {
    setState(() {
      _featureRows[index].dispose();
      _featureRows.removeAt(index);
    });
  }

  Future<void> _pickDate({required bool isStart}) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isStart ? _startDate : (_endDate ?? _startDate),
      firstDate: DateTime.now().subtract(const Duration(days: 365 * 2)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
    );
    if (picked == null) return;
    setState(() {
      if (isStart) {
        _startDate = picked;
      } else {
        _endDate = picked;
      }
    });
  }

  Future<void> _save() async {
    final price = double.tryParse(_priceController.text.trim());
    if (_nameController.text.trim().isEmpty || price == null) {
      setState(() => _error = 'Enter a plan name and a valid price');
      return;
    }
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final features = _featureRows
          .where((row) => row.text.text.trim().isNotEmpty)
          .map((row) => encodeFeature(row.category.text, row.text.text))
          .toList();
      final tasksByFeature = {for (final task in _tasks) task.feature: task};
      final tasks = <ClientTask>[
        for (var index = 0; index < features.length; index++)
          tasksByFeature[features[index]] ??
              ClientTask(
                id: const Uuid().v4(),
                category: _featureRows[index].category.text.trim(),
                title: _featureRows[index].text.text.trim(),
                order: index,
                source: _templateId == null
                    ? ClientTaskSource.customIncluded
                    : ClientTaskSource.template,
              ),
      ];
      final plan = Plan(
        id: widget.existing?.id ?? const Uuid().v4(),
        clientId: _clientId,
        templateId: _templateId,
        type: _type,
        name: _nameController.text.trim(),
        price: price,
        features: features,
        tasks: tasks,
        completedFeatures: widget.existing?.completedFeatures ?? const [],
        featureProgress: widget.existing?.featureProgress ?? const {},
        taskWorkflow: widget.existing?.taskWorkflow ?? const {},
        startDate: _startDate,
        endDate: _endDate,
      );
      final service = ref.read(firestoreServiceProvider);
      if (widget.existing != null) {
        await service.updatePlan(plan);
      } else {
        await service.createPlan(plan);
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) setState(() => _error = 'Error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.existing != null ? 'Change Plan' : 'Assign Plan'),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DropdownButtonFormField<String>(
                initialValue: _clientId,
                items: widget.clients
                    .map(
                      (c) => DropdownMenuItem(value: c.id, child: Text(c.name)),
                    )
                    .toList(),
                onChanged: (value) =>
                    setState(() => _clientId = value ?? _clientId),
                decoration: const InputDecoration(labelText: 'Client'),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String?>(
                initialValue: _templateId,
                items: [
                  const DropdownMenuItem(
                    value: null,
                    child: Text('Custom (no template)'),
                  ),
                  ...widget.templates
                      .where((t) => t.type == PlanType.setup)
                      .map(
                        (t) => DropdownMenuItem(
                          value: t.id,
                          child: Text(
                            '[Setup] ${t.name} — ₹${t.price.toStringAsFixed(0)}',
                          ),
                        ),
                      ),
                  ...widget.templates
                      .where((t) => t.type == PlanType.subscription)
                      .map(
                        (t) => DropdownMenuItem(
                          value: t.id,
                          child: Text(
                            '[Subscription] ${t.name} — ₹${t.price.toStringAsFixed(0)}',
                          ),
                        ),
                      ),
                ],
                onChanged: _applyTemplate,
                decoration: InputDecoration(
                  labelText: widget.existing != null
                      ? 'Change to template'
                      : 'From template',
                  helperText: widget.existing != null
                      ? 'Existing task titles are preserved; new items are added.'
                      : null,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Plan name'),
              ),
              const SizedBox(height: 16),
              Text('Category', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              SegmentedButton<PlanType>(
                segments: const [
                  ButtonSegment(
                    value: PlanType.setup,
                    label: Text('Setup'),
                    icon: Icon(Icons.build_circle_outlined),
                  ),
                  ButtonSegment(
                    value: PlanType.subscription,
                    label: Text('Subscription'),
                    icon: Icon(Icons.autorenew),
                  ),
                ],
                selected: {_type},
                onSelectionChanged: (selection) =>
                    setState(() => _type = selection.first),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _priceController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Price (₹) — customizable for this client',
                  prefixText: '₹ ',
                ),
              ),
              const SizedBox(height: 16),
              _FeatureListEditor(
                controllers: _featureRows,
                planType: _type,
                onAdd: _addFeatureField,
                onRemove: _removeFeatureField,
                addLabel: 'Add',
              ),
              const SizedBox(height: 8),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  'Start: ${DateFormat('MMM d, y').format(_startDate)}',
                ),
                trailing: const Icon(Icons.calendar_today),
                onTap: () => _pickDate(isStart: true),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  _endDate == null
                      ? 'End: none'
                      : 'End: ${DateFormat('MMM d, y').format(_endDate!)}',
                ),
                trailing: Wrap(
                  spacing: 4,
                  children: [
                    if (_endDate != null)
                      IconButton(
                        tooltip: 'Clear end date',
                        icon: const Icon(Icons.clear),
                        onPressed: () => setState(() => _endDate = null),
                      ),
                    const Icon(Icons.calendar_today),
                  ],
                ),
                onTap: () => _pickDate(isStart: false),
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(_error!, style: const TextStyle(color: Colors.red)),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _save,
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Save'),
        ),
      ],
    );
  }
}

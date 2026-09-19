import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:tulasisolutionssite/core/models/models.dart';
import 'package:tulasisolutionssite/core/providers/providers.dart';
import 'package:tulasisolutionssite/core/constants/enums.dart';
import 'package:tulasisolutionssite/core/widgets/app_drawer.dart';
import 'package:tulasisolutionssite/core/widgets/feature_progress_widgets.dart';
import 'package:tulasisolutionssite/core/widgets/shared_widgets.dart';
import 'package:tulasisolutionssite/features/admin/goals/add_edit_goal_screen.dart';
import 'package:tulasisolutionssite/features/admin/plans/plans_screen.dart';

class ClientProfileScreen extends ConsumerStatefulWidget {
  final String clientId;

  const ClientProfileScreen({super.key, required this.clientId});

  @override
  ConsumerState<ClientProfileScreen> createState() =>
      _ClientProfileScreenState();
}

class _ClientProfileScreenState extends ConsumerState<ClientProfileScreen> {
  late TextEditingController _notesController;
  String? _notesLoadedForClientId;

  @override
  void initState() {
    super.initState();
    _notesController = TextEditingController();
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final clientAsync = ref.watch(clientProvider(widget.clientId));
    final goalsAsync = ref.watch(goalsProvider(widget.clientId));
    final plansAsync = ref.watch(plansProvider(widget.clientId));
    final templatesAsync = ref.watch(planTemplatesProvider);

    return AppShell(
      isAdmin: true,
      currentRoute: '/admin/leads',
      title: clientAsync.valueOrNull?.name ?? 'Client Profile',
      actions: [
        if (clientAsync.valueOrNull != null)
          IconButton(
            tooltip: 'Client details',
            onPressed: () => _showClientDetailsSideView(
              context,
              ref,
              clientAsync.valueOrNull!,
            ),
            icon: const Icon(Icons.info_outline),
          ),
      ],
      body: clientAsync.when(
        data: (client) {
          if (client == null) {
            return const Center(child: Text('Client not found'));
          }

          if (_notesLoadedForClientId != client.id) {
            _notesController.text = client.notes ?? '';
            _notesLoadedForClientId = client.id;
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildOverviewSection(context, ref, client),
              const SizedBox(height: 12),
              _buildPlanSection(context, ref, plansAsync, templatesAsync),
              const SizedBox(height: 12),
              _buildGoalsSection(context, goalsAsync),
              const SizedBox(height: 12),
              _buildNotesSection(context, ref, client),
            ],
          );
        },
        loading: () => const LoadingWidget(),
        error: (error, stackTrace) =>
            CustomErrorWidget(message: 'Error loading client: $error'),
      ),
    );
  }

  Widget _buildOverviewSection(
    BuildContext context,
    WidgetRef ref,
    Client client,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.green.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 26,
            backgroundColor: Colors.green.withValues(alpha: 0.12),
            child: const Icon(Icons.storefront_outlined, color: Colors.green),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  client.name,
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (client.category.isNotEmpty)
                      Chip(label: Text(client.category)),
                    StageChip(label: client.stage.displayName),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'View client details',
            onPressed: () => _showClientDetailsSideView(context, ref, client),
            icon: const Icon(Icons.info_outline_rounded),
          ),
        ],
      ),
    );
  }

  void _showClientDetailsSideView(
    BuildContext context,
    WidgetRef ref,
    Client client,
  ) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Client details',
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (dialogContext, animation, secondaryAnimation) {
        return ClientDetailsSideSheet(client: client, ref: ref);
      },
    );
  }

  Widget _buildPlanSection(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<List<Plan>> plansAsync,
    AsyncValue<List<PlanTemplate>> templatesAsync,
  ) {
    return _CollapsibleSection(
      icon: Icons.receipt_long_outlined,
      title: 'Plan & Progress',
      child: plansAsync.when(
        data: (plans) {
          final planButtons = templatesAsync.maybeWhen(
            data: (templates) => Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => _showAssignPlanDialog(context, ref, templates),
                icon: const Icon(Icons.add_circle_outline),
                label: const Text('Assign plan'),
              ),
            ),
            orElse: () => const SizedBox.shrink(),
          );

          if (plans.isEmpty) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Text('No plan assigned yet.'),
                ),
                const SizedBox(height: 8),
                planButtons,
              ],
            );
          }

          return Column(
            children: [
              for (final plan in plans) ...[
                _ClientPlanProgressCard(plan: plan),
                const SizedBox(height: 12),
              ],
              planButtons,
            ],
          );
        },
        loading: () => const LoadingWidget(),
        error: (error, stackTrace) =>
            CustomErrorWidget(message: 'Error loading plan: $error'),
      ),
    );
  }

  void _showAssignPlanDialog(
    BuildContext context,
    WidgetRef ref,
    List<PlanTemplate> templates,
  ) {
    final client = ref.read(clientProvider(widget.clientId)).valueOrNull;
    if (client == null) return;

    showDialog(
      context: context,
      builder: (dialogContext) =>
          AssignPlanDialog(clients: [client], templates: templates),
    );
  }

  Widget _buildGoalsSection(
    BuildContext context,
    AsyncValue<List<Goal>> goalsAsync,
  ) {
    return _CollapsibleSection(
      icon: Icons.flag_outlined,
      title: 'Goals',
      child: goalsAsync.when(
        data: (goals) {
          return Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        _showAddGoalDialog(context);
                      },
                      icon: const Icon(Icons.add),
                      label: const Text('Add Goal'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        context.push(
                          '/admin/leads/${widget.clientId}/goals/add',
                        );
                      },
                      icon: const Icon(Icons.open_in_new),
                      label: const Text('Full Goals Management'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (goals.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Text('No goals set yet'),
                )
              else
                Column(children: goals.map((g) => GoalCard(goal: g)).toList()),
            ],
          );
        },
        loading: () => const LoadingWidget(),
        error: (error, stackTrace) =>
            CustomErrorWidget(message: 'Error loading goals'),
      ),
    );
  }

  void _showAddGoalDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        builder: (context, scrollController) =>
            AddEditGoalScreen(clientId: widget.clientId),
      ),
    );
  }

  Widget _buildNotesSection(
    BuildContext context,
    WidgetRef ref,
    Client client,
  ) {
    return _CollapsibleSection(
      icon: Icons.notes_outlined,
      title: 'Notes',
      child: Column(
        children: [
          TextField(
            controller: _notesController,
            maxLines: 5,
            decoration: InputDecoration(
              hintText: 'Add notes about this client...',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () async {
                final messenger = ScaffoldMessenger.of(context);
                final updatedClient = client.copyWith(
                  notes: _notesController.text,
                );
                await ref
                    .read(firestoreServiceProvider)
                    .updateClient(updatedClient);
                if (mounted) {
                  messenger.showSnackBar(
                    const SnackBar(content: Text('Notes updated')),
                  );
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              child: const Text('Save Notes'),
            ),
          ),
        ],
      ),
    );
  }
}

class ClientDetailsSideSheet extends StatefulWidget {
  final Client client;
  final WidgetRef ref;

  const ClientDetailsSideSheet({
    super.key,
    required this.client,
    required this.ref,
  });

  @override
  State<ClientDetailsSideSheet> createState() => _ClientDetailsSideSheetState();
}

class _ClientDetailsSideSheetState extends State<ClientDetailsSideSheet> {
  late final TextEditingController _nameController;
  late final TextEditingController _ownerController;
  late final TextEditingController _categoryController;
  late final TextEditingController _emailController;
  late final TextEditingController _phoneController;
  late final TextEditingController _alternatePhoneController;
  late final TextEditingController _managerController;
  late final TextEditingController _notesController;
  late final TextEditingController _followUpNotesController;
  late ClientStage _stage;
  String? _selectedStaffName;
  DateTime? _followUpAt;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.client.name);
    _ownerController = TextEditingController(
      text: widget.client.ownerName ?? '',
    );
    _categoryController = TextEditingController(text: widget.client.category);
    _emailController = TextEditingController(text: widget.client.contactEmail);
    _phoneController = TextEditingController(text: widget.client.contactPhone);
    _alternatePhoneController = TextEditingController(
      text: widget.client.alternatePhone ?? '',
    );
    _managerController = TextEditingController(
      text: widget.client.assignedManager ?? '',
    );
    _notesController = TextEditingController(text: widget.client.notes ?? '');
    _followUpNotesController = TextEditingController(
      text: widget.client.followUpNotes ?? '',
    );
    _stage =
        widget.client.stage == ClientStage.reach ||
            widget.client.stage == ClientStage.register
        ? ClientStage.click
        : widget.client.stage;
    _selectedStaffName = widget.client.assignedManager;
    _followUpAt = widget.client.followUpAt;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _ownerController.dispose();
    _categoryController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _alternatePhoneController.dispose();
    _managerController.dispose();
    _notesController.dispose();
    _followUpNotesController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final managerName = (_selectedStaffName ?? _managerController.text).trim();

    final updatedClient = widget.client.copyWith(
      name: _nameController.text.trim(),
      ownerName: _ownerController.text.trim().isEmpty
          ? null
          : _ownerController.text.trim(),
      clearOwnerName: _ownerController.text.trim().isEmpty,
      category: _categoryController.text.trim(),
      contactEmail: _emailController.text.trim().toLowerCase(),
      contactPhone: _phoneController.text.trim(),
      alternatePhone: _alternatePhoneController.text.trim().isEmpty
          ? null
          : _alternatePhoneController.text.trim(),
      clearAlternatePhone: _alternatePhoneController.text.trim().isEmpty,
      assignedManager: managerName.isEmpty ? null : managerName,
      stage: _stage,
      updatedDate: DateTime.now(),
      notes: _notesController.text.trim(),
      followUpAt: _followUpAt,
      followUpNotes: _followUpNotesController.text.trim().isEmpty
          ? null
          : _followUpNotesController.text.trim(),
      clearFollowUp: _followUpAt == null,
    );

    await widget.ref.read(firestoreServiceProvider).updateClient(updatedClient);

    if (!mounted) return;
    navigator.pop();
    messenger.showSnackBar(
      const SnackBar(content: Text('Client details updated')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final staffUsersAsync = widget.ref.watch(allUsersProvider);

    return SafeArea(
      child: Align(
        alignment: Alignment.centerRight,
        child: Material(
          color: Theme.of(context).colorScheme.surface,
          child: Container(
            width: 420,
            height: double.infinity,
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Client details',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    TextButton(onPressed: _save, child: const Text('Save')),
                  ],
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        TextFormField(
                          controller: _nameController,
                          decoration: const InputDecoration(
                            labelText: 'Business name',
                            prefixIcon: Icon(Icons.storefront_outlined),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _ownerController,
                          decoration: const InputDecoration(
                            labelText: 'Owner name',
                            prefixIcon: Icon(Icons.person_outline),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _categoryController,
                          decoration: const InputDecoration(
                            labelText: 'Category',
                            prefixIcon: Icon(Icons.category_outlined),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          decoration: const InputDecoration(
                            labelText: 'Email',
                            prefixIcon: Icon(Icons.email_outlined),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
                          decoration: const InputDecoration(
                            labelText: 'Phone',
                            prefixIcon: Icon(Icons.phone_outlined),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _alternatePhoneController,
                          keyboardType: TextInputType.phone,
                          decoration: const InputDecoration(
                            labelText: 'Alternate phone',
                            prefixIcon: Icon(Icons.phone_android_outlined),
                          ),
                        ),
                        const SizedBox(height: 16),
                        staffUsersAsync.when(
                          data: (users) {
                            final staffOptions = users
                                .where((user) => !user.isAdmin)
                                .map(
                                  (user) => user.name.isNotEmpty
                                      ? user.name
                                      : user.email,
                                )
                                .toList();

                            final selectedValue =
                                _selectedStaffName ??
                                (_managerController.text.trim().isNotEmpty
                                    ? _managerController.text.trim()
                                    : null);

                            if (staffOptions.isEmpty) {
                              return TextFormField(
                                controller: _managerController,
                                decoration: const InputDecoration(
                                  labelText: 'Assigned staff',
                                  prefixIcon: Icon(
                                    Icons.support_agent_outlined,
                                  ),
                                ),
                              );
                            }

                            return DropdownButtonFormField<String>(
                              initialValue: staffOptions.contains(selectedValue)
                                  ? selectedValue
                                  : null,
                              decoration: const InputDecoration(
                                labelText: 'Assigned staff',
                                prefixIcon: Icon(Icons.support_agent_outlined),
                              ),
                              items: staffOptions
                                  .map(
                                    (staffName) => DropdownMenuItem(
                                      value: staffName,
                                      child: Text(staffName),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (value) {
                                if (value != null) {
                                  setState(() {
                                    _selectedStaffName = value;
                                    _managerController.text = value;
                                  });
                                }
                              },
                            );
                          },
                          loading: () => const LinearProgressIndicator(),
                          error: (error, stackTrace) => const SizedBox.shrink(),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _notesController,
                          minLines: 3,
                          maxLines: 6,
                          decoration: const InputDecoration(
                            labelText: 'Notes',
                            alignLabelWithHint: true,
                            prefixIcon: Icon(Icons.notes_outlined),
                          ),
                        ),
                        const SizedBox(height: 16),
                        _EditFollowUpFields(
                          followUpAt: _followUpAt,
                          notesController: _followUpNotesController,
                          onDateChanged: (date) =>
                              setState(() => _followUpAt = date),
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<ClientStage>(
                          initialValue: _stage,
                          decoration: const InputDecoration(
                            labelText: 'Lifecycle stage',
                            prefixIcon: Icon(Icons.timeline_outlined),
                          ),
                          items: ClientStage.values
                              .where(
                                (item) =>
                                    item != ClientStage.reach &&
                                    item != ClientStage.register,
                              )
                              .map(
                                (item) => DropdownMenuItem(
                                  value: item,
                                  child: Text(item.displayName),
                                ),
                              )
                              .toList(),
                          onChanged: (value) {
                            if (value != null) {
                              setState(() => _stage = value);
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EditFollowUpFields extends StatelessWidget {
  final DateTime? followUpAt;
  final TextEditingController notesController;
  final ValueChanged<DateTime?> onDateChanged;

  const _EditFollowUpFields({
    required this.followUpAt,
    required this.notesController,
    required this.onDateChanged,
  });

  Future<void> _pickDateTime(BuildContext context) async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(now.year, now.month + 2, now.day),
      initialDate: followUpAt ?? now,
    );
    if (date == null || !context.mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: followUpAt != null
          ? TimeOfDay.fromDateTime(followUpAt!)
          : TimeOfDay.now(),
    );
    if (time == null) return;
    onDateChanged(
      DateTime(date.year, date.month, date.day, time.hour, time.minute),
    );
  }

  @override
  Widget build(BuildContext context) {
    final label = followUpAt == null
        ? 'Set follow-up date and time'
        : 'Follow-up: ${followUpAt!.day}/${followUpAt!.month}/${followUpAt!.year} '
              '${followUpAt!.hour.toString().padLeft(2, '0')}:${followUpAt!.minute.toString().padLeft(2, '0')}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.alarm_add_outlined),
          title: Text(label),
          subtitle: const Text('Choose a day this week or month'),
          trailing: followUpAt == null
              ? const Icon(Icons.calendar_month_outlined)
              : IconButton(
                  tooltip: 'Clear follow-up',
                  onPressed: () => onDateChanged(null),
                  icon: const Icon(Icons.clear),
                ),
          onTap: () => _pickDateTime(context),
        ),
        Wrap(
          spacing: 8,
          children: [
            _quickDateButton(context, 'Today', DateTime.now()),
            _quickDateButton(
              context,
              'This week',
              DateTime.now().add(const Duration(days: 7)),
            ),
            _quickDateButton(
              context,
              'This month',
              DateTime.now().add(const Duration(days: 30)),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          controller: notesController,
          maxLines: 2,
          decoration: const InputDecoration(
            labelText: 'Follow-up notes',
            hintText: 'What should be discussed?',
            prefixIcon: Icon(Icons.sticky_note_2_outlined),
          ),
        ),
      ],
    );
  }

  Widget _quickDateButton(BuildContext context, String label, DateTime date) {
    final now = TimeOfDay.now();
    return OutlinedButton(
      onPressed: () => onDateChanged(
        DateTime(date.year, date.month, date.day, now.hour, now.minute),
      ),
      child: Text(label),
    );
  }
}

/// A titled, icon-accented collapsible section used to replace tabs on the
/// Client Profile screen — every section (Overview, Plan, Checklist, Goals,
/// Software, Content, Notes) expands/collapses independently on one page.
class _CollapsibleSection extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget child;

  const _CollapsibleSection({
    required this.icon,
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
        title: Text(title, style: Theme.of(context).textTheme.titleMedium),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [child],
      ),
    );
  }
}

/// Read/toggle progress card for a client's assigned plan, shown inside the
/// Client Profile's collapsible "Plan & Progress" section.
class _ClientPlanProgressCard extends ConsumerWidget {
  final Plan plan;

  const _ClientPlanProgressCard({required this.plan});

  Future<void> _toggleFeature(
    WidgetRef ref,
    String rawFeature,
    bool done,
  ) async {
    final updated = List<String>.from(plan.completedFeatures);
    if (done) {
      if (!updated.contains(rawFeature)) updated.add(rawFeature);
    } else {
      updated.remove(rawFeature);
    }
    await ref
        .read(firestoreServiceProvider)
        .updatePlan(plan.copyWith(completedFeatures: updated));
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
    final percent = (plan.progress * 100).round();
    return Card(
      color: plan.isCompleted
          ? Colors.green.withValues(alpha: 0.08)
          : Theme.of(context).colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  plan.type == PlanType.subscription
                      ? Icons.autorenew
                      : Icons.build_circle_outlined,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    plan.name,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                Text(
                  plan.price == 0
                      ? 'Custom'
                      : '₹${plan.price.toStringAsFixed(0)}',
                ),
                const SizedBox(width: 8),
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
                  Chip(label: Text('$percent%')),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Starts ${DateFormat('MMM d, y').format(plan.startDate)}'
              '${plan.endDate != null ? ' • Ends ${DateFormat('MMM d, y').format(plan.endDate!)}' : ''}',
              style: Theme.of(context).textTheme.bodySmall,
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
              '${plan.completedFeatures.length} / ${plan.features.length} features completed',
              style: Theme.of(context).textTheme.bodySmall,
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
          ],
        ),
      ),
    );
  }
}

class ChecklistItemTile extends StatelessWidget {
  final SetupChecklistItem item;
  final Function(bool) onToggle;

  const ChecklistItemTile({
    super.key,
    required this.item,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: CheckboxListTile(
        value: item.isDone,
        onChanged: (value) {
          onToggle(value ?? false);
        },
        title: Text(
          item.itemName,
          style: TextStyle(
            decoration: item.isDone ? TextDecoration.lineThrough : null,
          ),
        ),
        subtitle: item.dueDate != null
            ? Text('Due: ${item.dueDate!.toString().split(' ')[0]}')
            : null,
      ),
    );
  }
}

class GoalCard extends StatelessWidget {
  final Goal goal;

  const GoalCard({super.key, required this.goal});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    '${goal.type.displayName} - ${goal.period}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                StageChip(label: goal.stage.displayName),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Target: ${goal.targetValue.toStringAsFixed(1)} (Baseline: ${goal.baselineValue.toStringAsFixed(1)} + ${(goal.liftPercentage * 100).toStringAsFixed(0)}%)',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (goal.progressValue != null) ...[
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: goal.progressPercentage / 100,
                  minHeight: 8,
                  backgroundColor: Colors.grey.withValues(alpha: 0.3),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    goal.progressPercentage >= 100
                        ? Colors.green
                        : Colors.orange,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${goal.progressValue?.toStringAsFixed(1)} of ${goal.targetValue.toStringAsFixed(1)} (${goal.progressPercentage.toStringAsFixed(0)}%)',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

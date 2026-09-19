import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tulasisolutionssite/core/models/brand_brief.dart';
import 'package:tulasisolutionssite/core/models/models.dart';
import 'package:tulasisolutionssite/core/providers/providers.dart';
import 'package:tulasisolutionssite/core/widgets/app_drawer.dart';
import 'package:tulasisolutionssite/core/widgets/shared_widgets.dart';
import 'package:tulasisolutionssite/features/client/brand_brief/client_brand_brief_screen.dart';

const _brandSectionLabels = <String, String>{
  'business': 'Brand Basics',
  'audience': 'Audience & Market',
  'personality': 'Personality & Voice',
  'logo': 'Logo Direction',
  'visualSystem': 'Colors & Typography',
  'assets': 'Existing Assets',
  'references': 'Design References',
  'motion': 'Motion & Video Brand Kit',
  'deliverables': 'Deliverables & Approval',
};

class BrandBriefsScreen extends ConsumerStatefulWidget {
  const BrandBriefsScreen({super.key});

  @override
  ConsumerState<BrandBriefsScreen> createState() => _BrandBriefsScreenState();
}

class _BrandBriefsScreenState extends ConsumerState<BrandBriefsScreen> {
  BrandBriefStatus? _filter;

  Future<void> _fillDuringCall(
    List<Plan> plans,
    Map<String, String> clientNames,
    Set<String> existingBriefs,
  ) async {
    if (plans.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Create a client plan first.')),
      );
      return;
    }
    final sorted = [...plans]
      ..sort(
        (first, second) => (clientNames[first.clientId] ?? '').compareTo(
          clientNames[second.clientId] ?? '',
        ),
      );
    final planId = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Fill brand brief during call'),
        content: SizedBox(
          width: 520,
          height: 440,
          child: ListView.separated(
            itemCount: sorted.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final plan = sorted[index];
              final exists = existingBriefs.contains(plan.id);
              return ListTile(
                leading: const Icon(Icons.branding_watermark_outlined),
                title: Text(clientNames[plan.clientId] ?? plan.clientId),
                subtitle: Text(
                  exists ? '${plan.name} • Continue brief' : plan.name,
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.pop(context, plan.id),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
    if (planId != null && mounted) {
      context.push('/admin/brand-briefs/$planId/edit');
    }
  }

  @override
  Widget build(BuildContext context) {
    final briefsAsync = ref.watch(allBrandBriefsProvider);
    final clientsAsync = ref.watch(clientsListProvider);
    final plans =
        ref.watch(allPlansStreamProvider).valueOrNull ?? const <Plan>[];
    return AppShell(
      isAdmin: true,
      currentRoute: '/admin/brand-briefs',
      title: 'Brand Identity Briefs',
      body: briefsAsync.when(
        loading: () => const LoadingWidget(),
        error: (error, stackTrace) =>
            CustomErrorWidget(message: 'Could not load brand briefs: $error'),
        data: (briefs) => clientsAsync.when(
          loading: () => const LoadingWidget(),
          error: (error, stackTrace) =>
              CustomErrorWidget(message: 'Could not load clients: $error'),
          data: (clients) {
            final clientNames = {
              for (final client in clients) client.id: client.name,
            };
            final visible = _filter == null
                ? briefs
                : briefs.where((brief) => brief.status == _filter).toList();
            return ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilledButton.icon(
                      onPressed: () => _fillDuringCall(
                        plans,
                        clientNames,
                        briefs.map((brief) => brief.planId).toSet(),
                      ),
                      icon: const Icon(Icons.support_agent_outlined),
                      label: const Text('Fill during call'),
                    ),
                    FilterChip(
                      label: Text('All (${briefs.length})'),
                      selected: _filter == null,
                      onSelected: (_) => setState(() => _filter = null),
                    ),
                    for (final status in BrandBriefStatus.values)
                      FilterChip(
                        label: Text(
                          '${status.label} (${briefs.where((brief) => brief.status == status).length})',
                        ),
                        selected: _filter == status,
                        onSelected: (_) => setState(() => _filter = status),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                if (visible.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(child: Text('No brand briefs in this view')),
                  )
                else
                  for (final brief in visible)
                    Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        leading: CircleAvatar(
                          child: Text('${brief.completionPercent}%'),
                        ),
                        title: Text(brief.planName),
                        subtitle: Text(
                          '${clientNames[brief.clientId] ?? brief.clientId} • Updated ${_formatDate(brief.updatedAt)}',
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _StatusChip(status: brief.status),
                            const SizedBox(width: 8),
                            const Icon(Icons.chevron_right),
                          ],
                        ),
                        onTap: () =>
                            context.push('/admin/brand-briefs/${brief.planId}'),
                      ),
                    ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class BrandBriefAdminEditScreen extends ConsumerWidget {
  final String planId;

  const BrandBriefAdminEditScreen({super.key, required this.planId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppShell(
      isAdmin: true,
      currentRoute: '/admin/brand-briefs',
      title: 'Fill Brand Identity Brief',
      actions: [
        IconButton(
          tooltip: 'Back to brand briefs',
          onPressed: () => context.go('/admin/brand-briefs'),
          icon: const Icon(Icons.close),
        ),
      ],
      body: ref
          .watch(allPlansStreamProvider)
          .when(
            loading: () => const LoadingWidget(),
            error: (error, stackTrace) =>
                CustomErrorWidget(message: 'Could not load plan: $error'),
            data: (plans) {
              final plan = plans.where((item) => item.id == planId).firstOrNull;
              if (plan == null) {
                return const Center(child: Text('Plan not found'));
              }
              return ref
                  .watch(clientProvider(plan.clientId))
                  .when(
                    loading: () => const LoadingWidget(),
                    error: (error, stackTrace) => CustomErrorWidget(
                      message: 'Could not load client: $error',
                    ),
                    data: (client) {
                      if (client == null) {
                        return const Center(child: Text('Client not found'));
                      }
                      return ref
                          .watch(brandBriefProvider(planId))
                          .when(
                            loading: () => const LoadingWidget(),
                            error: (error, stackTrace) => CustomErrorWidget(
                              message: 'Could not load brand brief: $error',
                            ),
                            data: (brief) => BrandBriefEditor(
                              key: ValueKey('$planId-admin'),
                              plan: plan,
                              client: client,
                              initialBrief: brief,
                              allPlans: [plan],
                              adminMode: true,
                              onDone: () => context.go(
                                brief == null
                                    ? '/admin/brand-briefs'
                                    : '/admin/brand-briefs/$planId',
                              ),
                            ),
                          );
                    },
                  );
            },
          ),
    );
  }
}

class BrandBriefReviewScreen extends ConsumerWidget {
  final String planId;

  const BrandBriefReviewScreen({super.key, required this.planId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppShell(
      isAdmin: true,
      currentRoute: '/admin/brand-briefs',
      title: 'Review Brand Identity Brief',
      actions: [
        IconButton(
          tooltip: 'Back to brand briefs',
          onPressed: () => context.go('/admin/brand-briefs'),
          icon: const Icon(Icons.close),
        ),
      ],
      body: ref
          .watch(brandBriefProvider(planId))
          .when(
            loading: () => const LoadingWidget(),
            error: (error, stackTrace) => CustomErrorWidget(
              message: 'Could not load brand brief: $error',
            ),
            data: (brief) => brief == null
                ? const Center(child: Text('Brand brief not found'))
                : _BrandBriefReview(brief: brief),
          ),
    );
  }
}

class _BrandBriefReview extends ConsumerStatefulWidget {
  final BrandBrief brief;

  const _BrandBriefReview({required this.brief});

  @override
  ConsumerState<_BrandBriefReview> createState() => _BrandBriefReviewState();
}

class _BrandBriefReviewState extends ConsumerState<_BrandBriefReview> {
  bool _saving = false;

  Future<void> _save(BrandBrief brief) async {
    setState(() => _saving = true);
    try {
      await ref.read(firestoreServiceProvider).saveBrandBrief(brief);
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Brand brief status updated')),
        );
      }
    } catch (error) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not update brand brief: $error')),
        );
      }
    }
  }

  Future<void> _sendForApproval() async {
    await _save(
      widget.brief.copyWith(
        status: BrandBriefStatus.awaitingApproval,
        requestedSections: const [],
        clearReviewNote: true,
        updatedAt: DateTime.now(),
      ),
    );
  }

  Future<void> _requestChanges() async {
    final selected = <String>{};
    final controller = TextEditingController();
    final result = await showDialog<({Set<String> sections, String note})>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Request brand changes'),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final entry in _brandSectionLabels.entries)
                    CheckboxListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text(entry.value),
                      value: selected.contains(entry.key),
                      onChanged: (checked) => setDialogState(() {
                        checked == true
                            ? selected.add(entry.key)
                            : selected.remove(entry.key);
                      }),
                    ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: controller,
                    minLines: 3,
                    maxLines: 6,
                    onChanged: (_) => setDialogState(() {}),
                    decoration: const InputDecoration(
                      labelText: 'Instructions for the client',
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: selected.isEmpty || controller.text.trim().isEmpty
                  ? null
                  : () => Navigator.pop(context, (
                      sections: selected,
                      note: controller.text.trim(),
                    )),
              child: const Text('Send request'),
            ),
          ],
        ),
      ),
    );
    controller.dispose();
    if (result == null) return;
    await _save(
      widget.brief.copyWith(
        status: BrandBriefStatus.changesRequested,
        reviewNote: result.note,
        requestedSections: result.sections.toList()..sort(),
        updatedAt: DateTime.now(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1050),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.brief.planName,
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        Text(
                          '${widget.brief.completionPercent}% complete • Updated ${_formatDate(widget.brief.updatedAt)}',
                        ),
                      ],
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (widget.brief.status != BrandBriefStatus.approved)
                          IconButton(
                            tooltip: 'Fill or edit during call',
                            onPressed: () => context.push(
                              '/admin/brand-briefs/${widget.brief.planId}/edit',
                            ),
                            icon: const Icon(Icons.edit_note_outlined),
                          ),
                        _StatusChip(status: widget.brief.status),
                      ],
                    ),
                  ],
                ),
                if (widget.brief.reviewNote.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Material(
                    color: const Color(0xFFFFF3CD),
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Text(widget.brief.reviewNote),
                    ),
                  ),
                ],
                const SizedBox(height: 18),
                for (final entry in _brandSectionLabels.entries) ...[
                  _ReviewSection(
                    title: entry.value,
                    values: Map<String, dynamic>.from(
                      widget.brief.sections[entry.key] as Map? ?? const {},
                    ),
                    requested: widget.brief.requestedSections.contains(
                      entry.key,
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
                if (widget.brief.status != BrandBriefStatus.approved)
                  Wrap(
                    alignment: WrapAlignment.end,
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      OutlinedButton.icon(
                        onPressed: _saving ? null : _requestChanges,
                        icon: const Icon(Icons.rate_review_outlined),
                        label: const Text('Request changes'),
                      ),
                      FilledButton.icon(
                        onPressed: _saving ? null : _sendForApproval,
                        icon: const Icon(Icons.verified_outlined),
                        label: const Text('Send for final approval'),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ReviewSection extends StatelessWidget {
  final String title;
  final Map<String, dynamic> values;
  final bool requested;

  const _ReviewSection({
    required this.title,
    required this.values,
    required this.requested,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: requested
          ? const Color(0xFFFFF3CD)
          : Theme.of(context).colorScheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(8),
      child: ExpansionTile(
        initiallyExpanded: requested,
        leading: Icon(
          requested ? Icons.feedback_outlined : Icons.checklist_outlined,
        ),
        title: Text(title),
        subtitle: requested ? const Text('Changes requested') : null,
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          if (values.isEmpty)
            const Align(
              alignment: Alignment.centerLeft,
              child: Text('No information provided'),
            )
          else
            for (final entry in values.entries)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _fieldLabel(entry.key),
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 3),
                      SelectableText(_displayValue(entry.value)),
                    ],
                  ),
                ),
              ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final BrandBriefStatus status;

  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      BrandBriefStatus.clientDraft => Colors.grey,
      BrandBriefStatus.submitted => Colors.blue,
      BrandBriefStatus.changesRequested => Colors.orange,
      BrandBriefStatus.awaitingApproval => Colors.amber,
      BrandBriefStatus.approved => Colors.green,
    };
    return Chip(
      avatar: Icon(Icons.circle, color: color, size: 10),
      label: Text(status.label),
    );
  }
}

extension on BrandBriefStatus {
  String get label => switch (this) {
    BrandBriefStatus.clientDraft => 'Draft',
    BrandBriefStatus.submitted => 'Submitted',
    BrandBriefStatus.changesRequested => 'Changes requested',
    BrandBriefStatus.awaitingApproval => 'Awaiting approval',
    BrandBriefStatus.approved => 'Approved',
  };
}

String _fieldLabel(String value) {
  final spaced = value.replaceAllMapped(
    RegExp(r'([a-z])([A-Z])'),
    (match) => '${match.group(1)} ${match.group(2)}',
  );
  return '${spaced[0].toUpperCase()}${spaced.substring(1)}';
}

String _displayValue(dynamic value) {
  if (value is List) return value.isEmpty ? 'None' : value.join(', ');
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? 'Not provided' : text;
}

String _formatDate(DateTime value) {
  final day = value.day.toString().padLeft(2, '0');
  final month = value.month.toString().padLeft(2, '0');
  return '$day/$month/${value.year}';
}

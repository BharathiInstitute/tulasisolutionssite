import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tulasisolutionssite/core/models/models.dart';
import 'package:tulasisolutionssite/core/models/website_brief.dart';
import 'package:tulasisolutionssite/core/providers/providers.dart';
import 'package:tulasisolutionssite/core/widgets/app_drawer.dart';
import 'package:tulasisolutionssite/core/widgets/shared_widgets.dart';
import 'package:tulasisolutionssite/features/client/website_brief/client_website_brief_screen.dart';

class WebsiteBriefsScreen extends ConsumerStatefulWidget {
  const WebsiteBriefsScreen({super.key});

  @override
  ConsumerState<WebsiteBriefsScreen> createState() =>
      _WebsiteBriefsScreenState();
}

class _WebsiteBriefsScreenState extends ConsumerState<WebsiteBriefsScreen> {
  WebsiteBriefStatus? _filter;

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
    final sortedPlans = [...plans]
      ..sort((first, second) {
        final firstClient = clientNames[first.clientId] ?? '';
        final secondClient = clientNames[second.clientId] ?? '';
        return firstClient.compareTo(secondClient);
      });
    final selectedPlanId = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Fill brief during call'),
        content: SizedBox(
          width: 520,
          height: 440,
          child: ListView.separated(
            itemCount: sortedPlans.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final plan = sortedPlans[index];
              final exists = existingBriefs.contains(plan.id);
              return ListTile(
                leading: const Icon(Icons.description_outlined),
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
    if (selectedPlanId != null && mounted) {
      context.push('/admin/website-briefs/$selectedPlanId/edit');
    }
  }

  @override
  Widget build(BuildContext context) {
    final briefsAsync = ref.watch(allWebsiteBriefsProvider);
    final clientsAsync = ref.watch(clientsListProvider);
    final plans =
        ref.watch(allPlansStreamProvider).valueOrNull ?? const <Plan>[];
    return AppShell(
      isAdmin: true,
      currentRoute: '/admin/website-briefs',
      title: 'Website Briefs',
      body: briefsAsync.when(
        loading: () => const LoadingWidget(),
        error: (error, stackTrace) =>
            CustomErrorWidget(message: 'Could not load briefs: $error'),
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
                    for (final status in WebsiteBriefStatus.values)
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
                    child: Center(
                      child: Text('No website briefs in this view'),
                    ),
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
                            _AdminStatusChip(status: brief.status),
                            const SizedBox(width: 8),
                            const Icon(Icons.chevron_right),
                          ],
                        ),
                        onTap: () => context.push(
                          '/admin/website-briefs/${brief.planId}',
                        ),
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

class WebsiteBriefAdminEditScreen extends ConsumerWidget {
  final String planId;

  const WebsiteBriefAdminEditScreen({super.key, required this.planId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppShell(
      isAdmin: true,
      currentRoute: '/admin/website-briefs',
      title: 'Fill Website Brief',
      actions: [
        IconButton(
          tooltip: 'Back to brief',
          onPressed: () => context.go('/admin/website-briefs/$planId'),
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
                          .watch(websiteBriefProvider(planId))
                          .when(
                            loading: () => const LoadingWidget(),
                            error: (error, stackTrace) => CustomErrorWidget(
                              message: 'Could not load website brief: $error',
                            ),
                            data: (brief) => WebsiteBriefEditor(
                              key: ValueKey('$planId-admin'),
                              plan: plan,
                              client: client,
                              initialBrief: brief,
                              allPlans: [plan],
                              adminMode: true,
                              onDone: () => context.go(
                                brief == null
                                    ? '/admin/website-briefs'
                                    : '/admin/website-briefs/$planId',
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

class WebsiteBriefReviewScreen extends ConsumerWidget {
  final String planId;

  const WebsiteBriefReviewScreen({super.key, required this.planId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppShell(
      isAdmin: true,
      currentRoute: '/admin/website-briefs',
      title: 'Review Website Brief',
      actions: [
        IconButton(
          tooltip: 'Back to briefs',
          onPressed: () => context.go('/admin/website-briefs'),
          icon: const Icon(Icons.close),
        ),
      ],
      body: ref
          .watch(websiteBriefProvider(planId))
          .when(
            loading: () => const LoadingWidget(),
            error: (error, stackTrace) =>
                CustomErrorWidget(message: 'Could not load brief: $error'),
            data: (brief) {
              if (brief == null) {
                return const Center(child: Text('Website brief not found'));
              }
              return _BriefReview(brief: brief);
            },
          ),
    );
  }
}

class _BriefReview extends ConsumerStatefulWidget {
  final WebsiteBrief brief;

  const _BriefReview({required this.brief});

  @override
  ConsumerState<_BriefReview> createState() => _BriefReviewState();
}

class _BriefReviewState extends ConsumerState<_BriefReview> {
  static const _sectionLabels = <String, String>{
    'basics': 'Business Basics',
    'goals': 'Website Goals',
    'pages': 'Pages',
    'features': 'Features',
    'design': 'Design Direction',
    'references': 'Reference Websites',
    'content': 'Content and Assets',
    'domain': 'Domain and Hosting',
    'timeline': 'Timeline and Approval',
  };

  bool _saving = false;

  Future<void> _sendForApproval() async {
    await _save(
      widget.brief.copyWith(
        status: WebsiteBriefStatus.awaitingApproval,
        updatedAt: DateTime.now(),
        requestedSections: const [],
        clearReviewNote: true,
      ),
    );
  }

  Future<void> _requestChanges() async {
    final selected = <String>{};
    final noteController = TextEditingController();
    final result = await showDialog<({Set<String> sections, String note})>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Request changes'),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('Select the sections the client should update.'),
                  const SizedBox(height: 8),
                  for (final entry in _sectionLabels.entries)
                    CheckboxListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text(entry.value),
                      value: selected.contains(entry.key),
                      onChanged: (checked) {
                        setDialogState(() {
                          checked == true
                              ? selected.add(entry.key)
                              : selected.remove(entry.key);
                        });
                      },
                    ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: noteController,
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
              onPressed: selected.isEmpty || noteController.text.trim().isEmpty
                  ? null
                  : () => Navigator.pop(context, (
                      sections: selected,
                      note: noteController.text.trim(),
                    )),
              child: const Text('Send request'),
            ),
          ],
        ),
      ),
    );
    noteController.dispose();
    if (result == null) return;
    await _save(
      widget.brief.copyWith(
        status: WebsiteBriefStatus.changesRequested,
        reviewNote: result.note,
        requestedSections: result.sections.toList()..sort(),
        updatedAt: DateTime.now(),
      ),
    );
  }

  Future<void> _save(WebsiteBrief brief) async {
    setState(() => _saving = true);
    try {
      await ref.read(firestoreServiceProvider).saveWebsiteBrief(brief);
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Brief status updated')));
      }
    } catch (error) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not update brief: $error')),
        );
      }
    }
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
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.brief.planName,
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${widget.brief.completionPercent}% complete • Updated ${_formatDate(widget.brief.updatedAt)}',
                          ),
                        ],
                      ),
                    ),
                    if (widget.brief.status != WebsiteBriefStatus.approved)
                      IconButton(
                        tooltip: 'Fill or edit during call',
                        onPressed: () => context.push(
                          '/admin/website-briefs/${widget.brief.planId}/edit',
                        ),
                        icon: const Icon(Icons.edit_note_outlined),
                      ),
                    _AdminStatusChip(status: widget.brief.status),
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
                for (final entry in _sectionLabels.entries) ...[
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
                if (widget.brief.status != WebsiteBriefStatus.approved) ...[
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      OutlinedButton.icon(
                        onPressed: _saving ? null : _requestChanges,
                        icon: const Icon(Icons.rate_review_outlined),
                        label: const Text('Request changes'),
                      ),
                      const SizedBox(width: 10),
                      FilledButton.icon(
                        onPressed: _saving ? null : _sendForApproval,
                        icon: const Icon(Icons.verified_outlined),
                        label: const Text('Send for final approval'),
                      ),
                    ],
                  ),
                ],
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
                padding: const EdgeInsets.only(top: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 170,
                      child: Text(
                        _fieldLabel(entry.key),
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    Expanded(child: SelectableText(_displayValue(entry.value))),
                  ],
                ),
              ),
        ],
      ),
    );
  }
}

class _AdminStatusChip extends StatelessWidget {
  final WebsiteBriefStatus status;

  const _AdminStatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      WebsiteBriefStatus.clientDraft => Colors.grey,
      WebsiteBriefStatus.submitted => Colors.blue,
      WebsiteBriefStatus.changesRequested => Colors.orange,
      WebsiteBriefStatus.awaitingApproval => Colors.amber,
      WebsiteBriefStatus.approved => Colors.green,
    };
    return Chip(
      avatar: Icon(Icons.circle, color: color, size: 10),
      label: Text(status.label),
    );
  }
}

extension on WebsiteBriefStatus {
  String get label => switch (this) {
    WebsiteBriefStatus.clientDraft => 'Draft',
    WebsiteBriefStatus.submitted => 'Submitted',
    WebsiteBriefStatus.changesRequested => 'Changes requested',
    WebsiteBriefStatus.awaitingApproval => 'Awaiting approval',
    WebsiteBriefStatus.approved => 'Approved',
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

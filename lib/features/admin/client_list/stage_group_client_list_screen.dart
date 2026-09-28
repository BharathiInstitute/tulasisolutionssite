import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tulasisolutionssite/core/constants/enums.dart';
import 'package:tulasisolutionssite/core/models/models.dart';
import 'package:tulasisolutionssite/core/providers/providers.dart';
import 'package:tulasisolutionssite/core/widgets/app_drawer.dart';
import 'package:tulasisolutionssite/core/widgets/shared_widgets.dart';
import 'add_client_screen.dart';
import 'client_list_screen.dart';

/// Client list driven by which clients have a plan (of any type in
/// [planTypes]) assigned in the Plans panel — used for the "Clients"
/// side-menu panel. Filtering by plan (not [ClientStage]) keeps this list
/// always in sync with the Plans panel's Client Plans tab: a client shows
/// up here exactly when — and only when — they have a matching plan there.
class StageGroupClientListScreen extends ConsumerStatefulWidget {
  final String title;
  final IconData icon;
  final String currentRoute;
  final Set<ClientStage> stages;
  final Set<PlanType> planTypes;

  const StageGroupClientListScreen({
    super.key,
    required this.title,
    required this.icon,
    required this.currentRoute,
    required this.stages,
    required this.planTypes,
  });

  @override
  ConsumerState<StageGroupClientListScreen> createState() =>
      _StageGroupClientListScreenState();
}

class _StageGroupClientListScreenState
    extends ConsumerState<StageGroupClientListScreen> {
  String _searchQuery = '';
  bool? _completedFilter;
  PlanType? _planTypeFilter;
  String? _planNameFilter;

  bool get _hasActiveFilter =>
      _completedFilter != null ||
      _planTypeFilter != null ||
      _planNameFilter != null;

  void _clearFilters() {
    setState(() {
      _completedFilter = null;
      _planTypeFilter = null;
      _planNameFilter = null;
    });
  }

  void _toggleCompletedFilter(bool value) {
    setState(() {
      _completedFilter = _completedFilter == value ? null : value;
    });
  }

  void _togglePlanTypeFilter(PlanType type) {
    setState(() {
      _planTypeFilter = _planTypeFilter == type ? null : type;
    });
  }

  void _togglePlanNameFilter(String name) {
    setState(() {
      _planNameFilter = _planNameFilter == name ? null : name;
    });
  }

  @override
  Widget build(BuildContext context) {
    final clientsAsync = ref.watch(clientsListProvider);
    final plansAsync = ref.watch(allPlansProvider);

    return AppShell(
      isAdmin: true,
      currentRoute: widget.currentRoute,
      title: widget.title,
      body: clientsAsync.when(
        data: (clients) {
          return plansAsync.when(
            data: (plans) {
              final plansByClient = <String, Plan>{
                for (final p in plans.where(
                  (p) => widget.planTypes.contains(p.type),
                ))
                  p.clientId: p,
              };

              var searchScoped = clients
                  .where((c) => plansByClient.containsKey(c.id))
                  .toList();

              if (_searchQuery.isNotEmpty) {
                searchScoped = searchScoped
                    .where(
                      (c) =>
                          c.clientCode.toLowerCase().contains(_searchQuery) ||
                          c.name.toLowerCase().contains(_searchQuery) ||
                          c.contactPhone.contains(_searchQuery),
                    )
                    .toList();
              }

              // Chip counts stay stable against the search results so users
              // can see totals for every facet regardless of which chips
              // are currently selected.
              final totalCount = searchScoped.length;
              final completedCount = searchScoped
                  .where((c) => plansByClient[c.id]!.isCompleted)
                  .length;
              final inProgressCount = totalCount - completedCount;
              final setupCount = searchScoped
                  .where((c) => plansByClient[c.id]!.type == PlanType.setup)
                  .length;
              final subscriptionCount = searchScoped
                  .where(
                    (c) => plansByClient[c.id]!.type == PlanType.subscription,
                  )
                  .length;
              final planCounts = <String, int>{};
              for (final client in searchScoped) {
                final planName = plansByClient[client.id]?.name ?? 'Unknown';
                planCounts[planName] = (planCounts[planName] ?? 0) + 1;
              }

              final filtered = searchScoped.where((c) {
                final plan = plansByClient[c.id]!;
                if (_completedFilter != null &&
                    plan.isCompleted != _completedFilter) {
                  return false;
                }
                if (_planTypeFilter != null && plan.type != _planTypeFilter) {
                  return false;
                }
                if (_planNameFilter != null && plan.name != _planNameFilter) {
                  return false;
                }
                return true;
              }).toList();

              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            decoration: InputDecoration(
                              hintText: 'Search by code, name, or phone...',
                              prefixIcon: const Icon(Icons.search),
                            ),
                            onChanged: (value) {
                              setState(
                                () => _searchQuery = value.toLowerCase(),
                              );
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Flexible(
                          child: Wrap(
                            alignment: WrapAlignment.end,
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              _SummaryChip(
                                label: 'Total',
                                value: '$totalCount',
                                selected: !_hasActiveFilter,
                                onTap: _clearFilters,
                              ),
                              _SummaryChip(
                                label: 'Completed',
                                value: '$completedCount',
                                color: Colors.green,
                                selected: _completedFilter == true,
                                onTap: () => _toggleCompletedFilter(true),
                              ),
                              _SummaryChip(
                                label: 'In Progress',
                                value: '$inProgressCount',
                                color: Colors.orange,
                                selected: _completedFilter == false,
                                onTap: () => _toggleCompletedFilter(false),
                              ),
                              if (widget.planTypes.contains(PlanType.setup))
                                _SummaryChip(
                                  label: 'Setup',
                                  value: '$setupCount',
                                  color: Colors.purple,
                                  selected: _planTypeFilter == PlanType.setup,
                                  onTap: () =>
                                      _togglePlanTypeFilter(PlanType.setup),
                                ),
                              if (widget.planTypes.contains(
                                PlanType.subscription,
                              ))
                                _SummaryChip(
                                  label: 'Subscription',
                                  value: '$subscriptionCount',
                                  color: Colors.teal,
                                  selected:
                                      _planTypeFilter == PlanType.subscription,
                                  onTap: () => _togglePlanTypeFilter(
                                    PlanType.subscription,
                                  ),
                                ),
                              ...planCounts.entries.map(
                                (entry) => _SummaryChip(
                                  label: entry.key,
                                  value: '${entry.value}',
                                  color: Colors.blue,
                                  selected: _planNameFilter == entry.key,
                                  onTap: () => _togglePlanNameFilter(entry.key),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: filtered.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(widget.icon, size: 56, color: Colors.grey),
                                const SizedBox(height: 12),
                                Text(
                                  _hasActiveFilter
                                      ? 'No clients match the selected filters'
                                      : 'No clients with a plan assigned yet',
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Assign one from Plans → Client Plans',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            itemCount: filtered.length,
                            itemBuilder: (context, index) {
                              final client = filtered[index];
                              final plan = plansByClient[client.id]!;
                              return ClientCard(
                                client: client,
                                plan: plan,
                                showFollowUpActions: false,
                                showFunnelStage: false,
                                onTap: () =>
                                    context.push('/admin/leads/${client.id}'),
                              );
                            },
                          ),
                  ),
                ],
              );
            },
            loading: () => const LoadingWidget(),
            error: (error, stackTrace) => CustomErrorWidget(
              message: 'Error loading plans: $error',
              onRetry: () => ref.invalidate(allPlansProvider),
            ),
          );
        },
        loading: () => const LoadingWidget(),
        error: (error, stackTrace) => CustomErrorWidget(
          message: 'Error loading clients: $error',
          onRetry: () {
            ref.invalidate(clientsListProvider);
            ref.invalidate(allPlansProvider);
          },
        ),
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Add client',
        onPressed: () {
          showAddClientDialog(context, initialStage: widget.stages.first);
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}

/// Compact live progress strip shown under a client's card, reflecting the
/// same plan data (and completion updates) as the Plans panel.
class _SummaryChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  const _SummaryChip({
    required this.label,
    required this.value,
    required this.onTap,
    this.selected = false,
    this.color = const Color(0xFF2E7D32),
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: selected ? 0.28 : 0.12),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: color.withValues(alpha: selected ? 0.9 : 0.25),
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$label: ',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.black87,
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              value,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: color,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tulasisolutionssite/core/chat/chat.dart';
import 'package:tulasisolutionssite/core/models/models.dart';
import 'package:tulasisolutionssite/core/providers/providers.dart';
import 'package:tulasisolutionssite/core/constants/enums.dart';
import 'package:tulasisolutionssite/core/widgets/shared_widgets.dart';
import 'package:tulasisolutionssite/core/widgets/app_drawer.dart';
import 'package:tulasisolutionssite/features/chat/lead_transfer.dart';
import 'add_client_screen.dart';
import '../client_profile/client_profile_screen.dart';

class ClientListScreen extends ConsumerStatefulWidget {
  const ClientListScreen({super.key});

  @override
  ConsumerState<ClientListScreen> createState() => _ClientListScreenState();
}

class _ClientListScreenState extends ConsumerState<ClientListScreen> {
  ClientStage? _selectedStage = ClientStage.click;
  String _searchQuery = '';
  bool _isTransferringLeads = false;

  bool get _hasSearchTerm => _searchQuery.length > 1;

  bool _matchesSearch(Client client) {
    final searchableDetails = [
      client.clientCode,
      client.name,
      client.ownerName,
      client.category,
      client.contactEmail,
      client.contactPhone,
      client.alternatePhone,
      client.assignedManager,
      client.notes,
      client.followUpNotes,
      client.stage.displayName,
    ].whereType<String>().join(' ').toLowerCase();
    return searchableDetails.contains(_searchQuery);
  }

  Future<void> _importLeads(List<Client> clients) async {
    setState(() => _isTransferringLeads = true);
    await importLeadFile(context: context, ref: ref, clients: clients);
    if (mounted) setState(() => _isTransferringLeads = false);
  }

  Future<void> _exportLeads(List<Client> clients) async {
    setState(() => _isTransferringLeads = true);
    await exportLeadFile(context: context, clients: clients);
    if (mounted) setState(() => _isTransferringLeads = false);
  }

  @override
  Widget build(BuildContext context) {
    final clientsAsync = ref.watch(clientsListProvider);

    return AppShell(
      isAdmin: true,
      currentRoute: '/admin/leads',
      title: 'Leads',
      actions: [
        if (_isTransferringLeads)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Center(
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              ),
            ),
          )
        else ...[
          TextButton.icon(
            onPressed: clientsAsync.hasValue
                ? () => _importLeads(clientsAsync.requireValue)
                : null,
            icon: const Icon(Icons.upload_file_outlined),
            label: const Text('Import'),
            style: TextButton.styleFrom(foregroundColor: Colors.white),
          ),
          TextButton.icon(
            onPressed: clientsAsync.hasValue
                ? () => _exportLeads(clientsAsync.requireValue)
                : null,
            icon: const Icon(Icons.download_outlined),
            label: const Text('Export'),
            style: TextButton.styleFrom(foregroundColor: Colors.white),
          ),
        ],
        IconButton(
          tooltip: 'Refresh',
          icon: const Icon(Icons.refresh),
          onPressed: () {
            ref.invalidate(clientsListProvider);
          },
        ),
      ],
      body: clientsAsync.when(
        data: (clients) {
          var stageClients = clients;

          if (_selectedStage != null && !_hasSearchTerm) {
            stageClients = stageClients
                .where((c) => c.stage == _selectedStage)
                .toList();
          }

          if (_hasSearchTerm) {
            stageClients = stageClients.where(_matchesSearch).toList();
          }

          final activeClients = stageClients
              .where((client) => !client.isArchived)
              .toList();
          final archivedClients = stageClients
              .where((client) => client.isArchived)
              .toList();

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    TextField(
                      decoration: InputDecoration(
                        hintText: 'Search by code, name, phone, or details...',
                        prefixIcon: const Icon(Icons.search),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onChanged: (value) {
                        setState(
                          () => _searchQuery = value.trim().toLowerCase(),
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          ...ClientStage.values
                              .where(
                                (stage) =>
                                    stage != ClientStage.reach &&
                                    stage != ClientStage.register,
                              )
                              .map((stage) {
                                final count = clients
                                    .where((c) => c.stage == stage)
                                    .length;
                                return FilterChip(
                                  label: Text(
                                    '${stage.displayName} ($count)',
                                  ),
                                  selected: _selectedStage == stage,
                                  onSelected: (_) {
                                    setState(() => _selectedStage = stage);
                                  },
                                );
                              }),
                          FilterChip(
                            label: Text('All (${clients.length})'),
                            selected: _selectedStage == null,
                            onSelected: (_) {
                              setState(() => _selectedStage = null);
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  children: [
                    if (activeClients.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(24),
                        child: Center(child: Text('No active leads found')),
                      )
                    else
                      for (final client in activeClients)
                        ClientCard(client: client),
                    _ArchivedLeadsSection(clients: archivedClients),
                  ],
                ),
              ),
            ],
          );
        },
        loading: () => const LoadingWidget(),
        error: (error, stackTrace) =>
            CustomErrorWidget(message: 'Error loading clients: $error'),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.green,
        onPressed: () {
          showAddClientDialog(context);
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}

class ClientCard extends ConsumerWidget {
  final Client client;
  final Plan? plan;
  final VoidCallback? onTap;
  final bool showFollowUpActions;
  final bool showFunnelStage;

  const ClientCard({
    super.key,
    required this.client,
    this.plan,
    this.onTap,
    this.showFollowUpActions = true,
    this.showFunnelStage = true,
  });

  Color _getStageColor(ClientStage stage) {
    switch (stage) {
      case ClientStage.reach:
        return Colors.orange;
      case ClientStage.click:
        return Colors.deepOrange;
      case ClientStage.register:
        return Colors.blue;
      case ClientStage.consult:
        return Colors.indigo;
      case ClientStage.followUp:
        return Colors.purple;
      case ClientStage.client:
        return Colors.green;
      case ClientStage.retain:
        return Colors.teal;
      case ClientStage.lost:
        return Colors.red;
    }
  }

  Future<void> _changeStage(
    BuildContext context,
    WidgetRef ref,
    ClientStage stage,
  ) async {
    if (stage == client.stage) return;
    try {
      await ref
          .read(firestoreServiceProvider)
          .updateClient(client.copyWith(stage: stage));
      ref.invalidate(clientsListProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${client.name} moved to ${stage.displayName}'),
          ),
        );
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not update stage: $error')),
        );
      }
    }
  }

  Future<void> _editClient(BuildContext context, WidgetRef ref) async {
    await showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Edit client',
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (dialogContext, animation, secondaryAnimation) {
        return ClientDetailsSideSheet(client: client, ref: ref);
      },
    );
    ref.invalidate(clientsListProvider);
  }

  Future<void> _setArchived(
    BuildContext context,
    WidgetRef ref,
    bool isArchived,
  ) async {
    try {
      await ref
          .read(firestoreServiceProvider)
          .updateClient(client.copyWith(isArchived: isArchived));
      ref.invalidate(clientsListProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isArchived
                  ? '${client.name} archived'
                  : '${client.name} restored to ${client.stage.displayName}',
            ),
          ),
        );
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not update archive: $error')),
        );
      }
    }
  }

  Future<void> _editNotes(BuildContext context, WidgetRef ref) async {
    final notesController = TextEditingController(text: client.notes ?? '');
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Notes: ${client.name}'),
        content: SizedBox(
          width: 420,
          child: TextField(
            controller: notesController,
            autofocus: true,
            minLines: 4,
            maxLines: 8,
            decoration: const InputDecoration(
              hintText: 'Add notes about this client...',
              alignLabelWithHint: true,
              border: OutlineInputBorder(),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Save notes'),
          ),
        ],
      ),
    );

    if (saved == true) {
      try {
        await ref
            .read(firestoreServiceProvider)
            .updateClient(client.copyWith(notes: notesController.text.trim()));
        ref.invalidate(clientsListProvider);
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Notes saved')));
        }
      } catch (error) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not save notes: $error')),
          );
        }
      }
    }
    notesController.dispose();
  }

  Future<void> _deleteLostClient(BuildContext context, WidgetRef ref) async {
    final confirmationController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete lost lead?'),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('You are deleting: ${client.name}'),
              const SizedBox(height: 16),
              TextField(
                controller: confirmationController,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Type delete to confirm',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: confirmationController,
            builder: (context, value, child) => ElevatedButton(
              onPressed: value.text == 'delete'
                  ? () => Navigator.of(dialogContext).pop(true)
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('Delete'),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await ref.read(firestoreServiceProvider).deleteClient(client.id);
        ref.invalidate(clientsListProvider);
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('${client.name} deleted')));
        }
      } catch (error) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not delete client: $error')),
          );
        }
      }
    }
    confirmationController.dispose();
  }

  Future<void> _showFollowUpSettings(
    BuildContext context,
    WidgetRef ref,
  ) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) =>
          FollowUpSettingsDialog(client: client, ref: ref),
    );
    ref.invalidate(clientsListProvider);
  }

  Future<void> _openWhatsAppChat(BuildContext context, WidgetRef ref) async {
    final phone = client.contactPhone.trim();
    if (phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This lead has no WhatsApp phone number.'),
        ),
      );
      return;
    }

    final chat = ref.read(chatProvider);
    final existing = chat.conversations.where(
      (conversation) =>
          conversation.clientId == client.id &&
          conversation.channel == ConversationChannel.whatsapp &&
          (conversation.contactId == client.id ||
              conversation.contactPhone.replaceAll(RegExp(r'\D'), '') ==
                  phone.replaceAll(RegExp(r'\D'), '')),
    );
    final conversation = existing.isNotEmpty
        ? existing.first
        : await chat.createConversation(
            contactId: client.id,
            contactName: client.name,
            contactPhone: phone,
            ownerClientId: client.id,
          );
    if (conversation == null || !context.mounted) return;
    context.push('/admin/chat/${conversation.id}', extra: conversation);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final percent = plan != null ? (plan!.progress * 100).round() : null;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListTile(
        contentPadding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        title: Text(client.name),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            if (client.clientCode.isNotEmpty)
              _detailLine(
                Icons.tag_outlined,
                'Code',
                client.clientCode,
              ),
            _detailLine(Icons.business, 'Business', client.name),
            if ((client.ownerName ?? client.assignedManager)
                    ?.trim()
                    .isNotEmpty ==
                true)
              _detailLine(
                Icons.person_outline,
                'Owner',
                client.ownerName ?? client.assignedManager!,
              ),
            if (client.contactPhone.trim().isNotEmpty)
              _detailLine(Icons.phone_outlined, 'Phone', client.contactPhone),
            if (client.alternatePhone?.trim().isNotEmpty == true)
              _detailLine(
                Icons.phone_android_outlined,
                'Alternate phone',
                client.alternatePhone!,
              ),
            if (client.contactEmail.trim().isNotEmpty)
              _detailLine(Icons.email_outlined, 'Email', client.contactEmail),
            if (client.category.trim().isNotEmpty)
              _detailLine(Icons.category_outlined, 'Category', client.category),
            _detailLine(
              Icons.schedule_outlined,
              'Created',
              _formatDateTime(client.createdDate),
            ),
            _detailLine(
              Icons.app_registration_outlined,
              'Registration',
              _isRegistered ? 'Registered' : 'Not registered',
            ),
            if (client.followUpAt != null)
              StreamBuilder<int>(
                stream: Stream.periodic(
                  const Duration(minutes: 1),
                  (tick) => tick,
                ),
                builder: (context, snapshot) {
                  final remaining = client.followUpAt!.difference(
                    DateTime.now(),
                  );
                  final overdue = remaining.isNegative;
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          overdue
                              ? Icons.warning_amber_outlined
                              : Icons.alarm_outlined,
                          size: 16,
                          color: overdue ? Colors.red : Colors.green,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                overdue
                                    ? 'Follow-up overdue by ${_formatCountdown(remaining.abs())}'
                                    : 'Follow-up in ${_formatCountdown(remaining)}',
                                style: TextStyle(
                                  color: overdue ? Colors.red : Colors.green,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              if (client.followUpNotes?.trim().isNotEmpty ==
                                  true)
                                Text(
                                  client.followUpNotes!,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            if (showFunnelStage) ...[
              const SizedBox(height: 4),
              PopupMenuButton<ClientStage>(
                tooltip: 'Change funnel stage',
                onSelected: (stage) => _changeStage(context, ref, stage),
                itemBuilder: (context) => ClientStage.values
                    .where(
                      (stage) =>
                          stage != ClientStage.reach &&
                          stage != ClientStage.register,
                    )
                    .map(
                      (stage) => PopupMenuItem(
                        value: stage,
                        child: Row(
                          children: [
                            Icon(
                              stage == client.stage
                                  ? Icons.check_circle
                                  : Icons.circle_outlined,
                              size: 18,
                              color: _getStageColor(stage),
                            ),
                            const SizedBox(width: 8),
                            Text(stage.displayName),
                          ],
                        ),
                      ),
                    )
                    .toList(),
                child: StageChip(
                  label: client.stage.displayName,
                  backgroundColor: _getStageColor(
                    client.stage,
                  ).withValues(alpha: 0.2),
                  textColor: _getStageColor(client.stage),
                ),
              ),
            ],
            if (plan != null) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          plan!.name,
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(999),
                          child: LinearProgressIndicator(
                            value: plan!.progress,
                            minHeight: 6,
                            backgroundColor: Colors.grey.withValues(alpha: 0.2),
                            valueColor: AlwaysStoppedAnimation<Color>(
                              plan!.isCompleted ? Colors.green : Colors.orange,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Chip(
                    label: Text(plan!.isCompleted ? 'Completed' : '$percent%'),
                    backgroundColor: plan!.isCompleted
                        ? Colors.green.withValues(alpha: 0.15)
                        : null,
                    labelStyle: TextStyle(
                      color: plan!.isCompleted ? Colors.green : null,
                      fontWeight: plan!.isCompleted ? FontWeight.w700 : null,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
        trailing: showFollowUpActions
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: 'Open WhatsApp chat',
                    icon: const Icon(Icons.chat, color: Color(0xFF25D366)),
                    onPressed: () => _openWhatsAppChat(context, ref),
                  ),
                  IconButton(
                    tooltip: 'Follow-up settings',
                    icon: Icon(
                      Icons.alarm_outlined,
                      color: client.followUpAt == null ? null : Colors.green,
                    ),
                    onPressed: () => _showFollowUpSettings(context, ref),
                  ),
                  IconButton(
                    tooltip: 'Add or edit notes',
                    icon: const Icon(Icons.note_add_outlined),
                    onPressed: () => _editNotes(context, ref),
                  ),
                  if (showFunnelStage)
                    IconButton(
                      tooltip: client.isArchived
                          ? 'Restore lead'
                          : 'Archive lead',
                      icon: Icon(
                        client.isArchived
                            ? Icons.unarchive_outlined
                            : Icons.archive_outlined,
                      ),
                      onPressed: () =>
                          _setArchived(context, ref, !client.isArchived),
                    ),
                  if (client.stage == ClientStage.lost)
                    IconButton(
                      tooltip: 'Delete lost lead',
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                      onPressed: () => _deleteLostClient(context, ref),
                    ),
                  IconButton(
                    tooltip: 'Edit client details',
                    icon: const Icon(Icons.edit_outlined),
                    onPressed: () => _editClient(context, ref),
                  ),
                ],
              )
            : const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }

  Widget _detailLine(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(top: 3),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey.shade600),
          const SizedBox(width: 6),
          Text('$label: ', style: const TextStyle(fontWeight: FontWeight.w600)),
          Expanded(child: Text(value, overflow: TextOverflow.ellipsis)),
        ],
      ),
    );
  }

  String _formatCountdown(Duration duration) {
    final days = duration.inDays;
    final hours = duration.inHours.remainder(24);
    final minutes = duration.inMinutes.remainder(60);
    if (days > 0) return '${days}d ${hours}h';
    if (hours > 0) return '${hours}h ${minutes}m';
    return '${minutes == 0 ? 1 : minutes}m';
  }

  bool get _isRegistered =>
      client.name.trim().isNotEmpty &&
      (client.ownerName?.trim().isNotEmpty ?? false) &&
      client.category.trim().isNotEmpty &&
      client.contactEmail.trim().isNotEmpty &&
      client.contactPhone.trim().isNotEmpty &&
      (client.alternatePhone?.trim().isNotEmpty ?? false);

  String _formatDateTime(DateTime value) {
    final local = value.toLocal();
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    final hour = local.hour == 0
        ? 12
        : local.hour > 12
        ? local.hour - 12
        : local.hour;
    final minute = local.minute.toString().padLeft(2, '0');
    final period = local.hour >= 12 ? 'PM' : 'AM';
    return '$day/$month/${local.year}, $hour:$minute $period';
  }
}

class _ArchivedLeadsSection extends StatelessWidget {
  final List<Client> clients;

  const _ArchivedLeadsSection({required this.clients});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: ExpansionTile(
          leading: const Icon(Icons.archive_outlined),
          title: Text('Archived (${clients.length})'),
          children: [
            if (clients.isEmpty)
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Text('No archived leads in this funnel stage'),
              )
            else
              for (final client in clients)
                ClientCard(key: ValueKey(client.id), client: client),
          ],
        ),
      ),
    );
  }
}

class FollowUpSettingsDialog extends StatefulWidget {
  final Client client;
  final WidgetRef ref;

  const FollowUpSettingsDialog({
    super.key,
    required this.client,
    required this.ref,
  });

  @override
  State<FollowUpSettingsDialog> createState() => _FollowUpSettingsDialogState();
}

class _FollowUpSettingsDialogState extends State<FollowUpSettingsDialog> {
  late final TextEditingController _notesController;
  DateTime? _followUpAt;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _followUpAt = widget.client.followUpAt;
    _notesController = TextEditingController(
      text: widget.client.followUpNotes ?? '',
    );
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickDateTime() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(now.year, now.month + 2, now.day),
      initialDate: _followUpAt ?? now,
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: _followUpAt == null
          ? TimeOfDay.now()
          : TimeOfDay.fromDateTime(_followUpAt!),
    );
    if (time == null) return;
    setState(() {
      _followUpAt = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });
  }

  void _setQuickDate(Duration offset) {
    final date = DateTime.now().add(offset);
    final time = TimeOfDay.now();
    setState(() {
      _followUpAt = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await widget.ref
          .read(firestoreServiceProvider)
          .updateClient(
            widget.client.copyWith(
              followUpAt: _followUpAt,
              followUpNotes: _notesController.text.trim().isEmpty
                  ? null
                  : _notesController.text.trim(),
              clearFollowUp: _followUpAt == null,
            ),
          );
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (error) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not save follow-up: $error')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateLabel = _followUpAt == null
        ? 'No follow-up scheduled'
        : '${_followUpAt!.day}/${_followUpAt!.month}/${_followUpAt!.year} at '
              '${_followUpAt!.hour == 0
                  ? 12
                  : _followUpAt!.hour > 12
                  ? _followUpAt!.hour - 12
                  : _followUpAt!.hour}:${_followUpAt!.minute.toString().padLeft(2, '0')} ${_followUpAt!.hour >= 12 ? 'PM' : 'AM'}';
    return AlertDialog(
      title: const Text('Follow-up settings'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.calendar_month_outlined),
              title: Text(dateLabel),
              subtitle: const Text('Set the reminder day and time'),
              trailing: IconButton(
                tooltip: 'Choose date and time',
                onPressed: _pickDateTime,
                icon: const Icon(Icons.edit_calendar_outlined),
              ),
            ),
            Wrap(
              spacing: 8,
              children: [
                OutlinedButton(
                  onPressed: () => _setQuickDate(Duration.zero),
                  child: const Text('Today'),
                ),
                OutlinedButton(
                  onPressed: () => _setQuickDate(const Duration(days: 7)),
                  child: const Text('This week'),
                ),
                OutlinedButton(
                  onPressed: () => _setQuickDate(const Duration(days: 30)),
                  child: const Text('This month'),
                ),
                if (_followUpAt != null)
                  TextButton(
                    onPressed: () => setState(() => _followUpAt = null),
                    child: const Text('Clear'),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _notesController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Follow-up notes',
                hintText: 'What should be discussed?',
                prefixIcon: Icon(Icons.sticky_note_2_outlined),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Save'),
        ),
      ],
    );
  }
}

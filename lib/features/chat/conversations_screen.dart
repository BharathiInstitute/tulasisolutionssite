import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/chat/chat.dart';
import '../../core/constants/enums.dart';
import '../../core/models/models.dart';
import '../../core/providers/providers.dart';
import '../../core/widgets/app_drawer.dart';
import '../../core/widgets/shared_widgets.dart';
import '../admin/client_list/client_list_screen.dart';
import 'lead_csv.dart';
import 'lead_csv_download.dart';
import 'lead_csv_picker.dart';

class ConversationsScreen extends ConsumerStatefulWidget {
  const ConversationsScreen({super.key});

  @override
  ConsumerState<ConversationsScreen> createState() =>
      _ConversationsScreenState();
}

class _ConversationsScreenState extends ConsumerState<ConversationsScreen> {
  String _searchQuery = '';
  ClientStage? _selectedFunnelStage;
  String? _selectedClosedReason;
  final Set<String> _startingAutomation = {};
  final Set<String> _createdFunnelPhones = {};
  bool _isTransferringLeads = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final chat = ref.watch(chatProvider);
    final conversations = chat.conversations;
    final clientsAsync = ref.watch(clientsListProvider);
    final clients = clientsAsync.valueOrNull ?? const <Client>[];

    final whatsappConvs = conversations
        .where((c) => c.channel == ConversationChannel.whatsapp)
        .toList();
    final clientsByPhone = _indexClientsByPhone(clients);
    final filteredConversations = _filterConversations(
      whatsappConvs,
      clientsByPhone,
    );

    if (clientsAsync.hasValue) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await _addChatsToFunnel(whatsappConvs, clients);
      });
    }

    return AppShell(
      isAdmin: true,
      currentRoute: '/admin/chat',
      title: 'Chat',
      actions: [
        if (_isTransferringLeads)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 12),
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
          IconButton(
            onPressed: () => _importLeads(clients),
            icon: const Icon(Icons.upload_file_outlined),
            tooltip: 'Import names and numbers',
          ),
          IconButton(
            onPressed: () => _exportLeads(clients, whatsappConvs),
            icon: const Icon(Icons.download_outlined),
            tooltip: 'Export names and numbers',
          ),
        ],
        TextButton.icon(
          onPressed: () => context.go('/admin/templates'),
          icon: const Icon(Icons.article_outlined, size: 18),
          label: const Text('Templates'),
          style: TextButton.styleFrom(foregroundColor: Colors.white),
        ),
        if (chat.totalUnread > 0)
          Semantics(
            label:
                '${chat.totalUnread} unread ${chat.totalUnread == 1 ? 'chat' : 'chats'}',
            child: Container(
              constraints: const BoxConstraints(minWidth: 24),
              margin: const EdgeInsets.only(right: 4),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.22),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${chat.totalUnread} Unread',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        IconButton(
          icon: const Icon(Icons.refresh),
          tooltip: 'Refresh',
          onPressed: () => chat.loadConversations(),
        ),
      ],
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showNewMessageSheet(context),
        backgroundColor: const Color(0xFF25D366),
        child: const Icon(Icons.message),
      ),
      body: chat.isLoading
          ? const Center(child: CircularProgressIndicator())
          : chat.error != null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 64,
                    color: theme.colorScheme.error,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Failed to load conversations',
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    chat.error!,
                    style: theme.textTheme.bodySmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: () => chat.loadConversations(),
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                  ),
                ],
              ),
            )
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: FilterChip(
                            label: Text('All (${whatsappConvs.length})'),
                            selected: _selectedFunnelStage == null,
                            onSelected: (_) => setState(() {
                              _selectedFunnelStage = null;
                              _selectedClosedReason = null;
                            }),
                          ),
                        ),
                        ...chatFunnelStages.map((stage) {
                          final count = whatsappConvs.where((conversation) {
                            final client =
                                clientsByPhone[normalizePhone(
                                  conversation.contactPhone,
                                )];
                            return client?.stage == stage;
                          }).length;
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: FilterChip(
                              avatar: Icon(
                                stage == _selectedFunnelStage
                                    ? Icons.check_circle
                                    : Icons.circle_outlined,
                                size: 17,
                                color: _funnelStageColor(stage),
                              ),
                              label: Text('${stage.displayName} ($count)'),
                              selected: _selectedFunnelStage == stage,
                              onSelected: (selected) => setState(() {
                                _selectedFunnelStage = selected ? stage : null;
                                _selectedClosedReason = null;
                              }),
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                ),
                if (_selectedFunnelStage == ClientStage.lost)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: SizedBox(
                        width: 360,
                        child: DropdownButtonFormField<String>(
                          initialValue: _selectedClosedReason ?? '',
                          decoration: const InputDecoration(
                            labelText: 'Closed reason',
                            prefixIcon: Icon(Icons.filter_alt_outlined),
                            isDense: true,
                          ),
                          items: [
                            DropdownMenuItem<String>(
                              value: '',
                              child: Text(
                                'All reasons (${_closedCount(whatsappConvs, clientsByPhone)})',
                              ),
                            ),
                            ..._closureReasons.keys.map((reason) {
                              final count = whatsappConvs.where((conversation) {
                                final client =
                                    clientsByPhone[normalizePhone(
                                      conversation.contactPhone,
                                    )];
                                return client?.stage == ClientStage.lost &&
                                    client?.closedReason == reason;
                              }).length;
                              return DropdownMenuItem<String>(
                                value: reason,
                                child: Text('$reason ($count)'),
                              );
                            }),
                          ],
                          onChanged: (value) => setState(
                            () => _selectedClosedReason =
                                value == null || value.isEmpty ? null : value,
                          ),
                        ),
                      ),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: TextField(
                    onChanged: (value) => setState(() => _searchQuery = value),
                    decoration: InputDecoration(
                      hintText: 'Search conversations...',
                      prefixIcon: const Icon(Icons.search, size: 20),
                      suffixIcon: _searchQuery.isEmpty
                          ? null
                          : IconButton(
                              icon: const Icon(Icons.close, size: 20),
                              tooltip: 'Clear search',
                              onPressed: () =>
                                  setState(() => _searchQuery = ''),
                            ),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 10),
                      filled: true,
                      fillColor: theme.colorScheme.surfaceContainerHighest,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: _ConversationList(
                    conversations: filteredConversations,
                    emptyIcon: Icons.chat_bubble_outline,
                    emptyText: 'No conversations in this funnel stage',
                    channelColor: const Color(0xFF25D366),
                    startingAutomation: _startingAutomation,
                    onStartAutomation: _startAutomation,
                    clients: clients,
                    onChangeStage: _changeClientStage,
                    onSetFollowUp: _showFollowUpSettings,
                  ),
                ),
              ],
            ),
    );
    // Removed the old appBar code
    // appBar: AppBar(
    //   title: Row(
    //     children: [
    //       const Text('Messages'),
    //       if (whatsappUnread > 0) ...[
    //         const SizedBox(width: 8),
    //         Container(
    //           padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    //           decoration: BoxDecoration(
    //             color: Colors.white.withAlpha(40),
    //             borderRadius: BorderRadius.circular(12),
    //           ),
    //           child: Text(
    //             '$whatsappUnread',
    //             style: const TextStyle(
    //               fontSize: 12,
    //               fontWeight: FontWeight.bold,
    //             ),
    //           ),
    //         ),
    //       ],
    //     ],
    //   ),
    //   elevation: 0,
    //   actions: [
    //     IconButton(
    //       icon: const Icon(Icons.search),
    //       onPressed: () =>
    //           setState(() => _searchQuery = _searchQuery.isEmpty ? ' ' : ''),
    //     ),
    //     IconButton(
    //       icon: const Icon(Icons.refresh),
    //       tooltip: 'Refresh',
    //       onPressed: () => chat.loadConversations(),
    //     ),
    //   ],
    //   bottom: _searchQuery.isNotEmpty
    //       ? PreferredSize(
    //           preferredSize: const Size.fromHeight(56),
    //           child: Padding(
    //             padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
    //             child: TextField(
    //               autofocus: true,
    //               onChanged: (v) => setState(() => _searchQuery = v),
    //               decoration: InputDecoration(
    //                 hintText: 'Search conversations...',
    //                 prefixIcon: const Icon(Icons.search, size: 20),
    //                 suffixIcon: IconButton(
    //                   icon: const Icon(Icons.close, size: 20),
    //                   onPressed: () => setState(() => _searchQuery = ''),
    //                 ),
    //                 isDense: true,
    //                 contentPadding: const EdgeInsets.symmetric(vertical: 8),
    //                 filled: true,
    //                 fillColor: theme.colorScheme.surfaceContainerHighest,
    //                 border: OutlineInputBorder(
    //                   borderRadius: BorderRadius.circular(24),
    //                   borderSide: BorderSide.none,
    //                 ),
    //               ),
    //             ),
    //           ),
    //         )
    //       : null,
    // ),
    /*      appBar: AppBar(
        title: Row(
          children: [
            const Text('Messages'),
            if (whatsappUnread > 0) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(40),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$whatsappUnread',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () =>
                setState(() => _searchQuery = _searchQuery.isEmpty ? ' ' : ''),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: () => chat.loadConversations(),
          ),
        ],
        bottom: _searchQuery.isNotEmpty
            ? PreferredSize(
                preferredSize: const Size.fromHeight(56),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: TextField(
                    autofocus: true,
                    onChanged: (v) => setState(() => _searchQuery = v),
                    decoration: InputDecoration(
                      hintText: 'Search conversations...',
                      prefixIcon: const Icon(Icons.search, size: 20),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.close, size: 20),
                        onPressed: () => setState(() => _searchQuery = ''),
                      ),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 8),
                      filled: true,
                      fillColor: theme.colorScheme.surfaceContainerHighest,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
              )
            : null,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showNewMessageSheet(context),
        backgroundColor: const Color(0xFF25D366),
        child: const Icon(Icons.message),
      ),
      body: chat.isLoading
          ? const Center(child: CircularProgressIndicator())
          : chat.error != null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 64,
                    color: theme.colorScheme.error,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Failed to load conversations',
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    chat.error!,
                    style: theme.textTheme.bodySmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: () => chat.loadConversations(),
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                  ),
                ],
              ),
            )
          : _ConversationList(
              conversations: _filterConversations(whatsappConvs),
              emptyIcon: Icons.chat_bubble_outline,
              emptyText: 'No WhatsApp conversations',
              channelColor: const Color(0xFF25D366),
                ),
              );*/
  }

  List<Conversation> _filterConversations(
    List<Conversation> conversations,
    Map<String, Client> clientsByPhone,
  ) {
    final q = _searchQuery.toLowerCase();
    return conversations.where((conversation) {
      final client = clientsByPhone[normalizePhone(conversation.contactPhone)];
      if (_selectedFunnelStage != null &&
          client?.stage != _selectedFunnelStage) {
        return false;
      }
      if (_selectedClosedReason != null &&
          client?.closedReason != _selectedClosedReason) {
        return false;
      }
      return q.trim().isEmpty ||
          conversation.contactName.toLowerCase().contains(q) ||
          conversation.contactPhone.contains(q) ||
          (conversation.lastMessage?.toLowerCase().contains(q) ?? false);
    }).toList();
  }

  Map<String, Client> _indexClientsByPhone(List<Client> clients) {
    final index = <String, Client>{};
    final duplicates = <String>{};
    for (final client in clients) {
      final phone = normalizePhone(client.contactPhone);
      if (phone.isEmpty || duplicates.contains(phone)) continue;
      if (index.containsKey(phone)) {
        index.remove(phone);
        duplicates.add(phone);
      } else {
        index[phone] = client;
      }
    }
    return index;
  }

  int _closedCount(
    List<Conversation> conversations,
    Map<String, Client> clientsByPhone,
  ) => conversations.where((conversation) {
    final client = clientsByPhone[normalizePhone(conversation.contactPhone)];
    return client?.stage == ClientStage.lost;
  }).length;

  Color _funnelStageColor(ClientStage stage) => switch (stage) {
    ClientStage.reach => Colors.orange,
    ClientStage.click => Colors.deepOrange,
    ClientStage.register => Colors.blue,
    ClientStage.consult => Colors.indigo,
    ClientStage.client => Colors.green,
    ClientStage.lost => Colors.red,
    _ => Colors.grey,
  };

  Future<void> _importLeads(List<Client> clients) async {
    final bytes = await pickLeadCsvBytes();
    if (bytes == null || !mounted) return;

    setState(() => _isTransferringLeads = true);
    try {
      final source = utf8.decode(bytes);
      final result = parseLeadCsv(source);
      final chat = ref.read(chatProvider);
      final firestore = ref.read(firestoreServiceProvider);
      final knownNumbers = <String>{
        ...clients.map((client) => normalizeLeadNumber(client.contactPhone)),
        ...chat.conversations.map(
          (conversation) => normalizeLeadNumber(conversation.contactPhone),
        ),
      }..remove('');
      final progress = ValueNotifier<_LeadImportProgress>(
        _LeadImportProgress(
          total:
              result.leads.length + result.invalidRows + result.duplicateRows,
          invalid: result.invalidRows,
          duplicateInFile: result.duplicateRows,
        ),
      );
      final progressDialog = showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (context) => _LeadImportProgressDialog(progress: progress),
      );

      for (final lead in result.leads) {
        final normalized = normalizeLeadNumber(lead.number);
        if (!knownNumbers.add(normalized)) {
          progress.value = progress.value.copyWith(
            alreadyExisted: progress.value.alreadyExisted + 1,
            currentNumber: normalized,
            existingNumbers: [...progress.value.existingNumbers, normalized],
          );
          continue;
        }

        final clientId = normalized;
        try {
          final created = await firestore.createClientIfAbsent(
            Client(
              id: clientId,
              name: lead.name,
              category: '',
              contactEmail: '',
              contactPhone: lead.number,
              stage: ClientStage.reach,
              createdDate: DateTime.now(),
              stageChangedAt: DateTime.now(),
            ),
          );
          if (!created) {
            progress.value = progress.value.copyWith(
              alreadyExisted: progress.value.alreadyExisted + 1,
              currentNumber: normalized,
              existingNumbers: [...progress.value.existingNumbers, normalized],
            );
            continue;
          }
          final conversation = await chat.createConversation(
            contactId: clientId,
            contactName: lead.name,
            contactPhone: lead.number,
            ownerClientId: clientId,
          );
          if (conversation == null) {
            await firestore.deleteClient(clientId);
            throw StateError(chat.error ?? 'Could not create chat');
          }
          progress.value = progress.value.copyWith(
            completed: progress.value.completed + 1,
            currentNumber: normalized,
          );
        } catch (_) {
          knownNumbers.remove(normalized);
          progress.value = progress.value.copyWith(
            failed: progress.value.failed + 1,
            currentNumber: normalized,
            failedNumbers: [...progress.value.failedNumbers, normalized],
          );
        }
      }

      ref.invalidate(clientsListProvider);
      chat.loadConversations();
      progress.value = progress.value.copyWith(done: true, currentNumber: '');
      await progressDialog;
      progress.dispose();
    } on FormatException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Import failed: $error')));
      }
    } finally {
      if (mounted) setState(() => _isTransferringLeads = false);
    }
  }

  Future<void> _exportLeads(
    List<Client> clients,
    List<Conversation> conversations,
  ) async {
    final leadsByNumber = <String, LeadCsvRow>{};
    for (final client in clients) {
      final number = normalizeLeadNumber(client.contactPhone);
      if (number.isNotEmpty) {
        leadsByNumber[number] = LeadCsvRow(
          name: client.name,
          number: client.contactPhone,
        );
      }
    }
    for (final conversation in conversations) {
      final number = normalizeLeadNumber(conversation.contactPhone);
      if (number.isNotEmpty) {
        leadsByNumber.putIfAbsent(
          number,
          () => LeadCsvRow(
            name: conversation.contactName,
            number: conversation.contactPhone,
          ),
        );
      }
    }

    if (leadsByNumber.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No names and numbers to export.')),
      );
      return;
    }

    setState(() => _isTransferringLeads = true);
    try {
      final content = encodeLeadCsv(leadsByNumber.values);
      final date = DateTime.now().toIso8601String().substring(0, 10);
      await saveLeadCsv(
        'chat-leads-$date.csv',
        Uint8List.fromList(utf8.encode(content)),
      );
    } finally {
      if (mounted) setState(() => _isTransferringLeads = false);
    }
  }

  Future<void> _startAutomation(Conversation conversation) async {
    setState(() => _startingAutomation.add(conversation.id));
    try {
      await ref.read(chatProvider).startQualificationAutomation(conversation);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Automation started for ${conversation.contactName}'),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not start automation: $error')),
      );
    } finally {
      if (mounted) setState(() => _startingAutomation.remove(conversation.id));
    }
  }

  Future<void> _changeClientStage(Client client, ClientStage stage) async {
    if (stage == client.stage) return;

    var updatedClient = client.copyWith(
      stage: stage,
      stageChangedAt: DateTime.now(),
      clearClosedDetails: stage != ClientStage.lost,
    );
    _QualifiedStageData? qualification;

    if (stage == ClientStage.consult) {
      qualification = await showDialog<_QualifiedStageData>(
        context: context,
        builder: (context) => _QualificationDialog(client: client),
      );
      if (qualification == null || !mounted) return;
      updatedClient = updatedClient.copyWith(
        intentConfirmed: true,
        roleConfirmed: true,
        decisionMakerRole: qualification.decisionMakerRole,
        packageTier: qualification.packageTier,
        followUpAt: DateTime.now().add(const Duration(days: 3)),
        followUpNotes: 'Package sent; follow up on day 3-4',
      );
    } else if (stage == ClientStage.lost) {
      final closure = await showDialog<_ClosureData>(
        context: context,
        builder: (context) => const _CloseLeadDialog(),
      );
      if (closure == null || !mounted) return;
      updatedClient = updatedClient.copyWith(
        closedReason: closure.reason,
        closedSubReason: closure.subReason,
        closedNote: closure.note,
        clearClosedDetails: true,
        clearFollowUp: true,
      );
    } else if (stage == ClientStage.client) {
      final paymentConfirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Confirm payment'),
          content: const Text(
            'Mark this lead as Won only after payment has been received.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Payment received'),
            ),
          ],
        ),
      );
      if (paymentConfirmed != true || !mounted) return;
      updatedClient = updatedClient.copyWith(clearFollowUp: true);
    } else if (stage == ClientStage.register) {
      updatedClient = updatedClient.copyWith(
        followUpAt: DateTime.now(),
        followUpNotes: 'Reply received; call now or schedule next call',
      );
    }

    try {
      await ref.read(firestoreServiceProvider).updateClient(updatedClient);

      if (qualification != null) {
        await _sendPackageMessage(client, qualification);
      }
      ref.invalidate(clientsListProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${client.name} moved to ${stage.displayName}'),
          ),
        );
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not update funnel stage: $error')),
      );
    }
  }

  Future<void> _sendPackageMessage(
    Client client,
    _QualifiedStageData qualification,
  ) async {
    final conversations = ref.read(chatProvider).conversations;
    final conversation = conversations
        .where(
          (item) =>
              normalizePhone(item.contactPhone) ==
              normalizePhone(client.contactPhone),
        )
        .firstOrNull;
    if (conversation == null) return;

    await ref
        .read(chatProvider)
        .sendMessageToConversation(
          conversation,
          'Thank you for your time. Here are the details for the '
          '${qualification.packageTier} package: '
          'https://tulasisolutions.com/pricing',
        );
  }

  Future<void> _showFollowUpSettings(Client client) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) =>
          FollowUpSettingsDialog(client: client, ref: ref),
    );
    ref.invalidate(clientsListProvider);
  }

  Future<void> _addChatsToFunnel(
    List<Conversation> conversations,
    List<Client> clients,
  ) async {
    final knownPhones = clients
        .map((client) => _lastTenDigits(client.contactPhone))
        .where((phone) => phone.isNotEmpty)
        .toSet();
    var createdLead = false;

    for (final conversation in conversations) {
      final phone = _lastTenDigits(conversation.contactPhone);
      if (phone.isEmpty ||
          knownPhones.contains(phone) ||
          _createdFunnelPhones.contains(phone)) {
        continue;
      }

      _createdFunnelPhones.add(phone);
      try {
        await ref
            .read(firestoreServiceProvider)
            .createClient(
              Client(
                id: const Uuid().v4(),
                name: conversation.contactName.trim().isEmpty
                    ? phone
                    : conversation.contactName.trim(),
                ownerName: null,
                category: '',
                contactEmail: '',
                contactPhone: phone,
                alternatePhone: null,
                stage: conversation.lastMessageAt == null
                    ? ClientStage.reach
                    : ClientStage.click,
                createdDate: DateTime.now(),
                stageChangedAt: conversation.lastMessageAt ?? DateTime.now(),
              ),
            );
        knownPhones.add(phone);
        createdLead = true;
      } catch (_) {
        _createdFunnelPhones.remove(phone);
      }
    }

    if (createdLead) ref.invalidate(clientsListProvider);
  }

  String _lastTenDigits(String value) => normalizePhone(value);

  void _showNewMessageSheet(BuildContext context) {
    // TODO: Load contacts from your contact service
    // For now, show a placeholder
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.chat, size: 48, color: Color(0xFF25D366)),
            const SizedBox(height: 16),
            const Text(
              'New WhatsApp Chat',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'To start a new conversation, you\'ll need to add contacts first.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Got it'),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Conversation list ─────────────────────────────────────────

class _ConversationList extends StatelessWidget {
  final List<Conversation> conversations;
  final List<Client> clients;
  final IconData emptyIcon;
  final String emptyText;
  final Color channelColor;
  final Set<String> startingAutomation;
  final Future<void> Function(Conversation) onStartAutomation;
  final Future<void> Function(Client, ClientStage) onChangeStage;
  final Future<void> Function(Client) onSetFollowUp;

  const _ConversationList({
    required this.conversations,
    required this.clients,
    required this.emptyIcon,
    required this.emptyText,
    required this.channelColor,
    required this.startingAutomation,
    required this.onStartAutomation,
    required this.onChangeStage,
    required this.onSetFollowUp,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (conversations.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(emptyIcon, size: 64, color: channelColor.withAlpha(60)),
            const SizedBox(height: 16),
            Text(
              emptyText,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Tap + to start a new conversation',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: conversations.length,
      itemBuilder: (context, i) {
        final c = conversations[i];
        return _ConversationTile(
          conversation: c,
          client: _findClient(c),
          channelColor: channelColor,
          isStartingAutomation: startingAutomation.contains(c.id),
          onStartAutomation: () => onStartAutomation(c),
          onChangeStage: onChangeStage,
          onSetFollowUp: onSetFollowUp,
        );
      },
    );
  }

  Client? _findClient(Conversation conversation) =>
      findClientByPhone(conversation.contactPhone, clients);
}

String normalizePhone(String value) {
  final digits = value.replaceAll(RegExp(r'\D'), '');
  if (digits.length < 10) return '';
  return digits.substring(digits.length - 10);
}

Client? findClientByPhone(String phone, List<Client> clients) {
  final normalizedPhone = normalizePhone(phone);
  if (normalizedPhone.isEmpty) return null;

  final matches = clients
      .where((client) => normalizePhone(client.contactPhone) == normalizedPhone)
      .toList();
  return matches.length == 1 ? matches.single : null;
}

String formatConversationTimestamp(DateTime? dt, {DateTime? now}) {
  if (dt == null) return '';

  final referenceNow = now ?? DateTime.now();
  final today = DateTime(
    referenceNow.year,
    referenceNow.month,
    referenceNow.day,
  );
  final messageDay = DateTime(dt.year, dt.month, dt.day);

  if (messageDay == today || dt.isAfter(referenceNow)) {
    final h = dt.hour == 0
        ? 12
        : dt.hour > 12
        ? dt.hour - 12
        : dt.hour;
    final m = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    return '$h:$m $period';
  }

  final diffDays = today.difference(messageDay).inDays;
  if (diffDays == 1) return 'Yesterday';
  if (diffDays < 7) {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return days[dt.weekday - 1];
  }

  return '${dt.day}/${dt.month}/${dt.year}';
}

String formatConversationWindow(DateTime? lastActivityAt, {DateTime? now}) {
  if (lastActivityAt == null) return 'No activity';

  final expiresAt = lastActivityAt.add(const Duration(hours: 24));
  final remaining = expiresAt.difference(now ?? DateTime.now());
  if (remaining <= Duration.zero) return 'Expired';

  final hours = remaining.inHours;
  final minutes = remaining.inMinutes.remainder(60);
  return '${hours}h ${minutes}m';
}

class _ConversationTile extends StatelessWidget {
  final Conversation conversation;
  final Client? client;
  final Color channelColor;
  final bool isStartingAutomation;
  final Future<void> Function() onStartAutomation;
  final Future<void> Function(Client, ClientStage) onChangeStage;
  final Future<void> Function(Client) onSetFollowUp;

  const _ConversationTile({
    required this.conversation,
    required this.client,
    required this.channelColor,
    required this.isStartingAutomation,
    required this.onStartAutomation,
    required this.onChangeStage,
    required this.onSetFollowUp,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = conversation;
    final hasUnread = c.unreadCount > 0;

    return InkWell(
      onTap: () => context.push('/chat/${c.id}', extra: c),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: hasUnread ? channelColor.withAlpha(8) : null,
          border: Border(
            bottom: BorderSide(color: theme.dividerColor.withAlpha(40)),
          ),
        ),
        child: Row(
          children: [
            // Avatar
            Stack(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: channelColor.withAlpha(25),
                  child: Text(
                    c.contactName.isNotEmpty
                        ? c.contactName[0].toUpperCase()
                        : '?',
                    style: TextStyle(
                      color: channelColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      color: channelColor,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: theme.colorScheme.surface,
                        width: 2,
                      ),
                    ),
                    child: Icon(
                      c.channel == ConversationChannel.whatsapp
                          ? Icons.chat
                          : Icons.sms,
                      size: 8,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 14),
            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          c.contactPhone.trim().isEmpty
                              ? c.contactName
                              : '${c.contactName} · ${c.contactPhone}',
                          style: TextStyle(
                            fontWeight: hasUnread
                                ? FontWeight.bold
                                : FontWeight.w500,
                            fontSize: 15,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        _formatTime(c.lastMessageAt),
                        style: TextStyle(
                          fontSize: 11,
                          color: hasUnread
                              ? channelColor
                              : theme.colorScheme.onSurfaceVariant,
                          fontWeight: hasUnread
                              ? FontWeight.w600
                              : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          c.lastMessage ?? 'No messages yet',
                          style: TextStyle(
                            fontSize: 13,
                            color: hasUnread
                                ? theme.colorScheme.onSurface
                                : theme.colorScheme.onSurfaceVariant,
                            fontWeight: hasUnread
                                ? FontWeight.w500
                                : FontWeight.normal,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (client != null) ...[
                        const SizedBox(width: 8),
                        PopupMenuButton<ClientStage>(
                          tooltip: 'Change funnel stage',
                          onSelected: (stage) => onChangeStage(client!, stage),
                          itemBuilder: (context) => chatFunnelStages
                              .map(
                                (stage) => PopupMenuItem(
                                  value: stage,
                                  child: Row(
                                    children: [
                                      Icon(
                                        stage == client!.stage
                                            ? Icons.check_circle
                                            : Icons.circle_outlined,
                                        size: 18,
                                        color: _stageColor(stage),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(stage.displayName),
                                    ],
                                  ),
                                ),
                              )
                              .toList(),
                          child: StageChip(
                            label: client!.stage.displayName,
                            backgroundColor: _stageColor(
                              client!.stage,
                            ).withValues(alpha: 0.2),
                            textColor: _stageColor(client!.stage),
                          ),
                        ),
                        IconButton(
                          tooltip: client!.followUpAt == null
                              ? 'Set follow-up'
                              : 'Edit follow-up',
                          onPressed: () => onSetFollowUp(client!),
                          icon: Icon(
                            client!.followUpAt == null
                                ? Icons.alarm_add_outlined
                                : Icons.alarm_on_outlined,
                            color: client!.followUpAt == null
                                ? theme.colorScheme.onSurfaceVariant
                                : Colors.green,
                            size: 20,
                          ),
                        ),
                      ],
                      if (hasUnread)
                        Semantics(
                          label:
                              '${c.unreadCount} unread ${c.unreadCount == 1 ? 'message' : 'messages'}',
                          child: Container(
                            margin: const EdgeInsets.only(left: 8),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 3,
                            ),
                            constraints: const BoxConstraints(minWidth: 22),
                            decoration: BoxDecoration(
                              color: channelColor,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '${c.unreadCount}',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  if (c.channel == ConversationChannel.whatsapp) ...[
                    const SizedBox(height: 4),
                    _FunnelReminderChip(
                      client: client,
                      lastActivityAt: c.lastMessageAt,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 4),
            SizedBox(
              width: 40,
              height: 40,
              child: IconButton(
                tooltip: 'Call ${c.contactPhone}',
                onPressed: () => _openDialer(context),
                icon: const Icon(
                  Icons.phone_in_talk_outlined,
                  color: Color(0xFF16863E),
                ),
              ),
            ),
            SizedBox(
              width: 40,
              height: 40,
              child: IconButton(
                tooltip: 'Start automation test',
                onPressed: isStartingAutomation ? null : onStartAutomation,
                icon: isStartingAutomation
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(
                        Icons.play_circle_outline_rounded,
                        color: channelColor,
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openDialer(BuildContext context) async {
    final phone = conversation.contactPhone.trim();
    if (phone.replaceAll(RegExp(r'\D'), '').isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This conversation has no phone number.')),
      );
      return;
    }

    final opened = await launchUrl(Uri(scheme: 'tel', path: phone));
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to open the phone dialer.')),
      );
    }
  }

  Color _stageColor(ClientStage stage) => switch (stage) {
    ClientStage.reach => Colors.orange,
    ClientStage.click => Colors.deepOrange,
    ClientStage.register => Colors.blue,
    ClientStage.consult => Colors.indigo,
    ClientStage.followUp => Colors.purple,
    ClientStage.client => Colors.green,
    ClientStage.retain => Colors.teal,
    ClientStage.refer => Colors.pink,
    ClientStage.lost => Colors.red,
  };

  String _formatTime(DateTime? dt) => formatConversationTimestamp(dt);
}

class _FunnelReminderChip extends StatefulWidget {
  final Client? client;
  final DateTime? lastActivityAt;

  const _FunnelReminderChip({
    required this.client,
    required this.lastActivityAt,
  });

  @override
  State<_FunnelReminderChip> createState() => _FunnelReminderChipState();
}

class _FunnelReminderChipState extends State<_FunnelReminderChip> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reminder = funnelReminderLabel(widget.client, widget.lastActivityAt);
    final color = reminder.isDue
        ? Colors.orange.shade800
        : const Color(0xFF16863E);
    return Semantics(
      label: reminder.label,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              reminder.isDue
                  ? Icons.notification_important_outlined
                  : Icons.schedule,
              size: 12,
              color: color,
            ),
            const SizedBox(width: 4),
            Text(
              reminder.label,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class FunnelReminder {
  final String label;
  final bool isDue;

  const FunnelReminder(this.label, {this.isDue = false});
}

FunnelReminder funnelReminderLabel(
  Client? client,
  DateTime? lastActivityAt, {
  DateTime? now,
}) {
  if (client == null) return const FunnelReminder('Not linked to funnel');
  final current = now ?? DateTime.now();
  final since = client.stageChangedAt ?? lastActivityAt ?? client.createdDate;
  final days = current.difference(since).inDays;
  if (client.stage == ClientStage.click) {
    if (days >= 8) {
      return const FunnelReminder('Ready to close: No Response', isDue: true);
    }
    if (days >= 7) {
      return const FunnelReminder('Final message due', isDue: true);
    }
    if (days >= 3) return const FunnelReminder('Nudge #2 due', isDue: true);
    return FunnelReminder('Nudge #2 on day ${3 - days}');
  }
  if (client.stage == ClientStage.consult) {
    if (days >= 15) return const FunnelReminder('Ready to close', isDue: true);
    if (days >= 12) {
      return const FunnelReminder('Close-or-drop follow-up due', isDue: true);
    }
    if (days >= 7) {
      return const FunnelReminder('Demo follow-up due', isDue: true);
    }
    if (days >= 3) {
      return const FunnelReminder('Package follow-up due', isDue: true);
    }
    return FunnelReminder('Package follow-up on day ${3 - days}');
  }
  if (client.followUpAt != null) {
    final daysUntilFollowUp = client.followUpAt!.difference(current).inDays;
    if (client.followUpAt!.isBefore(current)) {
      return const FunnelReminder('Follow-up due', isDue: true);
    }
    return FunnelReminder(
      daysUntilFollowUp <= 0
          ? 'Follow-up today'
          : 'Follow-up in $daysUntilFollowUp day${daysUntilFollowUp == 1 ? '' : 's'}',
    );
  }
  if (client.stage == ClientStage.register) {
    return const FunnelReminder('Call now or set next call', isDue: true);
  }
  if (client.stage == ClientStage.reach) {
    return const FunnelReminder('Ready to send');
  }
  if (client.stage == ClientStage.client) return const FunnelReminder('Won');
  if (client.stage == ClientStage.lost) {
    return FunnelReminder(
      'Closed: ${client.closedReason ?? 'Reason required'}',
    );
  }
  return const FunnelReminder('No action scheduled');
}

class _QualifiedStageData {
  final String decisionMakerRole;
  final String packageTier;

  const _QualifiedStageData(this.decisionMakerRole, this.packageTier);
}

class _QualificationDialog extends StatefulWidget {
  final Client client;

  const _QualificationDialog({required this.client});

  @override
  State<_QualificationDialog> createState() => _QualificationDialogState();
}

class _QualificationDialogState extends State<_QualificationDialog> {
  bool _intentConfirmed = false;
  bool _roleConfirmed = false;
  String _role = 'Owner';
  final _packageController = TextEditingController();

  @override
  void dispose() {
    _packageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final canQualify =
        _intentConfirmed &&
        _roleConfirmed &&
        _role != 'Manager - no authority' &&
        _role != 'Wrong person / staff' &&
        _packageController.text.trim().isNotEmpty;
    return AlertDialog(
      title: const Text('Qualify lead'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: _intentConfirmed,
              title: const Text('Intent confirmed'),
              subtitle: const Text(
                'Asked about packages/details or agreed to follow up',
              ),
              onChanged: (value) =>
                  setState(() => _intentConfirmed = value ?? false),
            ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: _roleConfirmed,
              title: const Text('Role confirmed'),
              onChanged: (value) =>
                  setState(() => _roleConfirmed = value ?? false),
            ),
            DropdownButtonFormField<String>(
              initialValue: _role,
              decoration: const InputDecoration(
                labelText: 'Decision-maker role',
              ),
              items:
                  const [
                        'Owner',
                        'Manager - authorized',
                        'Manager - no authority',
                        'Wrong person / staff',
                      ]
                      .map(
                        (role) =>
                            DropdownMenuItem(value: role, child: Text(role)),
                      )
                      .toList(),
              onChanged: (value) => setState(() => _role = value ?? 'Owner'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _packageController,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                labelText: 'Package / tier pitched',
                hintText: 'Example: Growth package',
              ),
            ),
            if (_role == 'Manager - no authority' ||
                _role == 'Wrong person / staff')
              const Padding(
                padding: EdgeInsets.only(top: 12),
                child: Text(
                  'This role cannot be qualified. Get the owner contact or close the lead.',
                  style: TextStyle(color: Colors.red),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: canQualify
              ? () => Navigator.pop(
                  context,
                  _QualifiedStageData(_role, _packageController.text.trim()),
                )
              : null,
          child: const Text('Qualify and send package'),
        ),
      ],
    );
  }
}

class _ClosureData {
  final String reason;
  final String subReason;
  final String? note;

  const _ClosureData(this.reason, this.subReason, this.note);
}

const _closureReasons = <String, List<String>>{
  'No Response': [
    'No reply to any message',
    'Replied once, then went silent',
    "Read but didn't reply",
    'Call not picked up (multiple attempts)',
  ],
  'Not Interested': [
    "Doesn't see the need",
    'Too small a business',
    'Bad timing',
    "Doesn't trust digital solutions",
  ],
  'Lost': [
    'Price too high',
    'Chose a competitor',
    'Already has a solution',
    'Delayed too long, went cold',
    "Package didn't match need",
    'Trust/credibility concern',
    'Budget/timing',
  ],
  'Opted Out': ['Asked to stop', 'Reported/blocked'],
  'Invalid Number': [
    'Not on WhatsApp',
    'Wrong person',
    "Restaurant closed/doesn't exist",
  ],
  'Duplicate': ['Same lead already exists'],
  'Not a Fit': ['Outside target segment', 'Needs unavailable scope'],
};

class _CloseLeadDialog extends StatefulWidget {
  const _CloseLeadDialog();

  @override
  State<_CloseLeadDialog> createState() => _CloseLeadDialogState();
}

class _CloseLeadDialogState extends State<_CloseLeadDialog> {
  String? _reason;
  String? _subReason;
  final _noteController = TextEditingController();

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Close lead'),
    content: SizedBox(
      width: 420,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DropdownButtonFormField<String>(
            initialValue: _reason,
            decoration: const InputDecoration(labelText: 'Reason'),
            items: _closureReasons.keys
                .map(
                  (reason) =>
                      DropdownMenuItem(value: reason, child: Text(reason)),
                )
                .toList(),
            onChanged: (value) => setState(() {
              _reason = value;
              _subReason = null;
            }),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            key: ValueKey(_reason),
            initialValue: _subReason,
            decoration: const InputDecoration(labelText: 'Sub-reason'),
            items: (_closureReasons[_reason] ?? const <String>[])
                .map(
                  (reason) =>
                      DropdownMenuItem(value: reason, child: Text(reason)),
                )
                .toList(),
            onChanged: (value) => setState(() => _subReason = value),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _noteController,
            maxLines: 2,
            decoration: const InputDecoration(labelText: 'Note (optional)'),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: _reason != null && _subReason != null
            ? () => Navigator.pop(
                context,
                _ClosureData(
                  _reason!,
                  _subReason!,
                  _noteController.text.trim().isEmpty
                      ? null
                      : _noteController.text.trim(),
                ),
              )
            : null,
        child: const Text('Close lead'),
      ),
    ],
  );
}

class _LeadImportProgress {
  final int total;
  final int completed;
  final int alreadyExisted;
  final int duplicateInFile;
  final int failed;
  final int invalid;
  final String currentNumber;
  final List<String> existingNumbers;
  final List<String> failedNumbers;
  final bool done;

  const _LeadImportProgress({
    required this.total,
    this.completed = 0,
    this.alreadyExisted = 0,
    this.duplicateInFile = 0,
    this.failed = 0,
    this.invalid = 0,
    this.currentNumber = '',
    this.existingNumbers = const [],
    this.failedNumbers = const [],
    this.done = false,
  });

  int get processed =>
      completed + alreadyExisted + duplicateInFile + failed + invalid;

  _LeadImportProgress copyWith({
    int? completed,
    int? alreadyExisted,
    int? failed,
    String? currentNumber,
    List<String>? existingNumbers,
    List<String>? failedNumbers,
    bool? done,
  }) => _LeadImportProgress(
    total: total,
    completed: completed ?? this.completed,
    alreadyExisted: alreadyExisted ?? this.alreadyExisted,
    duplicateInFile: duplicateInFile,
    failed: failed ?? this.failed,
    invalid: invalid,
    currentNumber: currentNumber ?? this.currentNumber,
    existingNumbers: existingNumbers ?? this.existingNumbers,
    failedNumbers: failedNumbers ?? this.failedNumbers,
    done: done ?? this.done,
  );
}

class _LeadImportProgressDialog extends StatelessWidget {
  final ValueNotifier<_LeadImportProgress> progress;

  const _LeadImportProgressDialog({required this.progress});

  @override
  Widget build(BuildContext context) => ValueListenableBuilder(
    valueListenable: progress,
    builder: (context, value, _) {
      final fraction = value.total == 0 ? 1.0 : value.processed / value.total;
      return AlertDialog(
        title: Text(value.done ? 'Import completed' : 'Importing leads'),
        content: SizedBox(
          width: 440,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              LinearProgressIndicator(value: fraction.clamp(0, 1)),
              const SizedBox(height: 8),
              Text(
                '${value.processed} of ${value.total} checked'
                '${value.currentNumber.isEmpty ? '' : ' - ${value.currentNumber}'}',
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _ImportCountChip(
                    label: 'Completed',
                    count: value.completed,
                    color: Colors.green,
                  ),
                  _ImportCountChip(
                    label: 'Already existed',
                    count: value.alreadyExisted,
                    color: Colors.orange,
                  ),
                  _ImportCountChip(
                    label: 'Duplicate in file',
                    count: value.duplicateInFile,
                    color: Colors.amber.shade800,
                  ),
                  _ImportCountChip(
                    label: 'Failed',
                    count: value.failed,
                    color: Colors.red,
                  ),
                  _ImportCountChip(
                    label: 'Invalid',
                    count: value.invalid,
                    color: Colors.grey,
                  ),
                ],
              ),
              if (value.existingNumbers.isNotEmpty) ...[
                const SizedBox(height: 16),
                const Text(
                  'Already existed - not imported',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                _PhoneNumberList(numbers: value.existingNumbers),
              ],
              if (value.failedNumbers.isNotEmpty) ...[
                const SizedBox(height: 12),
                const Text(
                  'Failed numbers',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                _PhoneNumberList(numbers: value.failedNumbers),
              ],
            ],
          ),
        ),
        actions: [
          if (value.done)
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Done'),
            ),
        ],
      );
    },
  );
}

class _ImportCountChip extends StatelessWidget {
  final String label;
  final int count;
  final Color color;

  const _ImportCountChip({
    required this.label,
    required this.count,
    required this.color,
  });

  @override
  Widget build(BuildContext context) => Chip(
    avatar: CircleAvatar(
      backgroundColor: color,
      child: Text('$count', style: const TextStyle(color: Colors.white)),
    ),
    label: Text(label),
  );
}

class _PhoneNumberList extends StatelessWidget {
  final List<String> numbers;

  const _PhoneNumberList({required this.numbers});

  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(maxHeight: 110),
    padding: const EdgeInsets.all(8),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(6),
    ),
    child: SingleChildScrollView(child: SelectableText(numbers.join('\n'))),
  );
}

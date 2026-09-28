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
import 'send_error_explanation.dart';

enum _ChatActivityFilter { inbox, unread, archived }

class ConversationsScreen extends ConsumerStatefulWidget {
  const ConversationsScreen({super.key});

  @override
  ConsumerState<ConversationsScreen> createState() =>
      _ConversationsScreenState();
}

class _ConversationsScreenState extends ConsumerState<ConversationsScreen> {
  String _searchQuery = '';
  _ChatActivityFilter _activityFilter = _ChatActivityFilter.inbox;
  ClientStage? _selectedFunnelStage;
  String? _selectedClosedReason;
  bool _showDueOnly = false;
  final Set<String> _createdFunnelPhones = {};
  final Set<String> _selectedConversationKeys = {};
  bool _isTransferringLeads = false;
  bool _isSendingBatch = false;
  bool _isArchivingSelection = false;
  bool _isBatchPaused = false;
  bool _cancelBatchRequested = false;
  int _batchSize = 50;
  int _batchCompleted = 0;
  int _batchTotal = 0;
  String? _lastCampaignId;
  int _lastClientRefreshConversationCount = -1;
  Timer? _sendStatusRefreshTimer;

  @override
  void dispose() {
    _sendStatusRefreshTimer?.cancel();
    super.dispose();
  }

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
    final archivedWhatsappConvs = chat.archivedConversations
      .where((c) => c.channel == ConversationChannel.whatsapp)
      .toList();
    final clientsById = {for (final client in clients) client.id: client};
    final clientsByPhone = _indexClientsByPhone(clients);
    final stageConversationCounts = <String, int>{
      for (final stage in chatFunnelStages)
      stage.name: whatsappConvs
            .where((conversation) => conversationStage(conversation) == stage)
        .length,
    };
    final filteredConversations = _filterConversations(
      whatsappConvs,
      clientsById,
      clientsByPhone,
    );
    final filteredArchivedConversations = _filterConversations(
      archivedWhatsappConvs,
      clientsById,
      clientsByPhone,
    );
    final displayedConversations =
        _activityFilter == _ChatActivityFilter.archived
        ? filteredArchivedConversations
        : filteredConversations;
    final readyConversations = filteredConversations.where((conversation) {
      final client = _findConversationClient(
        conversation,
        clientsById,
        clientsByPhone,
      );
      if (client?.doNotContact == true ||
          isLeadSendInFlight(client?.lastSendStatus)) {
        return false;
      }
      if (conversation.stage == ClientStage.reach.name) return true;
      return _showDueOnly &&
          client != null &&
          client.stage != ClientStage.client &&
          client.stage != ClientStage.retain &&
          client.stage != ClientStage.lost &&
          funnelReminderLabel(client, conversation.lastMessageAt).isDue;
    }).toList();
    final selectableConversationKeys = readyConversations
        .map(conversationSelectionKey)
        .toSet();
    final campaignClients = _lastCampaignId == null
        ? const <Client>[]
        : clients
              .where((client) => client.lastCampaignId == _lastCampaignId)
              .toList();

    if (clientsAsync.hasValue) {
      _scheduleSendStatusRefresh(clients);
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await _addChatsToFunnel(whatsappConvs, clients);
      });
      final hasUnloadedOwners = whatsappConvs.any(
        (conversation) =>
            conversation.clientId.isNotEmpty &&
            !clientsById.containsKey(conversation.clientId),
      );
      if (hasUnloadedOwners &&
          _lastClientRefreshConversationCount != whatsappConvs.length) {
        _lastClientRefreshConversationCount = whatsappConvs.length;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) ref.invalidate(clientsListProvider);
        });
      }
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
          tooltip: 'Refresh leads and conversations',
          onPressed: () {
            ref.invalidate(clientsListProvider);
            chat.loadConversations();
          },
        ),
      ],
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showNewMessageSheet(context),
        backgroundColor: const Color(0xFF25D366),
        child: const Icon(Icons.message),
      ),
        body: chat.error != null && conversations.isEmpty
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
                    onPressed: () => chat.loadConversations(
                      stage: _selectedFunnelStage?.name,
                    ),
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                  ),
                ],
              ),
            )
          : Column(
              children: [
                if (chat.isLoading)
                  const LinearProgressIndicator(minHeight: 2),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          SegmentedButton<_ChatActivityFilter>(
                            segments: [
                              ButtonSegment(
                                value: _ChatActivityFilter.inbox,
                                icon: const Icon(Icons.inbox_outlined),
                                label: Text(
                                  'Inbox (${whatsappConvs.length})',
                                ),
                              ),
                              ButtonSegment(
                                value: _ChatActivityFilter.unread,
                                icon: const Icon(
                                  Icons.mark_email_unread_outlined,
                                ),
                                label: Text('Unread (${chat.totalUnread})'),
                              ),
                              ButtonSegment(
                                value: _ChatActivityFilter.archived,
                                icon: const Icon(Icons.archive_outlined),
                                label: Text(
                                  'Archived (${archivedWhatsappConvs.length})',
                                ),
                              ),
                            ],
                            selected: {_activityFilter},
                            onSelectionChanged: (selection) {
                              setState(() {
                                _activityFilter = selection.first;
                                _showDueOnly = false;
                                _selectedConversationKeys.clear();
                              });
                            },
                          ),
                          const SizedBox(width: 12),
                          SizedBox(
                            width: 360,
                            child: DropdownButtonFormField<ClientStage?>(
                              initialValue: _selectedFunnelStage,
                              decoration: const InputDecoration(
                                labelText: 'Funnel',
                                prefixIcon: Icon(Icons.filter_alt_outlined),
                                isDense: true,
                              ),
                              items: [
                                DropdownMenuItem<ClientStage?>(
                                  value: null,
                                  child: Text(
                                    'Any stage (${whatsappConvs.length})',
                                  ),
                                ),
                                ...[
                                  ClientStage.click,
                                  ...chatFunnelStages.where(
                                    (stage) => stage != ClientStage.click,
                                  ),
                                ].map((stage) {
                                  final count =
                                      stageConversationCounts[stage.name];
                                  return DropdownMenuItem<ClientStage?>(
                                    value: stage,
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.circle_outlined,
                                          size: 17,
                                          color: _funnelStageColor(stage),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          '${stage.displayName} (${count ?? 0})',
                                        ),
                                      ],
                                    ),
                                  );
                                }),
                              ],
                              onChanged: (stage) => setState(() {
                                _selectedFunnelStage = stage;
                                _selectedClosedReason = null;
                                _showDueOnly = false;
                              }),
                            ),
                          ),
                        ],
                      ),
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
                if (_selectedFunnelStage == ClientStage.reach || _showDueOnly)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                    child: Wrap(
                      spacing: 12,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        OutlinedButton.icon(
                          onPressed: _isSendingBatch || _isArchivingSelection
                              ? null
                              : () => _toggleReadySelection(readyConversations),
                          icon: Icon(
                            _selectedConversationKeys.isEmpty
                                ? Icons.select_all
                                : Icons.deselect,
                          ),
                          label: Text(
                            _selectedConversationKeys.isEmpty
                                ? 'Select up to $_batchSize'
                                : 'Clear selection',
                          ),
                        ),
                        Tooltip(
                          message: 'Batch size',
                          child: DropdownButton<int>(
                            value: _batchSize,
                            items: const [25, 50, 100]
                                .map(
                                  (size) => DropdownMenuItem(
                                    value: size,
                                    child: Text('$size per batch'),
                                  ),
                                )
                                .toList(),
                            onChanged: _isSendingBatch || _isArchivingSelection
                                ? null
                                : (value) => setState(() {
                                    _batchSize = value ?? 50;
                                    if (_selectedConversationKeys.length >
                                        _batchSize) {
                                      final retained = _selectedConversationKeys
                                          .take(_batchSize)
                                          .toSet();
                                      _selectedConversationKeys
                                        ..clear()
                                        ..addAll(retained);
                                    }
                                  }),
                          ),
                        ),
                        Text('${_selectedConversationKeys.length} selected'),
                        if (_isSendingBatch) ...[
                          Text('Queueing $_batchCompleted/$_batchTotal'),
                          OutlinedButton.icon(
                            onPressed: _toggleBatchPaused,
                            icon: Icon(
                              _isBatchPaused ? Icons.play_arrow : Icons.pause,
                            ),
                            label: Text(_isBatchPaused ? 'Resume' : 'Pause'),
                          ),
                          TextButton.icon(
                            onPressed: _stopBatch,
                            icon: const Icon(Icons.stop_circle_outlined),
                            label: const Text('Stop'),
                          ),
                        ] else ...[
                          OutlinedButton.icon(
                            onPressed:
                                _selectedConversationKeys.isEmpty ||
                                    _isArchivingSelection
                                ? null
                                : () => _archiveSelected(readyConversations),
                            icon: _isArchivingSelection
                                ? const SizedBox.square(
                                    dimension: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.archive_outlined),
                            label: const Text('Archive selected'),
                          ),
                          FilledButton.icon(
                            onPressed:
                                _selectedConversationKeys.isEmpty ||
                                    _isArchivingSelection
                                ? null
                                : () => _sendSelectedBatch(
                                    readyConversations,
                                    clientsByPhone,
                                  ),
                            icon: const Icon(Icons.send_outlined),
                            label: const Text('Send selected'),
                          ),
                        ],
                        if (campaignClients.isNotEmpty)
                          Text(_campaignSummary(campaignClients)),
                      ],
                    ),
                  ),
                Expanded(
                  child: _ConversationList(
                    conversations: displayedConversations,
                    emptyIcon: Icons.chat_bubble_outline,
                    emptyText: switch (_activityFilter) {
                      _ChatActivityFilter.inbox => 'No conversations',
                      _ChatActivityFilter.unread => 'No unread conversations',
                      _ChatActivityFilter.archived =>
                        'No archived conversations',
                    },
                    channelColor: const Color(0xFF25D366),
                    clients: clients,
                    onChangeStage: _changeConversationStage,
                    onSetFollowUp: _showFollowUpSettings,
                    selectionEnabled:
                        _selectedFunnelStage == ClientStage.reach ||
                        _showDueOnly,
                    selectableConversationKeys: selectableConversationKeys,
                    selectedConversationKeys: _selectedConversationKeys,
                    onSelectionChanged: _setConversationSelected,
                    hasMore: chat.hasMoreConversations,
                    isLoadingMore: chat.isLoadingMore,
                    onLoadMore: chat.loadMoreConversations,
                    conversationsAreArchived:
                      _activityFilter == _ChatActivityFilter.archived,
                    onSetArchived: _setConversationArchived,
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

  void _scheduleSendStatusRefresh(List<Client> clients) {
    final hasInFlightSend = clients.any(
      (client) => isLeadSendInFlight(client.lastSendStatus),
    );
    if (!hasInFlightSend) {
      _sendStatusRefreshTimer?.cancel();
      _sendStatusRefreshTimer = null;
      return;
    }
    if (_sendStatusRefreshTimer?.isActive == true) return;
    _sendStatusRefreshTimer = Timer(const Duration(seconds: 3), () {
      _sendStatusRefreshTimer = null;
      if (mounted) ref.invalidate(clientsListProvider);
    });
  }

  List<Conversation> _filterConversations(
    List<Conversation> conversations,
    Map<String, Client> clientsById,
    Map<String, Client> clientsByPhone,
  ) {
    final q = _searchQuery.toLowerCase();
    return conversations.where((conversation) {
      if (_activityFilter == _ChatActivityFilter.unread &&
          conversation.unreadCount <= 0) {
        return false;
      }
      if (_selectedFunnelStage != null &&
          conversation.stage != _selectedFunnelStage!.name) {
        return false;
      }
      final client = _findConversationClient(
        conversation,
        clientsById,
        clientsByPhone,
      );
      if (_selectedClosedReason != null &&
          client?.closedReason != _selectedClosedReason) {
        return false;
      }
      if (_showDueOnly &&
          !funnelReminderLabel(client, conversation.lastMessageAt).isDue) {
        return false;
      }
      return q.trim().isEmpty ||
          conversation.contactName.toLowerCase().contains(q) ||
          conversation.contactPhone.contains(q) ||
          (conversation.lastMessage?.toLowerCase().contains(q) ?? false);
    }).toList();
  }

  Client? _findConversationClient(
    Conversation conversation,
    Map<String, Client> clientsById,
    Map<String, Client> clientsByPhone,
  ) {
    final owner = clientsById[conversation.clientId];
    return owner ?? clientsByPhone[normalizePhone(conversation.contactPhone)];
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
    ClientStage.retain => Colors.teal,
    ClientStage.lost => Colors.red,
    _ => Colors.grey,
  };

  Future<void> _importLeads(List<Client> clients) async {
    final bytes = await pickLeadCsvBytes();
    if (bytes == null || !mounted) return;

    setState(() => _isTransferringLeads = true);
    try {
      final result = parseLeadFile(bytes);
      final chat = ref.read(chatProvider);
      final knownNumbers = <String>{
        ...clients.map((client) => normalizeLeadNumber(client.contactPhone)),
        ...chat.conversations.map(
          (conversation) => normalizeLeadNumber(conversation.contactPhone),
        ),
      }..remove('');
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => _LeadImportPreviewDialog(
          result: result,
          knownNumbers: knownNumbers,
        ),
      );
      if (confirmed != true || !mounted) return;
      final firestore = ref.read(firestoreServiceProvider);
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
              clientCode: lead.code,
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
          code: client.clientCode,
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

  void _toggleReadySelection(List<Conversation> conversations) {
    setState(() {
      if (_selectedConversationKeys.isNotEmpty) {
        _selectedConversationKeys.clear();
        return;
      }
      _selectedConversationKeys.addAll(
        conversations.take(_batchSize).map(conversationSelectionKey),
      );
    });
  }

  void _setConversationSelected(Conversation conversation, bool selected) {
    final key = conversationSelectionKey(conversation);
    setState(() {
      if (selected) {
        if (_selectedConversationKeys.length >= _batchSize) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('This batch can contain up to $_batchSize leads.'),
            ),
          );
          return;
        }
        _selectedConversationKeys.add(key);
      } else {
        _selectedConversationKeys.remove(key);
      }
    });
  }

  Future<void> _archiveSelected(List<Conversation> conversations) async {
    final selected = conversations
        .where(
          (conversation) => _selectedConversationKeys.contains(
            conversationSelectionKey(conversation),
          ),
        )
        .take(_batchSize)
        .toList();
    if (selected.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Archive selected conversations?'),
        content: Text(
          '${selected.length} conversations will move to Archived.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.archive_outlined),
            label: const Text('Archive'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _isArchivingSelection = true);
    try {
      await ref
          .read(chatProvider)
          .updateConversationsArchive(
            conversations: selected,
            isArchived: true,
          );
      if (!mounted) return;
      setState(() => _selectedConversationKeys.clear());
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${selected.length} conversations archived')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not archive selection: $error')),
      );
    } finally {
      if (mounted) setState(() => _isArchivingSelection = false);
    }
  }

  Future<void> _toggleBatchPaused() async {
    final paused = !_isBatchPaused;
    setState(() => _isBatchPaused = paused);
    final campaignId = _lastCampaignId;
    final msg91 = ref.read(chatProvider).msg91Service;
    if (campaignId == null || msg91 == null) return;
    try {
      await msg91.updateOutreachCampaignStatus(
        campaignId: campaignId,
        status: paused ? 'paused' : 'running',
      );
    } catch (_) {}
  }

  Future<void> _stopBatch() async {
    setState(() {
      _cancelBatchRequested = true;
      _isBatchPaused = false;
    });
    final campaignId = _lastCampaignId;
    final msg91 = ref.read(chatProvider).msg91Service;
    if (campaignId == null || msg91 == null) return;
    try {
      await msg91.updateOutreachCampaignStatus(
        campaignId: campaignId,
        status: 'cancelled',
      );
    } catch (_) {}
  }

  Future<void> _sendSelectedBatch(
    List<Conversation> readyConversations,
    Map<String, Client> clientsByPhone,
  ) async {
    final selected = readyConversations
        .where(
          (conversation) => _selectedConversationKeys.contains(
            conversationSelectionKey(conversation),
          ),
        )
        .take(_batchSize)
        .toList();
    if (selected.isEmpty) return;

    final msg91 = ref.read(chatProvider).msg91Service;
    if (msg91 == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Messaging service is unavailable.')),
      );
      return;
    }

    List<MessageTemplate> templates;
    try {
      templates = (await msg91.getTemplates(channel: 'whatsapp'))
          .where(
            (template) =>
                template.status.toLowerCase() == 'approved' &&
                template.content.trim().isNotEmpty,
          )
          .toList();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not load approved templates: $error')),
      );
      return;
    }
    if (!mounted) return;

    final choice = await showDialog<_BatchTemplateChoice>(
      context: context,
      builder: (context) => _BatchTemplateDialog(
        templates: templates,
        recipientCount: selected.length,
      ),
    );
    if (choice == null || !mounted) return;

    setState(() {
      _isSendingBatch = true;
      _isBatchPaused = false;
      _cancelBatchRequested = false;
      _batchCompleted = 0;
      _batchTotal = selected.length;
    });

    final campaignId = const Uuid().v4();
    setState(() => _lastCampaignId = campaignId);
    var queued = 0;
    var failed = 0;
    final queuedKeys = <String>{};
    for (final conversation in selected) {
      while (_isBatchPaused && !_cancelBatchRequested) {
        await Future<void>.delayed(const Duration(milliseconds: 200));
      }
      if (_cancelBatchRequested) break;
      try {
        await ref
            .read(chatProvider)
            .sendTemplateToConversation(
              conversation,
              choice.template,
              choice.valuesFor(conversation.contactName),
              campaignId: campaignId,
            );
        queued++;
        queuedKeys.add(conversationSelectionKey(conversation));
      } catch (error) {
        failed++;
        final client =
            clientsByPhone[normalizePhone(conversation.contactPhone)];
        if (client != null) {
          await ref
              .read(firestoreServiceProvider)
              .updateClient(
                client.copyWith(
                  lastSendStatus: 'failed',
                  lastSendError: error.toString(),
                  lastAttemptAt: DateTime.now(),
                  sendAttemptCount: client.sendAttemptCount + 1,
                  lastCampaignId: campaignId,
                ),
              );
        }
      } finally {
        if (mounted) setState(() => _batchCompleted++);
      }
    }

    try {
      await msg91.updateOutreachCampaignStatus(
        campaignId: campaignId,
        status: _cancelBatchRequested ? 'cancelled' : 'completed',
      );
    } catch (_) {
      // Queue results remain authoritative if campaign metadata fails.
    }

    ref.invalidate(clientsListProvider);
    if (!mounted) return;
    setState(() {
      _isSendingBatch = false;
      _isBatchPaused = false;
      _selectedConversationKeys.removeAll(queuedKeys);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$queued queued${failed == 0 ? '' : ', $failed failed'}'),
      ),
    );
  }

  String _campaignSummary(List<Client> clients) {
    int count(String status) =>
        clients.where((client) => client.lastSendStatus == status).length;
    final replied = clients
        .where(
          (client) => const {
            ClientStage.register,
            ClientStage.consult,
            ClientStage.client,
            ClientStage.retain,
          }.contains(client.stage),
        )
        .length;
    return 'Last batch: ${count('pending')} pending · '
        '${count('retrying')} retrying · ${count('sent')} sent · '
        '${count('delivered')} delivered · ${count('read')} read · '
        '$replied replied · ${count('failed')} failed';
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
        doNotContact: closure.reason == 'Opted Out',
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
      await ref
          .read(chatProvider)
          .updateClientConversationFilters(
            ownerClientId: client.id,
            stage: updatedClient.stage.name,
          );

      if (qualification != null) {
        await _sendPackageMessage(client, qualification);
      }
      ref.invalidate(clientsListProvider);
        await ref.read(chatProvider).loadConversations();
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

  Future<void> _changeConversationStage(
    Conversation conversation,
    Client? client,
    ClientStage stage,
  ) async {
    var resolvedClient = client;
    if (resolvedClient == null && conversation.clientId.isNotEmpty) {
      resolvedClient = await ref
          .read(firestoreServiceProvider)
          .getClient(conversation.clientId);
    }
    if (!mounted) return;

    if (resolvedClient != null) {
      await _changeClientStage(resolvedClient, stage);
      return;
    }

    final ownerClientId = conversation.clientId;
    if (ownerClientId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Conversation cannot be linked.')),
      );
      return;
    }

    try {
      await ref
          .read(firestoreServiceProvider)
          .createClient(
            Client(
              id: ownerClientId,
              name: conversation.contactName.trim().isEmpty
                  ? conversation.contactPhone
                  : conversation.contactName.trim(),
              ownerName: null,
              category: '',
              contactEmail: '',
              contactPhone: conversation.contactPhone,
              alternatePhone: null,
              stage: stage,
              createdDate: DateTime.now(),
              stageChangedAt: DateTime.now(),
            ),
          );
      await ref
          .read(chatProvider)
          .updateClientConversationFilters(
            ownerClientId: ownerClientId,
            stage: stage.name,
          );
      ref.invalidate(clientsListProvider);
        await ref.read(chatProvider).loadConversations();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Linked to ${stage.displayName}')),
        );
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not link funnel stage: $error')),
      );
    }
  }

  Future<void> _setConversationArchived(
    Conversation conversation,
    Client? client,
    bool isArchived,
  ) async {
    try {
      final ownerClientId = conversation.clientId;
      if (ownerClientId.isEmpty) {
        throw StateError('Conversation is not linked to a lead');
      }
      await ref
          .read(chatProvider)
          .updateClientConversationArchive(
            ownerClientId: ownerClientId,
            conversation: conversation,
            isArchived: isArchived,
          );
      if (mounted) {
        setState(() {
          _selectedClosedReason = null;
          _showDueOnly = false;
          _selectedConversationKeys.clear();
        });
      }
      ref.invalidate(clientsListProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            duration: const Duration(seconds: 1),
            content: Text(
              isArchived
                  ? '${conversation.contactName} archived'
                  : '${conversation.contactName} restored',
            ),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not update archive: $error')),
        );
      }
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
  final Future<void> Function(Conversation, Client?, ClientStage) onChangeStage;
  final Future<void> Function(Client) onSetFollowUp;
  final bool selectionEnabled;
  final Set<String> selectableConversationKeys;
  final Set<String> selectedConversationKeys;
  final void Function(Conversation, bool) onSelectionChanged;
  final bool hasMore;
  final bool isLoadingMore;
  final Future<void> Function() onLoadMore;
  final bool conversationsAreArchived;
  final Future<void> Function(Conversation, Client?, bool) onSetArchived;

  const _ConversationList({
    required this.conversations,
    required this.clients,
    required this.emptyIcon,
    required this.emptyText,
    required this.channelColor,
    required this.onChangeStage,
    required this.onSetFollowUp,
    required this.selectionEnabled,
    required this.selectableConversationKeys,
    required this.selectedConversationKeys,
    required this.onSelectionChanged,
    required this.hasMore,
    required this.isLoadingMore,
    required this.onLoadMore,
    required this.conversationsAreArchived,
    required this.onSetArchived,
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

    return NotificationListener<ScrollEndNotification>(
      onNotification: (notification) {
        if (hasMore &&
            !isLoadingMore &&
            notification.metrics.extentAfter < 300) {
          onLoadMore();
        }
        return false;
      },
      child: ListView.builder(
        itemCount: conversations.length + 1,
        itemBuilder: (context, i) {
          if (i == conversations.length) {
            if (hasMore && !isLoadingMore) {
              WidgetsBinding.instance.addPostFrameCallback((_) => onLoadMore());
            }
            return Padding(
              padding: const EdgeInsets.all(16),
              child: Center(
                child: isLoadingMore
                    ? const CircularProgressIndicator()
                    : hasMore
                    ? const SizedBox(height: 24)
                    : const Text('End of conversations'),
              ),
            );
          }
          final c = conversations[i];
          return _ConversationTile(
            conversation: c,
            client: _findClient(c),
            channelColor: channelColor,
            onChangeStage: onChangeStage,
            onSetFollowUp: onSetFollowUp,
            selectionEnabled:
                selectionEnabled &&
                selectableConversationKeys.contains(
                  conversationSelectionKey(c),
                ),
            selected: selectedConversationKeys.contains(
              conversationSelectionKey(c),
            ),
            onSelectionChanged: (selected) => onSelectionChanged(c, selected),
            onSetArchived: onSetArchived,
            archived: conversationsAreArchived,
          );
        },
      ),
    );
  }

  Client? _findClient(Conversation conversation) =>
      findClientForConversation(conversation, clients);
}

String normalizePhone(String value) {
  final digits = value.replaceAll(RegExp(r'\D'), '');
  if (digits.length < 10) return '';
  return digits.substring(digits.length - 10);
}

String conversationSelectionKey(Conversation conversation) =>
    '${conversation.clientId}/${conversation.id}';

bool isLeadSendInFlight(String? status) =>
    status == 'pending' || status == 'sending' || status == 'retrying';

Client? findClientByPhone(String phone, List<Client> clients) {
  final normalizedPhone = normalizePhone(phone);
  if (normalizedPhone.isEmpty) return null;

  final matches = clients
      .where((client) => normalizePhone(client.contactPhone) == normalizedPhone)
      .toList();
  return matches.length == 1 ? matches.single : null;
}

Client? findClientForConversation(
  Conversation conversation,
  List<Client> clients,
) {
  if (conversation.clientId.isNotEmpty) {
    for (final client in clients) {
      if (client.id == conversation.clientId) return client;
    }
  }
  return findClientByPhone(conversation.contactPhone, clients);
}

ClientStage conversationStage(Conversation conversation) {
  if (conversation.stage == 'refer') return ClientStage.retain;
  for (final stage in chatFunnelStages) {
    if (stage.name == conversation.stage) return stage;
  }
  return ClientStage.click;
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
  final Future<void> Function(Conversation, Client?, ClientStage) onChangeStage;
  final Future<void> Function(Client) onSetFollowUp;
  final Future<void> Function(Conversation, Client?, bool) onSetArchived;
  final bool archived;
  final bool selectionEnabled;
  final bool selected;
  final ValueChanged<bool> onSelectionChanged;

  const _ConversationTile({
    required this.conversation,
    required this.client,
    required this.channelColor,
    required this.onChangeStage,
    required this.onSetFollowUp,
    required this.onSetArchived,
    required this.archived,
    required this.selectionEnabled,
    required this.selected,
    required this.onSelectionChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = conversation;
    final hasUnread = c.unreadCount > 0;
    final displayedStage = conversationStage(c);

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
            if (selectionEnabled) ...[
              Checkbox(
                value: selected,
                onChanged: (value) => onSelectionChanged(value ?? false),
              ),
              const SizedBox(width: 4),
            ],
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
                      const SizedBox(width: 8),
                      PopupMenuButton<ClientStage>(
                        tooltip: client == null
                            ? 'Link to funnel stage'
                            : 'Change funnel stage',
                        onSelected: (stage) =>
                            onChangeStage(conversation, client, stage),
                        itemBuilder: (context) => chatFunnelStages
                            .map(
                              (stage) => PopupMenuItem(
                                value: stage,
                                child: Row(
                                  children: [
                                    Icon(
                                      stage == displayedStage
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
                          label: displayedStage.displayName,
                          backgroundColor: _stageColor(
                            displayedStage,
                          ).withValues(alpha: 0.2),
                          textColor: _stageColor(displayedStage),
                        ),
                      ),
                      if (client != null)
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
                      IconButton(
                        tooltip: archived
                            ? 'Restore conversation'
                            : 'Archive conversation',
                        onPressed: () =>
                            onSetArchived(conversation, client, !archived),
                        icon: Icon(
                          archived
                              ? Icons.unarchive_outlined
                              : Icons.archive_outlined,
                          size: 20,
                        ),
                      ),
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
                  if (client?.stage == ClientStage.reach &&
                      client?.lastSendStatus != null) ...[
                    const SizedBox(height: 4),
                    _LeadSendStatus(client: client!),
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

class _LeadSendStatus extends StatelessWidget {
  final Client client;

  const _LeadSendStatus({required this.client});

  @override
  Widget build(BuildContext context) {
    final failed = client.lastSendStatus == 'failed';
    final retrying = client.lastSendStatus == 'retrying';
    final explanation = failed || retrying
        ? explainSendError(client.lastSendError)
        : null;
    final color = failed ? Theme.of(context).colorScheme.error : Colors.orange;
    final label = failed
        ? 'Not sent: ${explanation!.title}. Tap for details.'
        : retrying
        ? 'Retry pending: ${explanation!.title}. Tap for details.'
        : client.lastSendStatus == 'pending'
        ? 'Queued for sending'
        : 'Last send: ${client.lastSendStatus}';
    return Row(
      children: [
        Icon(
          failed ? Icons.error_outline : Icons.schedule_send_outlined,
          size: 15,
          color: color,
        ),
        const SizedBox(width: 5),
        Expanded(
          child: explanation == null
              ? Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: color, fontSize: 12),
                )
              : InkWell(
                  onTap: () =>
                      showSendErrorExplanationDialog(context, explanation),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Text(
                      label,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: color,
                        fontSize: 12,
                        decoration: TextDecoration.underline,
                        decorationColor: color,
                      ),
                    ),
                  ),
                ),
        ),
        if (client.sendAttemptCount > 0)
          Text(
            'Attempt ${client.sendAttemptCount}',
            style: Theme.of(context).textTheme.labelSmall,
          ),
      ],
    );
  }
}

class _BatchTemplateChoice {
  final MessageTemplate template;
  final List<String> parameterValues;
  final bool personalizeFirstParameter;

  const _BatchTemplateChoice({
    required this.template,
    required this.parameterValues,
    required this.personalizeFirstParameter,
  });

  List<String> valuesFor(String contactName) {
    final values = [...parameterValues];
    if (personalizeFirstParameter && values.isNotEmpty) {
      values[0] = contactName.trim().isEmpty ? 'there' : contactName.trim();
    }
    return values;
  }
}

class _BatchTemplateDialog extends StatefulWidget {
  final List<MessageTemplate> templates;
  final int recipientCount;

  const _BatchTemplateDialog({
    required this.templates,
    required this.recipientCount,
  });

  @override
  State<_BatchTemplateDialog> createState() => _BatchTemplateDialogState();
}

class _BatchTemplateDialogState extends State<_BatchTemplateDialog> {
  MessageTemplate? _selectedTemplate;
  List<TextEditingController> _parameterControllers = [];
  bool _personalizeFirstParameter = true;

  @override
  void initState() {
    super.initState();
    if (widget.templates.isNotEmpty) _selectTemplate(widget.templates.first);
  }

  @override
  void dispose() {
    for (final controller in _parameterControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  List<int> _parameterNumbers(MessageTemplate template) {
    final numbers =
        RegExp(r'\{\{(\d+)\}\}')
            .allMatches(template.content)
            .map((match) => int.parse(match.group(1)!))
            .toSet()
            .toList()
          ..sort();
    return numbers;
  }

  void _selectTemplate(MessageTemplate template) {
    for (final controller in _parameterControllers) {
      controller.dispose();
    }
    _selectedTemplate = template;
    _parameterControllers = [
      for (final _ in _parameterNumbers(template)) TextEditingController(),
    ];
  }

  void _submit() {
    final template = _selectedTemplate;
    if (template == null) return;
    final values = _parameterControllers
        .map((controller) => controller.text.trim())
        .toList();
    final firstSharedIndex = _personalizeFirstParameter ? 1 : 0;
    if (values.skip(firstSharedIndex).any((value) => value.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Fill every shared template variable.')),
      );
      return;
    }
    Navigator.pop(
      context,
      _BatchTemplateChoice(
        template: template,
        parameterValues: values,
        personalizeFirstParameter:
            _personalizeFirstParameter && values.isNotEmpty,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final template = _selectedTemplate;
    final parameterNumbers = template == null
        ? const <int>[]
        : _parameterNumbers(template);
    return AlertDialog(
      title: Text('Send to ${widget.recipientCount} selected leads'),
      content: SizedBox(
        width: 520,
        child: widget.templates.isEmpty
            ? const Text('No approved WhatsApp templates are available.')
            : SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    DropdownButtonFormField<MessageTemplate>(
                      initialValue: template,
                      decoration: const InputDecoration(
                        labelText: 'Approved template',
                      ),
                      items: widget.templates
                          .map(
                            (item) => DropdownMenuItem(
                              value: item,
                              child: Text(item.name),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() => _selectTemplate(value));
                      },
                    ),
                    const SizedBox(height: 16),
                    if (template != null)
                      Container(
                        padding: const EdgeInsets.all(12),
                        color: Theme.of(
                          context,
                        ).colorScheme.surfaceContainerHighest,
                        child: Text(template.content),
                      ),
                    if (parameterNumbers.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Use restaurant name for {{1}}'),
                        value: _personalizeFirstParameter,
                        onChanged: (value) =>
                            setState(() => _personalizeFirstParameter = value),
                      ),
                      for (
                        var index = 0;
                        index < parameterNumbers.length;
                        index++
                      )
                        if (index != 0 || !_personalizeFirstParameter)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: TextField(
                              controller: _parameterControllers[index],
                              decoration: InputDecoration(
                                labelText:
                                    'Value for {{${parameterNumbers[index]}}}',
                              ),
                            ),
                          ),
                    ],
                  ],
                ),
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          onPressed: template == null ? null : _submit,
          icon: const Icon(Icons.send_outlined),
          label: const Text('Queue batch'),
        ),
      ],
    );
  }
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
  if (client.stage == ClientStage.register) {
    return const FunnelReminder('Call now or set next call', isDue: true);
  }
  if (client.stage == ClientStage.reach) {
    return const FunnelReminder('Ready Agent Call');
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

class _LeadImportPreviewDialog extends StatelessWidget {
  final LeadCsvImportResult result;
  final Set<String> knownNumbers;

  const _LeadImportPreviewDialog({
    required this.result,
    required this.knownNumbers,
  });

  @override
  Widget build(BuildContext context) {
    final existing = result.leads
        .where(
          (lead) => knownNumbers.contains(normalizeLeadNumber(lead.number)),
        )
        .toList();
    final newLeadCount = result.leads.length - existing.length;
    return AlertDialog(
      title: const Text('Review lead import'),
      content: SizedBox(
        width: 620,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                spacing: 16,
                runSpacing: 8,
                children: [
                  Text('${result.leads.length} valid'),
                  Text('${result.duplicateRows} duplicates'),
                  Text('${result.invalidRows} invalid'),
                  Text('${existing.length} already imported'),
                ],
              ),
              const SizedBox(height: 16),
              Text('Preview', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 6),
              for (final lead in result.leads.take(8))
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Text('${lead.name}  ·  ${lead.number}'),
                ),
              if (result.leads.length > 8)
                Text('and ${result.leads.length - 8} more valid leads'),
              if (existing.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(
                  'Already in the system',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 6),
                for (final lead in existing.take(8))
                  Text('${lead.name}  ·  ${lead.number}'),
                if (existing.length > 8)
                  Text('and ${existing.length - 8} more existing leads'),
              ],
              if (result.issues.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(
                  'Rows requiring attention',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 6),
                for (final issue in result.issues.take(8))
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Text(
                      'Row ${issue.rowNumber}: ${issue.reason}'
                      '${issue.number.isEmpty ? '' : ' · ${issue.number}'}',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                if (result.issues.length > 8)
                  Text('and ${result.issues.length - 8} more issues'),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          onPressed: newLeadCount == 0
              ? null
              : () => Navigator.pop(context, true),
          icon: const Icon(Icons.upload_file_outlined),
          label: Text('Import $newLeadCount new leads'),
        ),
      ],
    );
  }
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

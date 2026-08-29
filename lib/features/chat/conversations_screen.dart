import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/chat/chat.dart';
import '../../core/providers/providers.dart';
import '../../core/widgets/app_drawer.dart';

class ConversationsScreen extends ConsumerStatefulWidget {
  const ConversationsScreen({super.key});

  @override
  ConsumerState<ConversationsScreen> createState() =>
      _ConversationsScreenState();
}

class _ConversationsScreenState extends ConsumerState<ConversationsScreen> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final chat = ref.watch(chatProvider);
    final conversations = chat.conversations;

    final whatsappConvs = conversations
        .where((c) => c.channel == ConversationChannel.whatsapp)
        .toList();

    return AppShell(
      isAdmin: true,
      currentRoute: '/admin/chat',
      title: 'Chat',
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

  List<Conversation> _filterConversations(List<Conversation> convs) {
    if (_searchQuery.trim().isEmpty) return convs;
    final q = _searchQuery.toLowerCase();
    return convs
        .where(
          (c) =>
              c.contactName.toLowerCase().contains(q) ||
              c.contactPhone.contains(q) ||
              (c.lastMessage?.toLowerCase().contains(q) ?? false),
        )
        .toList();
  }

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
  final IconData emptyIcon;
  final String emptyText;
  final Color channelColor;

  const _ConversationList({
    required this.conversations,
    required this.emptyIcon,
    required this.emptyText,
    required this.channelColor,
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
        return _ConversationTile(conversation: c, channelColor: channelColor);
      },
    );
  }
}

class _ConversationTile extends StatelessWidget {
  final Conversation conversation;
  final Color channelColor;

  const _ConversationTile({
    required this.conversation,
    required this.channelColor,
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
                          c.contactName,
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
                      if (hasUnread)
                        Container(
                          margin: const EdgeInsets.only(left: 8),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: channelColor,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '${c.unreadCount}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime? dt) {
    if (dt == null) return '';
    final now = DateTime.now();
    final diff = now.difference(dt);

    if (diff.inDays == 0) {
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } else if (diff.inDays == 1) {
      return 'Yesterday';
    } else if (diff.inDays < 7) {
      const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      return days[dt.weekday - 1];
    } else {
      return '${dt.day}/${dt.month}/${dt.year}';
    }
  }
}

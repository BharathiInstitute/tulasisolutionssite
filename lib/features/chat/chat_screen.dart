import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/chat/chat.dart';
import '../../core/providers/providers.dart';
import '../../core/widgets/app_drawer.dart';

class ChatScreen extends ConsumerStatefulWidget {
  final Conversation conversation;
  const ChatScreen({super.key, required this.conversation});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  late ConversationChannel _activeChannel;

  @override
  void initState() {
    super.initState();
    _activeChannel = widget.conversation.channel;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(chatProvider).openConversation(widget.conversation);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _send() async {
    final text = _controller.text;
    if (text.trim().isEmpty) return;
    _controller.clear();
    _scrollToBottom();
    final chat = ref.read(chatProvider);
    chat.clearError();
    try {
      await chat.sendMessage(text);
      if (!mounted) return;
      final error = chat.error;
      if (error != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildComposer(ThemeData theme) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 40,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            children: [
              _QuickReply(
                'Thank you!',
                onTap: () {
                  _controller.text = 'Thank you!';
                  _send();
                },
              ),
              _QuickReply(
                'Will follow up',
                onTap: () {
                  _controller.text = "I'll follow up on this. Thanks!";
                  _send();
                },
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            border: Border(top: BorderSide(color: theme.dividerColor)),
          ),
          child: SafeArea(
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.attach_file),
                  tooltip: 'Attach file',
                  onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Attachments coming soon')),
                  ),
                ),
                Expanded(
                  child: TextField(
                    controller: _controller,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _send(),
                    maxLines: 4,
                    minLines: 1,
                    decoration: InputDecoration(
                      hintText: 'Type a $_channelLabel message...',
                      filled: true,
                      fillColor: theme.colorScheme.surfaceContainerHighest,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                IconButton.filled(
                  onPressed: _send,
                  icon: const Icon(Icons.send),
                  style: IconButton.styleFrom(backgroundColor: _channelColor),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _showContact() async {
    final contactId = widget.conversation.contactId;
    if (contactId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This conversation has no contact record.'),
        ),
      );
      return;
    }

    try {
      final contact = await ref.read(chatProvider).getContact(contactId);
      if (!mounted) return;

      if (contact == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Contact record was not found.')),
        );
        return;
      }

      await showDialog<void>(
        context: context,
        builder: (context) => _ContactSheet(
          contact: contact,
          fallbackName: widget.conversation.contactName,
          fallbackPhone: widget.conversation.contactPhone,
        ),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to load contact details.')),
        );
      }
    }
  }

  Color get _channelColor => switch (_activeChannel) {
    ConversationChannel.whatsapp => const Color(0xFF25D366),
    ConversationChannel.sms => Colors.blue,
    ConversationChannel.voice => Colors.orange,
    _ => const Color(0xFF25D366),
  };

  IconData get _channelIcon => switch (_activeChannel) {
    ConversationChannel.whatsapp => Icons.chat,
    ConversationChannel.sms => Icons.sms,
    ConversationChannel.voice => Icons.call,
    _ => Icons.chat,
  };

  String get _channelLabel => switch (_activeChannel) {
    ConversationChannel.whatsapp => 'WhatsApp',
    ConversationChannel.sms => 'SMS',
    ConversationChannel.voice => 'Voice',
    _ => 'WhatsApp',
  };

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _openDialer() async {
    final phone = widget.conversation.contactPhone.trim();
    if (phone.replaceAll(RegExp(r'\D'), '').isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This conversation has no phone number.')),
      );
      return;
    }

    final opened = await launchUrl(Uri(scheme: 'tel', path: phone));
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to open the phone dialer.')),
      );
    }
  }

  void _showTemplatePicker() async {
    final msg91 = ref.read(chatProvider).msg91Service;
    if (msg91 == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Messaging service not available')),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _TemplatePickerSheet(
        msg91: msg91,
        clientId: widget.conversation.clientId,
        contactName: widget.conversation.contactName,
        onSend: (template, paramValues) async {
          Navigator.of(context).pop();
          try {
            await ref
                .read(chatProvider)
                .sendTemplateMessage(template, paramValues);
            _scrollToBottom();
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Failed to send template: $e')),
              );
            }
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final chat = ref.watch(chatProvider);
    final messages = chat.messages;

    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());

    return AppShell(
      isAdmin: true,
      currentRoute: '/admin/chat',
      title: widget.conversation.contactName,
      actions: [
        IconButton(
          icon: const Icon(Icons.phone),
          tooltip: 'Call ${widget.conversation.contactPhone}',
          onPressed: _openDialer,
        ),
        PopupMenuButton<String>(
          onSelected: (value) {
            if (value == 'profile') _showContact();
            if (value == 'template') _showTemplatePicker();
          },
          itemBuilder: (context) => [
            const PopupMenuItem(value: 'profile', child: Text('View Contact')),
            const PopupMenuItem(
              value: 'template',
              child: Text('Send Template'),
            ),
            const PopupMenuItem(value: 'close', child: Text('Close Chat')),
          ],
        ),
      ],
      body: Column(
        children: [
          // Channel switcher
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerLow,
              border: Border(
                bottom: BorderSide(color: theme.dividerColor.withAlpha(60)),
              ),
            ),
            child: Row(
              children: [
                _ChannelChip(
                  icon: Icons.chat,
                  label: 'WhatsApp',
                  color: const Color(0xFF25D366),
                  selected: _activeChannel == ConversationChannel.whatsapp,
                  onTap: () => setState(
                    () => _activeChannel = ConversationChannel.whatsapp,
                  ),
                ),
                const SizedBox(width: 8),
                _ChannelChip(
                  icon: Icons.sms,
                  label: 'SMS',
                  color: Colors.blue,
                  selected: false,
                  onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('SMS - Coming Soon!')),
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _channelColor.withAlpha(20),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(_channelIcon, size: 12, color: _channelColor),
                      const SizedBox(width: 4),
                      Text(
                        'via $_channelLabel',
                        style: TextStyle(
                          fontSize: 11,
                          color: _channelColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Messages
          Expanded(
            child: messages.isEmpty
                ? Center(
                    child: Text(
                      'No messages yet. Start the conversation!',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(12),
                    itemCount: messages.length,
                    itemBuilder: (context, i) {
                      final msg = messages[i];
                      final messageTime = msg.eventAt ?? msg.createdAt;
                      final previousMessageTime = i == 0
                          ? null
                          : messages[i - 1].eventAt ??
                                messages[i - 1].createdAt;
                      final isOutbound =
                          msg.direction == MessageDirection.outbound;
                      final showDate =
                          i == 0 ||
                          !_isSameDay(previousMessageTime!, messageTime);

                      return Column(
                        children: [
                          if (showDate) _DateChip(date: messageTime),
                          _MessageBubble(message: msg, isOutbound: isOutbound),
                        ],
                      );
                    },
                  ),
          ),
          _buildComposer(theme),
        ],
      ),
    );
    /*      appBar: AppBar(
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: _channelColor,
              child: Text(
                widget.conversation.contactName.isNotEmpty
                    ? widget.conversation.contactName[0].toUpperCase()
                    : '?',
                style: const TextStyle(color: Colors.white, fontSize: 16),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.conversation.contactName,
                    style: const TextStyle(fontSize: 16),
                  ),
                  Row(
                    children: [
                      Icon(_channelIcon, size: 12, color: _channelColor),
                      const SizedBox(width: 4),
                      Text(
                        _channelLabel,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: _channelColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        ' · ${widget.conversation.contactPhone}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(icon: const Icon(Icons.phone), onPressed: () {}),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'template') _showTemplatePicker();
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'profile',
                child: Text('View Contact'),
              ),
              const PopupMenuItem(
                value: 'template',
                child: Text('Send Template'),
              ),
              const PopupMenuItem(value: 'close', child: Text('Close Chat')),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Channel switcher
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerLow,
              border: Border(
                bottom: BorderSide(color: theme.dividerColor.withAlpha(60)),
              ),
            ),
            child: Row(
              children: [
                _ChannelChip(
                  icon: Icons.chat,
                  label: 'WhatsApp',
                  color: const Color(0xFF25D366),
                  selected: _activeChannel == ConversationChannel.whatsapp,
                  onTap: () => setState(
                    () => _activeChannel = ConversationChannel.whatsapp,
                  ),
                ),
                const SizedBox(width: 8),
                _ChannelChip(
                  icon: Icons.sms,
                  label: 'SMS',
                  color: Colors.blue,
                  selected: false,
                  onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('SMS — Coming Soon!')),
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _channelColor.withAlpha(20),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(_channelIcon, size: 12, color: _channelColor),
                      const SizedBox(width: 4),
                      Text(
                        'via $_channelLabel',
                        style: TextStyle(
                          fontSize: 11,
                          color: _channelColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Messages
          Expanded(
            child: messages.isEmpty
                ? Center(
                    child: Text(
                      'No messages yet. Start the conversation!',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(12),
                    itemCount: messages.length,
                    itemBuilder: (context, i) {
                      final msg = messages[i];
                      final isOutbound =
                          msg.direction == MessageDirection.outbound;
                      final showDate =
                          i == 0 ||
                          !_isSameDay(messages[i - 1].createdAt, msg.createdAt);

                      return Column(
                        children: [
                          if (showDate) _DateChip(date: msg.createdAt),
                          _MessageBubble(message: msg, isOutbound: isOutbound),
                        ],
                      );
                    },
                  ),
          ),

          // Quick replies
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                _QuickReply(
                  'Thank you! 🙏',
                  onTap: () {
                    _controller.text = 'Thank you! 🙏';
                    _send();
                  },
                ),
                _QuickReply(
                  'Will follow up',
                  onTap: () {
                    _controller.text = 'I\'ll follow up on this. Thanks!';
                    _send();
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),

          // Input bar
          Container(
            padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              border: Border(top: BorderSide(color: theme.dividerColor)),
            ),
            child: SafeArea(
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.attach_file),
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Attachments coming soon'),
                        ),
                      );
                    },
                  ),
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send(),
                      maxLines: 4,
                      minLines: 1,
                      decoration: InputDecoration(
                        hintText: 'Type a $_channelLabel message...',
                        filled: true,
                        fillColor: theme.colorScheme.surfaceContainerHighest,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  IconButton.filled(
                    onPressed: _send,
                    icon: const Icon(Icons.send),
                    style: IconButton.styleFrom(backgroundColor: _channelColor),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );*/
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

class _DateChip extends StatelessWidget {
  final DateTime date;
  const _DateChip({required this.date});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final messageDay = DateTime(date.year, date.month, date.day);
    final diff = today.difference(messageDay).inDays;
    final label = diff == 0
        ? 'Today'
        : diff == 1
        ? 'Yesterday'
        : '${date.day}/${date.month}/${date.year}';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            label,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
          ),
        ),
      ),
    );
  }
}

class _ContactSheet extends StatelessWidget {
  final Map<String, dynamic> contact;
  final String fallbackName;
  final String fallbackPhone;

  const _ContactSheet({
    required this.contact,
    required this.fallbackName,
    required this.fallbackPhone,
  });

  @override
  Widget build(BuildContext context) {
    final name = contact['name'] as String? ?? fallbackName;
    final phone = contact['phone'] as String? ?? fallbackPhone;
    final email = contact['email'] as String?;

    return AlertDialog(
      title: Text(name),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ContactDetail(icon: Icons.phone_outlined, value: phone),
          if (email != null && email.isNotEmpty) ...[
            const SizedBox(height: 12),
            _ContactDetail(icon: Icons.email_outlined, value: email),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }
}

class _ContactDetail extends StatelessWidget {
  final IconData icon;
  final String value;

  const _ContactDetail({required this.icon, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20),
        const SizedBox(width: 12),
        Expanded(child: Text(value)),
      ],
    );
  }
}

class _ChannelChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  const _ChannelChip({
    required this.icon,
    required this.label,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? color : Colors.transparent,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected ? color : color.withAlpha(80),
              width: 1.5,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: selected ? Colors.white : color),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: selected ? Colors.white : color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final Message message;
  final bool isOutbound;
  const _MessageBubble({required this.message, required this.isOutbound});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Align(
      alignment: isOutbound ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.75,
        ),
        margin: const EdgeInsets.symmetric(vertical: 3),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isOutbound
              ? const Color(0xFFDCF8C6)
              : theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(12),
            topRight: const Radius.circular(12),
            bottomLeft: Radius.circular(isOutbound ? 12 : 2),
            bottomRight: Radius.circular(isOutbound ? 2 : 12),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildMessageContent(context, theme),
            if (isOutbound &&
                message.status == MessageStatus.failed &&
                message.failureReason?.trim().isNotEmpty == true) ...[
              const SizedBox(height: 6),
              Text(
                message.failureReason!.trim(),
                style: const TextStyle(
                  color: Colors.red,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerRight,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _formatTime(message.eventAt ?? message.createdAt),
                    style: TextStyle(
                      fontSize: 10,
                      color: isOutbound
                          ? Colors.black45
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  if (isOutbound) ...[
                    const SizedBox(width: 3),
                    Icon(
                      message.status == MessageStatus.read
                          ? Icons.done_all
                          : message.status == MessageStatus.delivered
                          ? Icons.done_all
                          : message.status == MessageStatus.failed
                          ? Icons.error_outline
                          : message.status == MessageStatus.queued
                          ? Icons.access_time
                          : Icons.done,
                      size: 14,
                      color: message.status == MessageStatus.read
                          ? Colors.blue
                          : message.status == MessageStatus.failed
                          ? Colors.red
                          : Colors.black45,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageContent(BuildContext context, ThemeData theme) {
    final mediaUrl = message.mediaUrl ?? '';
    final hasMedia = mediaUrl.isNotEmpty;
    final textColor = isOutbound ? Colors.black87 : theme.colorScheme.onSurface;
    final content = message.content.trim();
    final isPlaceholder =
        content == '[Image]' ||
        content == '[Sticker]' ||
        content == '[Audio]' ||
        content == '[Media]' ||
        content == '[Video]' ||
        content == '[Document]' ||
        content == '[Location]' ||
        content == '[Template]' ||
        content == '[Call]';
    final showText = content.isNotEmpty && !isPlaceholder;

    switch (message.type) {
      case MessageType.image:
      case MessageType.sticker:
        if (hasMedia) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              InkWell(
                onTap: () => _openMediaUrl(context, mediaUrl),
                borderRadius: BorderRadius.circular(10),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.network(
                    mediaUrl,
                    width: message.type == MessageType.sticker ? 140 : 220,
                    height: message.type == MessageType.sticker ? 140 : 220,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      width: 180,
                      height: 120,
                      color: theme.colorScheme.surfaceContainer,
                      alignment: Alignment.center,
                      child: const Text('Image unavailable'),
                    ),
                  ),
                ),
              ),
              if (showText) ...[
                const SizedBox(height: 6),
                Text(content, style: TextStyle(fontSize: 14, color: textColor)),
              ],
            ],
          );
        }
        break;
      case MessageType.video:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              onTap: hasMedia ? () => _openMediaUrl(context, mediaUrl) : null,
              borderRadius: BorderRadius.circular(10),
              child: Container(
                width: 220,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.videocam_rounded, size: 22),
                    SizedBox(width: 8),
                    Text('Video'),
                  ],
                ),
              ),
            ),
            if (showText) ...[
              const SizedBox(height: 6),
              Text(content, style: TextStyle(fontSize: 14, color: textColor)),
            ],
          ],
        );
      case MessageType.audio:
      case MessageType.voiceNote:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              onTap: hasMedia ? () => _openMediaUrl(context, mediaUrl) : null,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface.withAlpha(120),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      message.type == MessageType.voiceNote
                          ? Icons.mic_none_rounded
                          : Icons.headphones_rounded,
                      size: 20,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      message.type == MessageType.voiceNote
                          ? 'Voice note'
                          : 'Audio',
                    ),
                  ],
                ),
              ),
            ),
            if (showText) ...[
              const SizedBox(height: 6),
              Text(content, style: TextStyle(fontSize: 14, color: textColor)),
            ],
          ],
        );
      case MessageType.document:
        return InkWell(
          onTap: hasMedia ? () => _openMediaUrl(context, mediaUrl) : null,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.insert_drive_file_rounded, size: 20),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    content.isEmpty ? 'Document' : content,
                    style: TextStyle(fontSize: 14, color: textColor),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        );
      case MessageType.location:
        return Container(
          width: 220,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              const Icon(Icons.location_on_rounded, color: Colors.red),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  content.isEmpty ? 'Shared location' : content,
                  style: TextStyle(fontSize: 14, color: textColor),
                ),
              ),
            ],
          ),
        );
      case MessageType.template:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: theme.colorScheme.primaryContainer.withAlpha(120),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            content.isEmpty ? 'Template message' : content,
            style: TextStyle(fontSize: 14, color: textColor),
          ),
        );
      case MessageType.call:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Icon(Icons.call_rounded, size: 18),
              SizedBox(width: 8),
              Text('Call'),
            ],
          ),
        );
      case MessageType.text:
        return Text(
          content.isEmpty ? '[Unsupported message]' : content,
          style: TextStyle(fontSize: 14, color: textColor),
        );
    }

    return Text(
      content.isEmpty ? '[Unsupported message]' : content,
      style: TextStyle(fontSize: 14, color: textColor),
    );
  }

  Future<void> _openMediaUrl(BuildContext context, String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    final ok = await launchUrl(uri, mode: LaunchMode.platformDefault);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Could not open media URL')));
    }
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour == 0
        ? 12
        : dt.hour > 12
        ? dt.hour - 12
        : dt.hour;
    final m = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    return '$h:$m $period';
  }
}

class _QuickReply extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _QuickReply(this.label, {required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ActionChip(
        label: Text(label, style: const TextStyle(fontSize: 12)),
        onPressed: onTap,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }
}

class _TemplatePickerSheet extends StatefulWidget {
  final MSG91Service msg91;
  final String clientId;
  final String contactName;
  final Future<void> Function(MessageTemplate template, List<String> params)
  onSend;

  const _TemplatePickerSheet({
    required this.msg91,
    required this.clientId,
    required this.contactName,
    required this.onSend,
  });

  @override
  State<_TemplatePickerSheet> createState() => _TemplatePickerSheetState();
}

class _TemplatePickerSheetState extends State<_TemplatePickerSheet> {
  List<MessageTemplate>? _templates;
  bool _loading = true;
  String? _error;
  MessageTemplate? _selected;
  final _paramControllers = <TextEditingController>[];
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _loadTemplates();
  }

  @override
  void dispose() {
    for (final c in _paramControllers) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _loadTemplates() async {
    try {
      final templates = await widget.msg91.getTemplates(channel: 'whatsapp');
      setState(() {
        _templates = templates
            .where(
              (template) =>
                  template.status.toLowerCase() == 'approved' &&
                  template.content.trim().isNotEmpty,
            )
            .toList();
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load templates: $e';
        _loading = false;
      });
    }
  }

  List<String> _extractParams(String content) {
    final regex = RegExp(r'\{\{(\d+)\}\}');
    final matches = regex.allMatches(content);
    final params = <String>{};
    for (final m in matches) {
      params.add(m.group(1)!);
    }
    return params.toList()..sort();
  }

  void _selectTemplate(MessageTemplate template) {
    for (final c in _paramControllers) {
      c.dispose();
    }
    final params = _extractParams(template.content);
    setState(() {
      _selected = template;
      _paramControllers.clear();
      for (final _ in params) {
        _paramControllers.add(TextEditingController());
      }
    });
  }

  String _getPreview() {
    if (_selected == null) return '';
    var preview = _selected!.content;
    final params = _extractParams(_selected!.content);
    for (var i = 0; i < params.length; i++) {
      final value =
          i < _paramControllers.length && _paramControllers[i].text.isNotEmpty
          ? _paramControllers[i].text
          : '[param ${params[i]}]';
      preview = preview.replaceAll('{{${params[i]}}}', value);
    }
    return preview;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      maxChildSize: 0.9,
      minChildSize: 0.4,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.symmetric(vertical: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.outline,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    if (_selected != null)
                      IconButton(
                        icon: const Icon(Icons.arrow_back),
                        onPressed: () => setState(() => _selected = null),
                      ),
                    Text(
                      _selected != null ? 'Fill Parameters' : 'Send Template',
                      style: theme.textTheme.titleMedium,
                    ),
                    const Spacer(),
                    if (_selected != null)
                      FilledButton.icon(
                        onPressed: _sending
                            ? null
                            : () async {
                                setState(() => _sending = true);
                                final values = _paramControllers
                                    .map((c) => c.text)
                                    .toList();
                                await widget.onSend(_selected!, values);
                              },
                        icon: const Icon(Icons.send, size: 16),
                        label: Text(_sending ? 'Sending...' : 'Send'),
                      ),
                  ],
                ),
              ),
              const Divider(),
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _error != null
                    ? Center(
                        child: Text(
                          _error!,
                          style: TextStyle(color: theme.colorScheme.error),
                        ),
                      )
                    : _selected != null
                    ? _buildParamForm(scrollController)
                    : _buildTemplateList(scrollController),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTemplateList(ScrollController scrollController) {
    if (_templates == null || _templates!.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text(
            'No approved WhatsApp templates with sendable message text were found.',
          ),
        ),
      );
    }
    return ListView.builder(
      controller: scrollController,
      itemCount: _templates!.length,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      itemBuilder: (context, index) {
        final t = _templates![index];
        return Card(
          margin: const EdgeInsets.symmetric(vertical: 4),
          child: ListTile(
            title: Text(
              t.name,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              t.content,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: Chip(
              label: Text(
                t.category ?? 'utility',
                style: const TextStyle(fontSize: 11),
              ),
              padding: EdgeInsets.zero,
            ),
            onTap: () => _selectTemplate(t),
          ),
        );
      },
    );
  }

  Widget _buildParamForm(ScrollController scrollController) {
    final content = _selected!.content.trim();
    final params = _extractParams(content);
    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: const Color(0xFFDCF8C6),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            content.isEmpty
                ? 'MSG91 did not provide this template body.'
                : _getPreview(),
            style: const TextStyle(fontSize: 14),
          ),
        ),
        for (var i = 0; i < params.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: TextField(
              controller: _paramControllers[i],
              decoration: InputDecoration(
                labelText: 'Parameter {{${params[i]}}}',
                hintText: 'Enter value for {{${params[i]}}}',
                border: const OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
        if (content.isEmpty)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Parameters cannot be shown until MSG91 returns the template body.',
            ),
          )
        else if (params.isEmpty)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'This template has no parameters. Tap Send to proceed.',
            ),
          ),
      ],
    );
  }
}

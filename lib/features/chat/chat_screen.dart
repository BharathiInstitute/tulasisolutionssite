import 'dart:async';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:cross_file/cross_file.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;
import 'package:mime/mime.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';
import '../../core/chat/chat.dart';
import '../../core/providers/providers.dart';
import '../../core/widgets/app_drawer.dart';
import 'send_error_explanation.dart';

class _PreparedAttachment {
  final XFile source;
  final Uint8List? bytes;
  final String fileName;
  final String contentType;
  final int size;

  const _PreparedAttachment({
    required this.source,
    required this.fileName,
    required this.contentType,
    required this.size,
    this.bytes,
  });

  Stream<Uint8List> read() =>
      bytes == null ? source.openRead() : Stream<Uint8List>.value(bytes!);
}

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
  bool _isAttaching = false;
  bool _isDraggingFile = false;
  bool _attachmentCancelled = false;
  double _attachmentProgress = 0.01;
  String? _attachmentPhase;
  http.Client? _uploadClient;
  Timer? _processingProgressTimer;

  @override
  void initState() {
    super.initState();
    _activeChannel = widget.conversation.channel;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(chatProvider).openConversation(widget.conversation);
    });
  }

  @override
  void dispose() {
    _processingProgressTimer?.cancel();
    _uploadClient?.close();
    ref.read(chatProvider).closeConversation();
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

  Future<void> _attachFile() async {
    if (_isAttaching) return;
    if (!_canAttachMedia()) return;

    final file = await FilePicker.pickFile(type: FileType.any);
    if (file == null || !mounted) return;
    await _uploadAttachment(file.xFile);
  }

  bool _canAttachMedia() {
    if (_activeChannel != ConversationChannel.whatsapp) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Media attachments are currently available for WhatsApp.',
          ),
        ),
      );
      return false;
    }
    return true;
  }

  void _handleFileDrop(DropDoneDetails details) {
    if (_isDraggingFile) setState(() => _isDraggingFile = false);
    if (_isAttaching || !_canAttachMedia()) return;
    final files = details.files.whereType<DropItemFile>().toList();
    if (files.length != 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            files.isEmpty
                ? 'Drop a file to attach it.'
                : 'Drop one file at a time.',
          ),
        ),
      );
      return;
    }
    unawaited(_uploadAttachment(files.single));
  }

  Future<void> _uploadAttachment(XFile file) async {
    try {
      final fileSize = await file.length();
      if (fileSize <= 0) {
        throw StateError('The selected file is empty or cannot be read.');
      }
      final mimeType = file.mimeType ?? lookupMimeType(file.name);
      final messageType = _messageTypeForMime(mimeType);
      final maxSourceBytes = _maxSourceAttachmentBytes(messageType);
      if (fileSize > maxSourceBytes) {
        throw StateError(
          '${_attachmentLabel(messageType)} must be smaller than '
          '${maxSourceBytes ~/ (1024 * 1024)} MB.',
        );
      }

      setState(() {
        _isAttaching = true;
        _attachmentCancelled = false;
        _attachmentProgress = 0.01;
        _attachmentPhase = 'Preparing';
      });
      final attachment = await _prepareAttachment(
        file: file,
        messageType: messageType,
        mimeType: mimeType,
        fileSize: fileSize,
      );
      if (!mounted || _attachmentCancelled) return;
      _setAttachmentProgress(0.08);
      final safeName = attachment.fileName.replaceAll(
        RegExp(r'[^A-Za-z0-9._-]'),
        '_',
      );
      final functions = FirebaseFunctions.instanceFor(region: 'asia-south1');
      final prepareResult = await functions
          .httpsCallable('prepareChatMediaUpload')
          .call({
            'clientId': widget.conversation.clientId,
            'conversationId': widget.conversation.id,
            'fileName': safeName,
            'originalName': file.name,
            'contentType': attachment.contentType,
            'size': attachment.size,
          });
      final prepareData = Map<String, dynamic>.from(prepareResult.data as Map);
      final uploadUrl = prepareData['uploadUrl']?.toString();
      final objectPath = prepareData['objectPath']?.toString();
      if (uploadUrl == null || objectPath == null) {
        throw StateError('Upload could not be prepared.');
      }

      if (!mounted || _attachmentCancelled) return;
      setState(() {
        _attachmentPhase = 'Uploading';
        _attachmentProgress = 0.12;
      });
      final requiresProcessing =
          messageType == MessageType.video || messageType == MessageType.audio;
      await _putAttachment(
        attachment: attachment,
        uploadUrl: uploadUrl,
        endProgress: requiresProcessing ? 0.55 : 0.82,
      );
      if (!mounted || _attachmentCancelled) return;
      setState(() {
        _attachmentPhase = 'Finalizing';
        _attachmentProgress = requiresProcessing ? 0.58 : 0.88;
      });

      final completeResult = await functions
          .httpsCallable('completeChatMediaUpload')
          .call({
            'clientId': widget.conversation.clientId,
            'conversationId': widget.conversation.id,
            'objectPath': objectPath,
            'originalName': file.name,
          });
      var uploadData = Map<String, dynamic>.from(completeResult.data as Map);
      if (requiresProcessing) {
        if (!mounted || _attachmentCancelled) return;
        setState(() {
          _attachmentPhase = 'Processing media';
          _attachmentProgress = 0.62;
        });
        _processingProgressTimer = Timer.periodic(
          const Duration(milliseconds: 800),
          (_) => _setAttachmentProgress(
            (_attachmentProgress + 0.01).clamp(0.62, 0.92),
          ),
        );
        final processResult = await functions
            .httpsCallable('processChatMedia')
            .call({
              'clientId': widget.conversation.clientId,
              'conversationId': widget.conversation.id,
              'objectPath': objectPath,
              'originalName': file.name,
              'mediaType': messageType.name,
            });
        _processingProgressTimer?.cancel();
        _processingProgressTimer = null;
        _setAttachmentProgress(0.94);
        uploadData = Map<String, dynamic>.from(processResult.data as Map);
      }
      final mediaUrl = uploadData['mediaUrl']?.toString();
      if (mediaUrl == null || mediaUrl.isEmpty) {
        throw StateError('Upload did not return a media URL.');
      }
      _setAttachmentProgress(0.96);
      await ref
          .read(chatProvider)
          .sendMediaMessage(
            mediaUrl: mediaUrl,
            type: messageType,
            caption: messageType == MessageType.document ? file.name : null,
          );
      if (!mounted) return;
      setState(() => _attachmentProgress = 1);
      _scrollToBottom();
    } catch (error) {
      if (!mounted) return;
      if (_attachmentCancelled) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Attachment upload cancelled.')),
        );
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not attach file: $error'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      _processingProgressTimer?.cancel();
      _processingProgressTimer = null;
      _uploadClient?.close();
      _uploadClient = null;
      if (mounted) {
        setState(() {
          _isAttaching = false;
          _attachmentProgress = 0.01;
          _attachmentPhase = null;
        });
      }
    }
  }

  Future<void> _putAttachment({
    required _PreparedAttachment attachment,
    required String uploadUrl,
    required double endProgress,
  }) async {
    final client = http.Client();
    _uploadClient = client;
    final request = http.StreamedRequest('PUT', Uri.parse(uploadUrl))
      ..contentLength = attachment.size
      ..headers.addAll({
        'Content-Type': attachment.contentType,
        'x-goog-meta-upload-state': 'pending',
      });
    var uploadedBytes = 0;
    final responseFuture = client.send(request);
    await request.sink.addStream(
      attachment.read().map((chunk) {
        uploadedBytes += chunk.length;
        final uploadRatio = uploadedBytes / attachment.size;
        _setAttachmentProgress(0.12 + uploadRatio * (endProgress - 0.12));
        return chunk;
      }),
    );
    await request.sink.close();
    final response = await responseFuture;
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError('Upload failed with status ${response.statusCode}.');
    }
  }

  void _setAttachmentProgress(double progress) {
    if (!mounted || progress <= _attachmentProgress) return;
    setState(() => _attachmentProgress = progress.clamp(0.01, 1));
  }

  Future<_PreparedAttachment> _prepareAttachment({
    required XFile file,
    required MessageType messageType,
    required String? mimeType,
    required int fileSize,
  }) async {
    final contentType = mimeType ?? 'application/octet-stream';
    if (messageType != MessageType.image) {
      return _PreparedAttachment(
        source: file,
        fileName: file.name,
        contentType: contentType,
        size: fileSize,
      );
    }

    const targetBytes = 5 * 1024 * 1024;
    const directlySupportedTypes = {'image/jpeg', 'image/png'};
    if (fileSize <= targetBytes &&
        directlySupportedTypes.contains(contentType)) {
      return _PreparedAttachment(
        source: file,
        fileName: file.name,
        contentType: contentType,
        size: fileSize,
      );
    }
    if (mounted) {
      setState(() {
        _attachmentPhase = 'Compressing image';
        _attachmentProgress = 0.03;
      });
    }
    final decoded = img.decodeImage(await file.readAsBytes());
    if (decoded == null) {
      throw StateError('This image format could not be converted.');
    }
    var image = img.bakeOrientation(decoded);
    _setAttachmentProgress(0.05);
    if (image.width > 2560 || image.height > 2560) {
      image = image.width >= image.height
          ? img.copyResize(
              image,
              width: 2560,
              interpolation: img.Interpolation.average,
            )
          : img.copyResize(
              image,
              height: 2560,
              interpolation: img.Interpolation.average,
            );
    }

    final preservePng = contentType == 'image/png';
    Uint8List encoded = Uint8List(0);
    for (var attempt = 0; attempt < 10; attempt++) {
      encoded = Uint8List.fromList(
        preservePng
            ? img.encodePng(image, level: 7)
            : img.encodeJpg(image, quality: (85 - attempt * 5).clamp(45, 85)),
      );
      _setAttachmentProgress(0.06 + attempt * 0.002);
      if (encoded.length <= targetBytes) break;
      if (image.width <= 320 && image.height <= 320) break;
      image = img.copyResize(
        image,
        width: (image.width * 0.82).round(),
        interpolation: img.Interpolation.average,
      );
    }
    if (encoded.length > targetBytes) {
      throw StateError('The image could not be reduced below 5 MB.');
    }

    final baseName = file.name.replaceFirst(RegExp(r'\.[^.]+$'), '');
    return _PreparedAttachment(
      source: file,
      bytes: encoded,
      fileName: '$baseName.${preservePng ? 'png' : 'jpg'}',
      contentType: preservePng ? 'image/png' : 'image/jpeg',
      size: encoded.length,
    );
  }

  void _cancelAttachmentUpload() {
    _attachmentCancelled = true;
    _uploadClient?.close();
  }

  MessageType _messageTypeForMime(String? mimeType) {
    if (mimeType == 'image/gif') return MessageType.video;
    if (mimeType?.startsWith('image/') == true) return MessageType.image;
    if (mimeType?.startsWith('video/') == true) return MessageType.video;
    if (mimeType?.startsWith('audio/') == true) return MessageType.audio;
    return MessageType.document;
  }

  int _maxSourceAttachmentBytes(MessageType type) => switch (type) {
    MessageType.image => 250 * 1024 * 1024,
    MessageType.video || MessageType.audio => 250 * 1024 * 1024,
    _ => 100 * 1024 * 1024,
  };

  String _attachmentLabel(MessageType type) => switch (type) {
    MessageType.image => 'Image',
    MessageType.video => 'Video',
    MessageType.audio => 'Audio',
    _ => 'Document',
  };

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
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_isAttaching) ...[
                  Tooltip(
                    message: 'Cancel attachment upload',
                    child: GestureDetector(
                      onTap:
                          _attachmentPhase == 'Preparing' ||
                              _attachmentPhase == 'Compressing image' ||
                              _attachmentPhase == 'Uploading'
                          ? _cancelAttachmentUpload
                          : null,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          LinearProgressIndicator(
                            value: _attachmentProgress,
                            minHeight: 18,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          Text(
                            '${(_attachmentProgress * 100).round()}%',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.onSurface,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                ],
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.attach_file),
                      tooltip: _isAttaching
                          ? 'Uploading attachment'
                          : 'Attach file',
                      onPressed: _isAttaching ? null : _attachFile,
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
                      style: IconButton.styleFrom(
                        backgroundColor: _channelColor,
                      ),
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

    return DropTarget(
      enable: _activeChannel == ConversationChannel.whatsapp && !_isAttaching,
      onDragEntered: (_) {
        if (!_isDraggingFile) setState(() => _isDraggingFile = true);
      },
      onDragExited: (_) {
        if (_isDraggingFile) setState(() => _isDraggingFile = false);
      },
      onDragDone: _handleFileDrop,
      child: Stack(
        children: [
          AppShell(
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
                  const PopupMenuItem(
                    value: 'profile',
                    child: Text('View Contact'),
                  ),
                  const PopupMenuItem(
                    value: 'template',
                    child: Text('Send Template'),
                  ),
                  const PopupMenuItem(
                    value: 'close',
                    child: Text('Close Chat'),
                  ),
                ],
              ),
            ],
            body: Column(
              children: [
                // Channel switcher
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerLow,
                    border: Border(
                      bottom: BorderSide(
                        color: theme.dividerColor.withAlpha(60),
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      _ChannelChip(
                        icon: Icons.chat,
                        label: 'WhatsApp',
                        color: const Color(0xFF25D366),
                        selected:
                            _activeChannel == ConversationChannel.whatsapp,
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
                                _MessageBubble(
                                  message: msg,
                                  isOutbound: isOutbound,
                                ),
                              ],
                            );
                          },
                        ),
                ),
                _buildComposer(theme),
              ],
            ),
          ),
          if (_isDraggingFile)
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer.withAlpha(220),
                    border: Border.all(
                      color: theme.colorScheme.primary,
                      width: 3,
                    ),
                  ),
                  child: Center(
                    child: Icon(
                      Icons.file_upload_outlined,
                      size: 72,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
              ),
            ),
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
      child: IntrinsicWidth(
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
                Builder(
                  builder: (context) {
                    final explanation = explainSendError(message.failureReason);
                    return InkWell(
                      onTap: () =>
                          showSendErrorExplanationDialog(context, explanation),
                      child: Text(
                        '${explanation.title}. Tap for details.',
                        style: const TextStyle(
                          color: Colors.red,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          decoration: TextDecoration.underline,
                          decorationColor: Colors.red,
                        ),
                      ),
                    );
                  },
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
                onTap: () => _showMediaDialog(context, mediaUrl, message.type),
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
              onTap: hasMedia
                  ? () => _showMediaDialog(context, mediaUrl, MessageType.video)
                  : null,
              borderRadius: BorderRadius.circular(10),
              child: hasMedia
                  ? _VideoPreview(url: mediaUrl)
                  : Container(
                      width: 220,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.videocam_rounded, size: 22),
                          SizedBox(width: 8),
                          Text('Video unavailable'),
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
            if (hasMedia)
              _InlineAudioPlayer(
                url: mediaUrl,
                isVoiceNote: message.type == MessageType.voiceNote,
              )
            else
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    message.type == MessageType.voiceNote
                        ? Icons.mic_off_rounded
                        : Icons.headset_off_rounded,
                    size: 20,
                  ),
                  const SizedBox(width: 6),
                  const Text('Audio unavailable'),
                ],
              ),
            if (showText) ...[
              const SizedBox(height: 6),
              Text(content, style: TextStyle(fontSize: 14, color: textColor)),
            ],
          ],
        );
      case MessageType.document:
        return InkWell(
          onTap: hasMedia ? () => _openExternalUrl(context, mediaUrl) : null,
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

  Future<void> _showMediaDialog(
    BuildContext context,
    String url,
    MessageType type,
  ) {
    return showDialog<void>(
      context: context,
      builder: (_) => _MediaDialog(url: url, type: type),
    );
  }

  Future<void> _openExternalUrl(BuildContext context, String url) async {
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

class _MediaDialog extends StatelessWidget {
  final String url;
  final MessageType type;

  const _MediaDialog({required this.url, required this.type});

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.sizeOf(context);
    final isAudio = type == MessageType.audio || type == MessageType.voiceNote;
    final width = (screenSize.width - 32).clamp(280.0, 900.0).toDouble();
    final height = isAudio
        ? 210.0
        : (screenSize.height - 32).clamp(320.0, 700.0).toDouble();

    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        width: width,
        height: height,
        child: Column(
          children: [
            SizedBox(
              height: 48,
              child: Row(
                children: [
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      _title,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(child: _buildMedia()),
          ],
        ),
      ),
    );
  }

  String get _title => switch (type) {
    MessageType.image => 'Image',
    MessageType.sticker => 'Sticker',
    MessageType.video => 'Video',
    MessageType.voiceNote => 'Voice note',
    _ => 'Audio',
  };

  Widget _buildMedia() => switch (type) {
    MessageType.image || MessageType.sticker => _ImageViewer(url: url),
    MessageType.video => _VideoViewer(url: url),
    MessageType.audio || MessageType.voiceNote => _AudioViewer(url: url),
    _ => const Center(child: Text('Unsupported media')),
  };
}

class _ImageViewer extends StatelessWidget {
  final String url;

  const _ImageViewer({required this.url});

  @override
  Widget build(BuildContext context) {
    return InteractiveViewer(
      minScale: 0.8,
      maxScale: 5,
      child: Center(
        child: Image.network(
          url,
          fit: BoxFit.contain,
          loadingBuilder: (context, child, progress) => progress == null
              ? child
              : const Center(child: CircularProgressIndicator()),
          errorBuilder: (_, __, ___) =>
              const Center(child: Text('Could not load image')),
        ),
      ),
    );
  }
}

class _VideoPreview extends StatefulWidget {
  final String url;

  const _VideoPreview({required this.url});

  @override
  State<_VideoPreview> createState() => _VideoPreviewState();
}

class _VideoPreviewState extends State<_VideoPreview> {
  late final VideoPlayerController _controller;
  bool _ready = false;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.url));
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      await _controller.initialize();
      if (mounted) setState(() => _ready = true);
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: SizedBox(
        width: 220,
        height: 140,
        child: Stack(
          fit: StackFit.expand,
          children: [
            ColoredBox(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              child: _ready
                  ? FittedBox(
                      fit: BoxFit.cover,
                      clipBehavior: Clip.hardEdge,
                      child: SizedBox(
                        width: _controller.value.size.width,
                        height: _controller.value.size.height,
                        child: VideoPlayer(_controller),
                      ),
                    )
                  : Center(
                      child: _failed
                          ? const Icon(Icons.videocam_off_rounded, size: 30)
                          : const CircularProgressIndicator(strokeWidth: 2),
                    ),
            ),
            if (_ready)
              const Center(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Color(0x99000000),
                    shape: BoxShape.circle,
                  ),
                  child: Padding(
                    padding: EdgeInsets.all(10),
                    child: Icon(
                      Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: 34,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _VideoViewer extends StatefulWidget {
  final String url;

  const _VideoViewer({required this.url});

  @override
  State<_VideoViewer> createState() => _VideoViewerState();
}

class _VideoViewerState extends State<_VideoViewer> {
  late final VideoPlayerController _controller;
  bool _ready = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.url));
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      await _controller.initialize();
      await _controller.setLooping(false);
      _controller.addListener(_refresh);
      if (mounted) setState(() => _ready = true);
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not load video');
    }
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controller.removeListener(_refresh);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) return Center(child: Text(_error!));
    if (!_ready) return const Center(child: CircularProgressIndicator());

    final value = _controller.value;
    return Column(
      children: [
        Expanded(
          child: Center(
            child: AspectRatio(
              aspectRatio: value.aspectRatio,
              child: VideoPlayer(_controller),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 4, 16, 12),
          child: Row(
            children: [
              IconButton(
                tooltip: value.isPlaying ? 'Pause' : 'Play',
                onPressed: value.isPlaying
                    ? _controller.pause
                    : _controller.play,
                icon: Icon(
                  value.isPlaying
                      ? Icons.pause_rounded
                      : Icons.play_arrow_rounded,
                ),
              ),
              Expanded(
                child: VideoProgressIndicator(
                  _controller,
                  allowScrubbing: true,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
              const SizedBox(width: 12),
              Text(_formatDuration(value.position)),
            ],
          ),
        ),
      ],
    );
  }
}

class _InlineAudioPlayer extends StatefulWidget {
  final String url;
  final bool isVoiceNote;

  const _InlineAudioPlayer({required this.url, required this.isVoiceNote});

  @override
  State<_InlineAudioPlayer> createState() => _InlineAudioPlayerState();
}

class _InlineAudioPlayerState extends State<_InlineAudioPlayer> {
  late final AudioPlayer _player;
  late final StreamSubscription<void> _completionSubscription;
  bool _ready = false;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _player = AudioPlayer();
    _completionSubscription = _player.onPlayerComplete.listen((_) async {
      await _player.seek(Duration.zero);
    });
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      await _player.setReleaseMode(ReleaseMode.stop);
      await _player.setSourceUrl(widget.url);
      if (mounted) setState(() => _ready = true);
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  Future<void> _togglePlayback(PlayerState state) async {
    if (state == PlayerState.playing) {
      await _player.pause();
      return;
    }
    if (state == PlayerState.completed) {
      await _player.seek(Duration.zero);
    }
    await _player.resume();
  }

  @override
  void dispose() {
    _completionSubscription.cancel();
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_failed) {
      return const SizedBox(
        width: 280,
        height: 64,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline_rounded, size: 20),
            SizedBox(width: 8),
            Text('Could not load audio'),
          ],
        ),
      );
    }
    if (!_ready) {
      return const SizedBox(
        width: 280,
        height: 64,
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }

    return SizedBox(
      width: 300,
      height: 72,
      child: StreamBuilder<Duration>(
        stream: _player.onDurationChanged,
        builder: (context, durationSnapshot) {
          final duration = durationSnapshot.data ?? Duration.zero;
          return StreamBuilder<Duration>(
            stream: _player.onPositionChanged,
            builder: (context, positionSnapshot) {
              final position = positionSnapshot.data ?? Duration.zero;
              final maximum = duration.inMilliseconds.toDouble().clamp(
                1.0,
                double.infinity,
              );
              final current = position.inMilliseconds.toDouble().clamp(
                0.0,
                maximum,
              );
              return Row(
                children: [
                  StreamBuilder<PlayerState>(
                    stream: _player.onPlayerStateChanged,
                    builder: (context, stateSnapshot) {
                      final state = stateSnapshot.data ?? PlayerState.stopped;
                      final isPlaying = state == PlayerState.playing;
                      return IconButton.filled(
                        tooltip: isPlaying ? 'Pause' : 'Play',
                        onPressed: () => _togglePlayback(state),
                        icon: Icon(
                          isPlaying
                              ? Icons.pause_rounded
                              : Icons.play_arrow_rounded,
                        ),
                      );
                    },
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            trackHeight: 3,
                            thumbShape: const RoundSliderThumbShape(
                              enabledThumbRadius: 6,
                            ),
                            overlayShape: const RoundSliderOverlayShape(
                              overlayRadius: 12,
                            ),
                          ),
                          child: Slider(
                            min: 0,
                            max: maximum,
                            value: current,
                            onChanged: (value) => _player.seek(
                              Duration(milliseconds: value.round()),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Row(
                            children: [
                              Icon(
                                widget.isVoiceNote
                                    ? Icons.mic_none_rounded
                                    : Icons.headphones_rounded,
                                size: 14,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                _formatDuration(position),
                                style: Theme.of(context).textTheme.labelSmall,
                              ),
                              const Spacer(),
                              Text(
                                _formatDuration(duration),
                                style: Theme.of(context).textTheme.labelSmall,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class _AudioViewer extends StatefulWidget {
  final String url;

  const _AudioViewer({required this.url});

  @override
  State<_AudioViewer> createState() => _AudioViewerState();
}

class _AudioViewerState extends State<_AudioViewer> {
  late final AudioPlayer _player;
  bool _ready = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _player = AudioPlayer();
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      await _player.setSourceUrl(widget.url);
      if (mounted) setState(() => _ready = true);
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not load audio');
    }
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) return Center(child: Text(_error!));
    if (!_ready) return const Center(child: CircularProgressIndicator());

    return Padding(
      padding: const EdgeInsets.all(20),
      child: StreamBuilder<Duration>(
        stream: _player.onDurationChanged,
        builder: (context, durationSnapshot) {
          final duration = durationSnapshot.data ?? Duration.zero;
          return StreamBuilder<Duration>(
            stream: _player.onPositionChanged,
            builder: (context, positionSnapshot) {
              final position = positionSnapshot.data ?? Duration.zero;
              final maximum = duration.inMilliseconds.toDouble().clamp(
                1.0,
                double.infinity,
              );
              final current = position.inMilliseconds.toDouble().clamp(
                0.0,
                maximum,
              );
              return Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    children: [
                      StreamBuilder<PlayerState>(
                        stream: _player.onPlayerStateChanged,
                        builder: (context, stateSnapshot) {
                          final isPlaying =
                              stateSnapshot.data == PlayerState.playing;
                          return IconButton.filled(
                            tooltip: isPlaying ? 'Pause' : 'Play',
                            onPressed: isPlaying
                                ? _player.pause
                                : _player.resume,
                            icon: Icon(
                              isPlaying
                                  ? Icons.pause_rounded
                                  : Icons.play_arrow_rounded,
                            ),
                          );
                        },
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Slider(
                          min: 0,
                          max: maximum,
                          value: current,
                          onChanged: (value) => _player.seek(
                            Duration(milliseconds: value.round()),
                          ),
                        ),
                      ),
                    ],
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      '${_formatDuration(position)} / '
                      '${_formatDuration(duration)}',
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

String _formatDuration(Duration duration) {
  final minutes = duration.inMinutes;
  final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
  return '$minutes:$seconds';
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

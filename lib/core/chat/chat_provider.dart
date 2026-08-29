import 'dart:async';
import 'package:flutter/foundation.dart';
import 'message_model.dart';
import 'chat_firestore_service.dart';
import 'msg91_service.dart';
import 'rate_limiter.dart';

class ChatProvider extends ChangeNotifier {
  final ChatFirestoreService _firestoreService;
  final MSG91Service? _msg91Service;
  final _sendLimiter = RateLimiter(interval: const Duration(milliseconds: 500));
  int _retryCount = 0;
  static const _maxRetries = 3;

  List<Conversation> _conversations = [];
  Conversation? _activeConversation;
  List<Message> _messages = [];
  bool _isLoading = false;
  String? _error;
  StreamSubscription? _conversationsSub;
  StreamSubscription? _messagesSub;

  ChatProvider({
    required ChatFirestoreService firestoreService,
    MSG91Service? msg91Service,
  }) : _firestoreService = firestoreService,
       _msg91Service = msg91Service;

  List<Conversation> get conversations => _conversations;
  Conversation? get activeConversation => _activeConversation;
  MSG91Service? get msg91Service => _msg91Service;
  List<Message> get messages => _messages;
  bool get isLoading => _isLoading;
  String? get error => _error;

  void clearError() {
    _error = null;
    notifyListeners();
  }

  int get totalUnread =>
      _conversations.fold(0, (sum, c) => sum + c.unreadCount);

  void loadConversations() {
    _isLoading = true;
    _retryCount = 0;
    _error = null;
    notifyListeners();

    _startConversationsStream();
  }

  void _startConversationsStream() {
    _conversationsSub?.cancel();
    _conversationsSub = _firestoreService.watchConversations().listen(
      (list) {
        _conversations = list;
        _isLoading = false;
        _error = null;
        _retryCount = 0;
        notifyListeners();
      },
      onError: (e) {
        final errStr = e.toString();
        debugPrint(
          'ChatProvider: conversations error (retry $_retryCount/$_maxRetries): $errStr',
        );
        debugPrint(
          'ChatProvider: clientId=${_firestoreService.isConfigured ? _firestoreService.currentClientId : "NOT CONFIGURED"}',
        );

        if (errStr.contains('permission-denied') && _retryCount < _maxRetries) {
          _retryCount++;
          final delay = Duration(seconds: _retryCount * 2);
          debugPrint('ChatProvider: retrying in ${delay.inSeconds}s...');
          Future.delayed(delay, () {
            _startConversationsStream();
          });
        } else {
          _error = 'Failed to load conversations: $errStr';
          _isLoading = false;
          notifyListeners();
        }
      },
    );
  }

  void openConversation(Conversation conversation) {
    _activeConversation = conversation;
    _messages = [];
    notifyListeners();

    _messagesSub?.cancel();
    _messagesSub = _firestoreService.watchMessages(conversation.id).listen((
      list,
    ) {
      final hadNewInbound =
          _msg91Service != null &&
          list.any(
            (m) =>
                m.direction == MessageDirection.inbound &&
                m.status == MessageStatus.delivered,
          );

      _messages = list;
      notifyListeners();

      if (hadNewInbound) {
        _msg91Service
            .markConversationRead(conversationId: conversation.id)
            .catchError((e) {
              debugPrint('Failed to send read receipts: $e');
            });
      }
    });

    if (_msg91Service != null && conversation.unreadCount > 0) {
      _msg91Service
          .markConversationRead(conversationId: conversation.id)
          .catchError((e) {
            debugPrint('Failed to send read receipts: $e');
          });
    }
  }

  void closeConversation() {
    _activeConversation = null;
    _messages = [];
    _messagesSub?.cancel();
    notifyListeners();
  }

  Future<Conversation?> createConversation({
    required String contactId,
    required String contactName,
    required String contactPhone,
    ConversationChannel channel = ConversationChannel.whatsapp,
  }) async {
    try {
      final conversation = Conversation(
        id: '',
        contactId: contactId,
        contactName: contactName,
        contactPhone: contactPhone,
        channel: channel,
        createdAt: DateTime.now(),
      );
      final id = await _firestoreService.createConversation(conversation);
      return Conversation(
        id: id,
        contactId: contactId,
        contactName: contactName,
        contactPhone: contactPhone,
        channel: channel,
        createdAt: DateTime.now(),
      );
    } catch (e) {
      _error = 'Failed to create conversation: $e';
      notifyListeners();
      return null;
    }
  }

  Future<void> sendMessage(
    String content, {
    MessageType type = MessageType.text,
  }) async {
    if (_activeConversation == null || content.trim().isEmpty) return;
    if (!_sendLimiter.allow()) return;

    final message = Message(
      id: 'msg-${DateTime.now().millisecondsSinceEpoch}',
      conversationId: _activeConversation!.id,
      contactId: _activeConversation!.contactId,
      direction: MessageDirection.outbound,
      type: type,
      content: content.trim(),
      status: MessageStatus.queued,
      senderName: 'You',
      createdAt: DateTime.now(),
    );

    try {
      final msgId = await _firestoreService.sendMessage(
        _activeConversation!.id,
        message,
      );

      if (_msg91Service != null) {
        try {
          await _msg91Service.sendWhatsAppMessage(
            contactId: _activeConversation!.contactId,
            content: content.trim(),
            conversationId: _activeConversation!.id,
            messageDocId: msgId,
          );
          debugPrint(
            'MSG91: WhatsApp message enqueued for delivery (msgId: $msgId)',
          );
        } catch (e) {
          debugPrint('MSG91: WhatsApp delivery failed: $e');
          _error = 'Message saved but WhatsApp delivery failed: $e';
          notifyListeners();
        }
      } else {
        debugPrint(
          'MSG91: No MSG91 service configured — message saved to Firestore only',
        );
      }
    } catch (e) {
      _error = 'Failed to send message: $e';
      notifyListeners();
      rethrow;
    }
  }

  Future<void> sendTemplateMessage(
    MessageTemplate template,
    List<String> paramValues,
  ) async {
    if (_activeConversation == null) return;
    if (!_sendLimiter.allow()) return;

    var displayContent = template.content;
    for (var i = 0; i < paramValues.length; i++) {
      displayContent = displayContent.replaceAll(
        '{{${i + 1}}}',
        paramValues[i],
      );
    }

    final message = Message(
      id: 'msg-${DateTime.now().millisecondsSinceEpoch}',
      conversationId: _activeConversation!.id,
      contactId: _activeConversation!.contactId,
      direction: MessageDirection.outbound,
      type: template.type,
      content: displayContent,
      status: MessageStatus.queued,
      senderName: 'You',
      createdAt: DateTime.now(),
    );

    try {
      final msgId = await _firestoreService.sendMessage(
        _activeConversation!.id,
        message,
      );

      if (_msg91Service != null) {
        await _msg91Service.sendWhatsAppMessage(
          contactId: _activeConversation!.contactId,
          content: displayContent,
          templateName: template.name,
          templateParams: {
            for (var i = 0; i < paramValues.length; i++)
              '${i + 1}': paramValues[i],
          },
          conversationId: _activeConversation!.id,
          messageDocId: msgId,
        );
      }
    } catch (e) {
      _error = 'Failed to send template: $e';
      notifyListeners();
      rethrow;
    }
  }

  Future<void> sendMediaMessage({
    required String mediaUrl,
    required MessageType type,
    String? caption,
  }) async {
    if (_activeConversation == null) return;
    if (!_sendLimiter.allow()) return;

    final trimmedCaption = caption?.trim() ?? '';
    final fallbackText = switch (type) {
      MessageType.image => '[Image]',
      MessageType.sticker => '[Sticker]',
      MessageType.audio || MessageType.voiceNote => '[Audio]',
      _ => '[Media]',
    };

    final message = Message(
      id: 'msg-${DateTime.now().millisecondsSinceEpoch}',
      conversationId: _activeConversation!.id,
      contactId: _activeConversation!.contactId,
      direction: MessageDirection.outbound,
      type: type,
      content: trimmedCaption.isEmpty ? fallbackText : trimmedCaption,
      mediaUrl: mediaUrl,
      mediaType: type.name,
      status: MessageStatus.queued,
      senderName: 'You',
      createdAt: DateTime.now(),
    );

    try {
      final msgId = await _firestoreService.sendMessage(
        _activeConversation!.id,
        message,
      );

      if (_msg91Service != null) {
        await _msg91Service.sendWhatsAppMedia(
          contactId: _activeConversation!.contactId,
          mediaUrl: mediaUrl,
          caption: trimmedCaption,
          type: type,
          conversationId: _activeConversation!.id,
          messageDocId: msgId,
        );
      }
    } catch (e) {
      _error = 'Failed to send media: $e';
      notifyListeners();
      rethrow;
    }
  }

  @override
  void dispose() {
    _conversationsSub?.cancel();
    _messagesSub?.cancel();
    super.dispose();
  }
}

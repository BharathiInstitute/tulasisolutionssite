import 'dart:async';
import 'package:flutter/foundation.dart';
import '../constants/enums.dart';
import 'message_model.dart';
import 'chat_firestore_service.dart';
import 'msg91_service.dart';
import 'rate_limiter.dart';

class ChatProvider extends ChangeNotifier {
  final ChatFirestoreService _firestoreService;
  final MSG91Service? _msg91Service;
  final _sendLimiter = RateLimiter(interval: const Duration(milliseconds: 500));

  List<Conversation> _allConversations = [];
  List<Conversation> _conversations = [];
  List<Conversation> _archivedConversations = [];
  Conversation? _activeConversation;
  List<Message> _messages = [];
  bool _isLoading = false;
  final bool _isLoadingMore = false;
  bool _hasMoreConversations = true;
  bool _isDisposed = false;
  int? _totalWhatsappConversations;
  int _totalArchivedConversations = 0;
  Map<String, int> _stageConversationCounts = {};
  Map<String, int> _archivedStageConversationCounts = {};
  String? _conversationStage;
  String? _error;
  StreamSubscription? _messagesSub;
  StreamSubscription<List<Conversation>>? _conversationsSub;
  Timer? _conversationRetryTimer;
  int _conversationSession = 0;

  ChatProvider({
    required ChatFirestoreService firestoreService,
    MSG91Service? msg91Service,
  }) : _firestoreService = firestoreService,
       _msg91Service = msg91Service;

  List<Conversation> get conversations => _conversations;
  List<Conversation> get archivedConversations => _archivedConversations;
  Conversation? get activeConversation => _activeConversation;
  MSG91Service? get msg91Service => _msg91Service;
  List<Message> get messages => _messages;
  bool get isLoading => _isLoading;
  bool get isLoadingMore => _isLoadingMore == true;
  bool get hasMoreConversations => _hasMoreConversations == true;
  int? get totalWhatsappConversations => _totalWhatsappConversations;
  int get totalArchivedConversations => _conversationStage == null
      ? _totalArchivedConversations
      : _archivedStageConversationCounts[_conversationStage] ?? 0;
  Map<String, int> get stageConversationCounts => _stageConversationCounts;
  String? get error => _error;

  Future<Map<String, dynamic>?> getContact(String contactId) {
    return _firestoreService.getContact(
      contactId,
      ownerClientId: _activeConversation?.clientId,
    );
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  int get totalUnread =>
      _conversations.fold(0, (sum, c) => sum + c.unreadCount);

  void markConversationAsReadLocally(String conversationId) {
    final index = _conversations.indexWhere((c) => c.id == conversationId);
    if (index == -1) return;

    final current = _conversations[index];
    if (current.unreadCount <= 0) return;

    _conversations[index] = Conversation(
      id: current.id,
      clientId: current.clientId,
      contactId: current.contactId,
      contactName: current.contactName,
      contactPhone: current.contactPhone,
      contactAvatarUrl: current.contactAvatarUrl,
      channel: current.channel,
      lastMessage: current.lastMessage,
      lastMessageAt: current.lastMessageAt,
      lastMessageDirection: current.lastMessageDirection,
      unreadCount: 0,
      isActive: current.isActive,
      isArchived: current.isArchived,
      stage: current.stage,
      assignedTo: current.assignedTo,
      createdAt: current.createdAt,
    );
    notifyListeners();
  }

  Future<void> loadConversations({String? stage}) async {
    _conversationStage = stage;
    _error = null;
    _watchAllConversations();
  }

  void _watchAllConversations() {
    _conversationRetryTimer?.cancel();
    _conversationsSub?.cancel();
    _isLoading = true;
    _hasMoreConversations = false;
    _conversationsSub = _firestoreService
        .watchAllConversations(stage: _conversationStage)
        .listen(
          (conversations) {
            if (_isDisposed) return;
            _allConversations = conversations;
            _isLoading = false;
            _error = null;
            _conversationRetryTimer?.cancel();
            _applyConversationView();
            notifyListeners();
          },
          onError: (Object error) {
            if (_isDisposed) return;
            _isLoading = false;
            _error = 'Failed to load conversations: $error';
            notifyListeners();
            _conversationRetryTimer = Timer(
              const Duration(seconds: 3),
              _watchAllConversations,
            );
          },
        );
    unawaited(_refreshConversationCounts());
  }

  Future<void> _refreshConversationCounts() async {
    try {
      final stages = chatFunnelStages.map((stage) => stage.name).toList();
      final results = await Future.wait([
        _firestoreService.countActiveConversationsByStage(stages),
        Future.wait(
          stages.map(
            (stage) => _firestoreService.countConversations(
              stage: stage,
              isArchived: true,
            ),
          ),
        ),
      ]);
      if (_isDisposed) return;
      _stageConversationCounts = results[0] as Map<String, int>;
      final archivedCounts = results[1] as List<int>;
      _archivedStageConversationCounts = {
        for (var index = 0; index < stages.length; index++)
          stages[index]: archivedCounts[index],
      };
      _totalWhatsappConversations = _stageConversationCounts.values.fold<int>(
        0,
        (total, amount) => total + amount,
      );
      _totalArchivedConversations = _archivedStageConversationCounts.values
          .fold<int>(0, (total, amount) => total + amount);
      notifyListeners();
    } catch (_) {
      // Counts are supplementary; conversations should remain usable.
    }
  }

  void _applyConversationView() {
    final active = <Conversation>[];
    final archived = <Conversation>[];

    for (final conversation in _allConversations) {
      if (_conversationStage != null &&
          conversation.stage != _conversationStage) {
        continue;
      }
      (conversation.isArchived ? archived : active).add(conversation);
    }

    _conversations = active;
    _archivedConversations = archived;
  }

  Future<void> loadMoreConversations() async {
    return;
  }

  Future<void> updateClientConversationFilters({
    required String ownerClientId,
    required String stage,
  }) {
    return _firestoreService.updateClientConversationFilters(
      ownerClientId: ownerClientId,
      stage: stage,
    );
  }

  Future<void> updateClientConversationArchive({
    required String ownerClientId,
    required Conversation conversation,
    required bool isArchived,
  }) async {
    await _firestoreService.updateClientConversationArchive(
      ownerClientId: ownerClientId,
      conversationId: conversation.id,
      isArchived: isArchived,
    );
  }

  Future<void> updateConversationsArchive({
    required List<Conversation> conversations,
    required bool isArchived,
  }) async {
    await _firestoreService.updateConversationsArchive(
      conversations: conversations,
      isArchived: isArchived,
    );
  }

  void openConversation(Conversation conversation) {
    final session = ++_conversationSession;
    _activeConversation = conversation;
    _messages = [];
    markConversationAsReadLocally(conversation.id);
    notifyListeners();

    _messagesSub?.cancel();
    _messagesSub = _firestoreService
        .watchMessages(conversation.id, ownerClientId: conversation.clientId)
        .listen(
          (list) {
            if (_isDisposed ||
                session != _conversationSession ||
                _activeConversation?.id != conversation.id) {
              return;
            }
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
                  .markConversationRead(
                    conversationId: conversation.id,
                    clientId: conversation.clientId,
                    viewedAt: DateTime.now(),
                  )
                  .catchError((e) {
                    debugPrint('Failed to send read receipts: $e');
                  });
            }
          },
          onError: (Object error) {
            if (_isDisposed || session != _conversationSession) return;
            _error = 'Failed to load messages: $error';
            notifyListeners();
          },
        );

    if (_msg91Service != null && conversation.unreadCount > 0) {
      _msg91Service
          .markConversationRead(
            conversationId: conversation.id,
            clientId: conversation.clientId,
            viewedAt: DateTime.now(),
          )
          .catchError((e) {
            debugPrint('Failed to send read receipts: $e');
          });
    }
  }

  void closeConversation() {
    _conversationSession++;
    _activeConversation = null;
    _messages = [];
    _messagesSub?.cancel();
    _messagesSub = null;
  }

  Future<void> startQualificationAutomation(Conversation conversation) async {
    if (_msg91Service == null) {
      throw StateError('Messaging service is unavailable');
    }
    await _msg91Service.startQualificationAutomation(
      conversationId: conversation.id,
    );
  }

  Future<Conversation?> createConversation({
    required String contactId,
    required String contactName,
    required String contactPhone,
    ConversationChannel channel = ConversationChannel.whatsapp,
    String? ownerClientId,
  }) async {
    try {
      final conversation = Conversation(
        id: '',
        clientId: ownerClientId ?? _firestoreService.currentClientId,
        contactId: contactId,
        contactName: contactName,
        contactPhone: contactPhone,
        channel: channel,
        createdAt: DateTime.now(),
      );
      final id = await _firestoreService.createConversation(
        conversation,
        ownerClientId: ownerClientId,
      );
      return Conversation(
        id: id,
        clientId: ownerClientId ?? _firestoreService.currentClientId,
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
        ownerClientId: _activeConversation!.clientId,
      );

      if (_msg91Service != null) {
        try {
          await _msg91Service.sendWhatsAppMessage(
            contactId: _activeConversation!.contactId,
            content: content.trim(),
            clientId: _activeConversation!.clientId,
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

  Future<void> sendMessageToConversation(
    Conversation conversation,
    String content,
  ) async {
    final message = Message(
      id: 'msg-${DateTime.now().millisecondsSinceEpoch}',
      conversationId: conversation.id,
      contactId: conversation.contactId,
      direction: MessageDirection.outbound,
      content: content.trim(),
      status: MessageStatus.queued,
      senderName: 'You',
      createdAt: DateTime.now(),
    );
    final messageId = await _firestoreService.sendMessage(
      conversation.id,
      message,
      ownerClientId: conversation.clientId,
    );
    if (_msg91Service == null) {
      throw StateError('Messaging service is unavailable');
    }
    await _msg91Service.sendWhatsAppMessage(
      contactId: conversation.contactId,
      content: content.trim(),
      clientId: conversation.clientId,
      conversationId: conversation.id,
      messageDocId: messageId,
    );
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
      mediaUrl: template.headerImageUrl,
      mediaType: template.headerImageUrl == null ? null : 'image',
      status: MessageStatus.queued,
      senderName: 'You',
      createdAt: DateTime.now(),
    );

    try {
      final msgId = await _firestoreService.sendMessage(
        _activeConversation!.id,
        message,
        ownerClientId: _activeConversation!.clientId,
      );

      if (_msg91Service != null) {
        await _msg91Service.sendWhatsAppMessage(
          contactId: _activeConversation!.contactId,
          content: displayContent,
          clientId: _activeConversation!.clientId,
          templateName: template.name,
          templateParams: {
            for (var i = 0; i < paramValues.length; i++)
              '${i + 1}': paramValues[i],
          },
          templateHeaderImageUrl: template.headerImageUrl,
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

  Future<void> sendTemplateToConversation(
    Conversation conversation,
    MessageTemplate template,
    List<String> paramValues, {
    required String campaignId,
  }) async {
    var displayContent = template.content;
    for (var index = 0; index < paramValues.length; index++) {
      displayContent = displayContent.replaceAll(
        '{{${index + 1}}}',
        paramValues[index],
      );
    }

    final message = Message(
      id: 'msg-${DateTime.now().microsecondsSinceEpoch}',
      conversationId: conversation.id,
      contactId: conversation.contactId,
      direction: MessageDirection.outbound,
      type: template.type,
      content: displayContent,
      status: MessageStatus.queued,
      senderName: 'You',
      createdAt: DateTime.now(),
    );
    final messageId = await _firestoreService.sendMessage(
      conversation.id,
      message,
      ownerClientId: conversation.clientId,
    );
    if (_msg91Service == null) {
      throw StateError('Messaging service is unavailable');
    }
    await _msg91Service.sendWhatsAppMessage(
      contactId: conversation.contactId,
      content: displayContent,
      clientId: conversation.clientId,
      templateName: template.name,
      templateParams: {
        for (var index = 0; index < paramValues.length; index++)
          '${index + 1}': paramValues[index],
      },
      templateHeaderImageUrl: template.headerImageUrl,
      conversationId: conversation.id,
      messageDocId: messageId,
      campaignId: campaignId,
    );
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
      MessageType.video => '[Video]',
      MessageType.document => '[Document]',
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
        ownerClientId: _activeConversation!.clientId,
      );

      if (_msg91Service != null) {
        await _msg91Service.sendWhatsAppMedia(
          contactId: _activeConversation!.contactId,
          mediaUrl: mediaUrl,
          clientId: _activeConversation!.clientId,
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
    _isDisposed = true;
    _conversationRetryTimer?.cancel();
    _messagesSub?.cancel();
    _conversationsSub?.cancel();
    super.dispose();
  }
}

import 'package:cloud_firestore/cloud_firestore.dart';

enum MessageType {
  text,
  image,
  sticker,
  video,
  audio,
  document,
  template,
  location,
  voiceNote,
  call,
}

enum MessageStatus { queued, sent, delivered, read, failed }

enum MessageDirection { inbound, outbound }

enum ConversationChannel { whatsapp, sms, email, voice }

class Message {
  final String id;
  final String conversationId;
  final String contactId;
  final MessageDirection direction;
  final MessageType type;
  final String content;
  final String? mediaUrl;
  final String? mediaType;
  final String? templateId;
  final MessageStatus status;
  final String? senderName;
  final String? senderId;
  final DateTime createdAt;
  final DateTime? readAt;

  const Message({
    required this.id,
    required this.conversationId,
    required this.contactId,
    required this.direction,
    this.type = MessageType.text,
    required this.content,
    this.mediaUrl,
    this.mediaType,
    this.templateId,
    this.status = MessageStatus.queued,
    this.senderName,
    this.senderId,
    required this.createdAt,
    this.readAt,
  });

  factory Message.fromMap(Map<String, dynamic> map, String id) {
    final rawType = (map['type'] ?? '').toString();
    final rawMediaType = (map['mediaType'] ?? '').toString();
    final mediaUrl = map['mediaUrl']?.toString();

    return Message(
      id: id,
      conversationId: map['conversationId'] ?? '',
      contactId: map['contactId'] ?? '',
      direction: MessageDirection.values.firstWhere(
        (e) => e.name == map['direction'],
        orElse: () => MessageDirection.inbound,
      ),
      type: _parseMessageType(rawType, rawMediaType, mediaUrl),
      content: map['content'] ?? '',
      mediaUrl: mediaUrl,
      mediaType: _normalizeMediaType(rawMediaType, mediaUrl),
      templateId: map['templateId'],
      status: MessageStatus.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => MessageStatus.queued,
      ),
      senderName: map['senderName'],
      senderId: map['senderId'],
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      readAt: (map['readAt'] as Timestamp?)?.toDate(),
    );
  }

  static MessageType _parseMessageType(
    String rawType,
    String rawMediaType,
    String? mediaUrl,
  ) {
    final type = rawType.toLowerCase().trim();
    final mediaType = rawMediaType.toLowerCase().trim();
    final combined = '$type $mediaType';

    final exact = MessageType.values.where((e) => e.name == type);
    if (exact.isNotEmpty) return exact.first;

    if (combined.contains('sticker')) return MessageType.sticker;
    if (combined.contains('voice') || combined.contains('ptt')) {
      return MessageType.voiceNote;
    }
    if (combined.contains('audio')) return MessageType.audio;
    if (combined.contains('video')) return MessageType.video;
    if (combined.contains('image') || combined.contains('gif')) {
      return MessageType.image;
    }
    if (combined.contains('document') || combined.contains('file')) {
      return MessageType.document;
    }
    if (combined.contains('location')) return MessageType.location;
    if (combined.contains('template')) return MessageType.template;
    if (combined.contains('call')) return MessageType.call;

    final url = (mediaUrl ?? '').toLowerCase();
    if (url.isNotEmpty) {
      if (url.contains('.gif') ||
          url.contains('.jpg') ||
          url.contains('.jpeg') ||
          url.contains('.png') ||
          url.contains('.webp')) {
        return MessageType.image;
      }
      if (url.contains('.mp3') ||
          url.contains('.wav') ||
          url.contains('.ogg') ||
          url.contains('.m4a') ||
          url.contains('.aac') ||
          url.contains('.opus')) {
        return MessageType.audio;
      }
      if (url.contains('.mp4') ||
          url.contains('.mov') ||
          url.contains('.webm')) {
        return MessageType.video;
      }
    }

    return MessageType.text;
  }

  static String? _normalizeMediaType(String rawMediaType, String? mediaUrl) {
    final mediaType = rawMediaType.trim();
    if (mediaType.isNotEmpty) return mediaType;

    final url = (mediaUrl ?? '').toLowerCase();
    if (url.isEmpty) return null;
    if (url.contains('.gif')) return 'image/gif';
    if (url.contains('.jpg') || url.contains('.jpeg')) return 'image/jpeg';
    if (url.contains('.png')) return 'image/png';
    if (url.contains('.webp')) return 'image/webp';
    if (url.contains('.mp3')) return 'audio/mpeg';
    if (url.contains('.wav')) return 'audio/wav';
    if (url.contains('.ogg')) return 'audio/ogg';
    if (url.contains('.m4a')) return 'audio/mp4';
    if (url.contains('.mp4')) return 'video/mp4';
    return null;
  }

  Map<String, dynamic> toMap() {
    return {
      'conversationId': conversationId,
      'contactId': contactId,
      'direction': direction.name,
      'type': type.name,
      'content': content,
      'mediaUrl': mediaUrl,
      'mediaType': mediaType,
      'templateId': templateId,
      'status': status.name,
      'senderName': senderName,
      'senderId': senderId,
      'createdAt': Timestamp.fromDate(createdAt),
      'readAt': readAt != null ? Timestamp.fromDate(readAt!) : null,
    };
  }
}

class Conversation {
  final String id;
  final String contactId;
  final String contactName;
  final String contactPhone;
  final String? contactAvatarUrl;
  final ConversationChannel channel;
  final String? lastMessage;
  final DateTime? lastMessageAt;
  final int unreadCount;
  final bool isActive;
  final String? assignedTo;
  final DateTime createdAt;

  const Conversation({
    required this.id,
    required this.contactId,
    required this.contactName,
    required this.contactPhone,
    this.contactAvatarUrl,
    this.channel = ConversationChannel.whatsapp,
    this.lastMessage,
    this.lastMessageAt,
    this.unreadCount = 0,
    this.isActive = true,
    this.assignedTo,
    required this.createdAt,
  });

  factory Conversation.fromMap(Map<String, dynamic> map, String id) {
    return Conversation(
      id: id,
      contactId: map['contactId'] ?? '',
      contactName: map['contactName'] ?? '',
      contactPhone: map['contactPhone'] ?? '',
      contactAvatarUrl: map['contactAvatarUrl'],
      channel: ConversationChannel.values.firstWhere(
        (e) => e.name == map['channel'],
        orElse: () => ConversationChannel.whatsapp,
      ),
      lastMessage: map['lastMessage'],
      lastMessageAt: (map['lastMessageAt'] as Timestamp?)?.toDate(),
      unreadCount: map['unreadCount'] ?? 0,
      isActive: map['isActive'] ?? true,
      assignedTo: map['assignedTo'],
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'contactId': contactId,
      'contactName': contactName,
      'contactPhone': contactPhone,
      'contactAvatarUrl': contactAvatarUrl,
      'channel': channel.name,
      'lastMessage': lastMessage,
      'lastMessageAt': lastMessageAt != null
          ? Timestamp.fromDate(lastMessageAt!)
          : null,
      'unreadCount': unreadCount,
      'isActive': isActive,
      'assignedTo': assignedTo,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}

class MessageTemplate {
  final String id;
  final String name;
  final String content;
  final MessageType type;
  final String? category;
  final String? language;
  final String status;
  final String channel;
  final String? dltTemplateId;
  final String? flowId;
  final String? rejectionReason;
  final DateTime createdAt;

  const MessageTemplate({
    required this.id,
    required this.name,
    required this.content,
    this.type = MessageType.text,
    this.category,
    this.language = 'en',
    this.status = 'draft',
    this.channel = 'whatsapp',
    this.dltTemplateId,
    this.flowId,
    this.rejectionReason,
    required this.createdAt,
  });

  factory MessageTemplate.fromMap(Map<String, dynamic> map, String id) {
    final content = map['body'] ?? map['content'] ?? '';
    DateTime createdAt;
    final raw = map['createdAt'];
    if (raw is Timestamp) {
      createdAt = raw.toDate();
    } else if (raw is String) {
      createdAt = DateTime.tryParse(raw) ?? DateTime.now();
    } else {
      createdAt = DateTime.now();
    }
    return MessageTemplate(
      id: id,
      name: map['name'] ?? '',
      content: content,
      type: MessageType.values.firstWhere(
        (e) => e.name == map['type'],
        orElse: () => MessageType.text,
      ),
      category: map['category'],
      language: map['language'] ?? 'en',
      status: map['status'] ?? 'draft',
      channel: map['channel'] ?? 'whatsapp',
      dltTemplateId: map['dltTemplateId'],
      flowId: map['flowId'],
      rejectionReason: map['rejectionReason'],
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'body': content,
      'type': type.name,
      'category': category,
      'language': language,
      'status': status,
      'channel': channel,
      'dltTemplateId': dltTemplateId,
      'flowId': flowId,
      'rejectionReason': rejectionReason,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}

enum CallDirection { inbound, outbound }

enum CallStatus { initiated, answered, missed, busy, failed, noAnswer }

class CallLog {
  final String id;
  final String? contactId;
  final String phoneNumber;
  final CallDirection direction;
  final CallStatus status;
  final Duration duration;
  final String? recordingUrl;
  final DateTime timestamp;

  const CallLog({
    required this.id,
    this.contactId,
    required this.phoneNumber,
    this.direction = CallDirection.outbound,
    this.status = CallStatus.answered,
    this.duration = Duration.zero,
    this.recordingUrl,
    required this.timestamp,
  });

  factory CallLog.fromMap(Map<String, dynamic> map, String id) {
    return CallLog(
      id: id,
      contactId: map['contactId'],
      phoneNumber: map['phone'] ?? map['phoneNumber'] ?? '',
      direction: CallDirection.values.firstWhere(
        (e) => e.name == map['direction'],
        orElse: () => CallDirection.outbound,
      ),
      status: CallStatus.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => CallStatus.answered,
      ),
      duration: Duration(seconds: map['duration'] ?? 0),
      recordingUrl: map['recordingUrl'],
      timestamp: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'contactId': contactId,
      'phone': phoneNumber,
      'direction': direction.name,
      'status': status.name,
      'duration': duration.inSeconds,
      'recordingUrl': recordingUrl,
      'createdAt': Timestamp.fromDate(timestamp),
    };
  }
}

import 'cloud_function_service.dart';
import 'message_model.dart';

/// Messaging status for all channels.
class MessagingStatus {
  final bool apiConnected;
  final bool whatsappConnected;
  final String? whatsappNumber;
  final bool smsConnected;
  final int smsBalance;
  final String? smsSenderId;
  final bool voiceConnected;

  const MessagingStatus({
    this.apiConnected = false,
    this.whatsappConnected = false,
    this.whatsappNumber,
    this.smsConnected = false,
    this.smsBalance = 0,
    this.smsSenderId,
    this.voiceConnected = false,
  });

  factory MessagingStatus.fromMap(Map<String, dynamic> map) {
    final wa = map['whatsapp'] as Map<String, dynamic>? ?? {};
    final sms = map['sms'] as Map<String, dynamic>? ?? {};
    final voice = map['voice'] as Map<String, dynamic>? ?? {};
    return MessagingStatus(
      apiConnected: map['apiConnected'] == true,
      whatsappConnected: wa['connected'] == true,
      whatsappNumber: wa['integratedNumber'] as String?,
      smsConnected: sms['connected'] == true,
      smsBalance: (sms['balance'] as num?)?.toInt() ?? 0,
      smsSenderId: sms['senderId'] as String?,
      voiceConnected: voice['connected'] == true,
    );
  }
}

/// Usage statistics.
class MessagingUsageStats {
  final int smsBalance;
  final bool whatsappActive;
  final bool voiceActive;

  const MessagingUsageStats({
    this.smsBalance = 0,
    this.whatsappActive = false,
    this.voiceActive = false,
  });

  factory MessagingUsageStats.fromMap(Map<String, dynamic> map) {
    return MessagingUsageStats(
      smsBalance: (map['smsBalance'] as num?)?.toInt() ?? 0,
      whatsappActive: map['whatsappActive'] == true,
      voiceActive: map['voiceActive'] == true,
    );
  }
}

/// Service that wraps MSG91-powered Cloud Functions.
/// All MSG91 API calls go through Cloud Functions (authkey stays server-side).
class MSG91Service {
  final CloudFunctionService _cf;

  MSG91Service({required CloudFunctionService cloudFunctions})
    : _cf = cloudFunctions;

  // ─── STATUS ──────────────────────────────────────────────

  Future<MessagingStatus> getMessagingStatus() async {
    final result = await _cf.call('getMessagingStatus');
    return MessagingStatus.fromMap(result);
  }

  Future<bool> testConnection() async {
    final result = await _cf.call('testMessagingConnection');
    return result['connected'] == true;
  }

  Future<MessagingUsageStats> getUsageStats() async {
    final result = await _cf.call('getMessagingUsageStats');
    return MessagingUsageStats.fromMap(result);
  }

  // ─── WHATSAPP ────────────────────────────────────────────

  Future<void> sendWhatsAppMessage({
    required String contactId,
    required String content,
    String? clientId,
    String? templateName,
    Map<String, String>? templateParams,
    String? conversationId,
    String? messageDocId,
  }) async {
    await _cf.call('enqueueMessage', {
      'contactId': contactId,
      'content': content,
      'channel': 'whatsapp',
      if (clientId != null) 'clientId': clientId,
      if (templateName != null) 'templateName': templateName,
      if (templateParams != null) 'templateParams': templateParams,
      if (conversationId != null) 'conversationId': conversationId,
      if (messageDocId != null) 'messageDocId': messageDocId,
    });
  }

  Future<void> sendWhatsAppMedia({
    required String contactId,
    required String mediaUrl,
    String? clientId,
    String? caption,
    MessageType type = MessageType.image,
    String? conversationId,
    String? messageDocId,
  }) async {
    await _cf.call('enqueueMessage', {
      'contactId': contactId,
      'content': caption ?? '',
      'channel': 'whatsapp',
      if (clientId != null) 'clientId': clientId,
      'mediaUrl': mediaUrl,
      'mediaType': type.name,
      if (conversationId != null) 'conversationId': conversationId,
      if (messageDocId != null) 'messageDocId': messageDocId,
    });
  }

  // ─── SMS ─────────────────────────────────────────────────

  Future<void> sendSMS({
    required String contactId,
    required String content,
    required String flowId,
  }) async {
    await _cf.call('enqueueMessage', {
      'contactId': contactId,
      'content': content,
      'channel': 'sms',
      'flowId': flowId,
    });
  }

  // ─── VOICE ───────────────────────────────────────────────

  Future<void> makeCall({
    required String contactId,
    required String voiceFlowId,
  }) async {
    await _cf.call('enqueueMessage', {
      'contactId': contactId,
      'content': 'Voice call',
      'channel': 'voice',
      'voiceFlowId': voiceFlowId,
    });
  }

  // ─── READ RECEIPTS ──────────────────────────────────────

  Future<void> markConversationRead({
    required String conversationId,
    String? clientId,
  }) async {
    await _cf.call('markConversationRead', {
      'conversationId': conversationId,
      if (clientId?.isNotEmpty == true) 'clientId': clientId,
    });
  }

  Future<void> startQualificationAutomation({
    required String conversationId,
  }) async {
    await _cf.call('startQualificationAutomation', {
      'conversationId': conversationId,
    });
  }

  // ─── TEMPLATES ───────────────────────────────────────────

  Future<List<MessageTemplate>> getTemplates({
    String? channel,
  }) async {
    final result = await _cf.call('listTemplates', {
      if (channel != null) 'channel': channel,
    });
    final list = result['templates'] as List<dynamic>? ?? [];
    return list
        .map(
          (t) => MessageTemplate.fromMap(
            Map<String, dynamic>.from(t as Map),
            t['id'] as String? ?? '',
          ),
        )
        .toList();
  }

  Future<List<MessageTemplate>> getPendingWhatsAppTemplates() async {
    final result = await _cf.call('listTemplates');
    final list = result['pendingTemplates'] as List<dynamic>? ?? [];
    return list
        .map(
          (template) => MessageTemplate.fromMap(
            Map<String, dynamic>.from(template as Map),
            template['id'] as String? ?? '',
          ),
        )
        .toList();
  }

  Future<Map<String, dynamic>> submitWhatsAppTemplate({
    required String name,
    required String body,
    required String category,
    required String language,
    String? footer,
  }) async {
    return _cf.call('submitWhatsAppTemplate', {
      'name': name,
      'body': body,
      'category': category,
      'language': language,
      if (footer?.isNotEmpty == true) 'footer': footer,
    });
  }
}

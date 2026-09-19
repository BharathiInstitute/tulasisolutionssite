import 'package:flutter_test/flutter_test.dart';
import 'package:tulasisolutionssite/core/chat/message_model.dart';
import 'package:tulasisolutionssite/core/constants/enums.dart';
import 'package:tulasisolutionssite/core/models/models.dart';
import 'package:tulasisolutionssite/features/chat/conversations_screen.dart';

Client _client(String id, String name, String phone) => Client(
  id: id,
  name: name,
  category: '',
  contactEmail: '',
  contactPhone: phone,
  stage: ClientStage.click,
  createdDate: DateTime(2026, 1, 1),
);

Client _funnelClient(ClientStage stage, DateTime stageChangedAt) => Client(
  id: 'lead',
  name: 'Restaurant',
  category: '',
  contactEmail: '',
  contactPhone: '9000000000',
  stage: stage,
  stageChangedAt: stageChangedAt,
  createdDate: stageChangedAt,
);

void main() {
  group('formatConversationTimestamp', () {
    test('shows the exact time for today messages', () {
      final now = DateTime(2026, 8, 30, 15, 45, 0);
      final dt = DateTime(2026, 8, 30, 9, 20, 0);

      expect(formatConversationTimestamp(dt, now: now), '9:20 AM');
    });

    test('shows Yesterday for messages from the previous day', () {
      final now = DateTime(2026, 8, 30, 15, 45, 0);
      final dt = DateTime(2026, 8, 29, 20, 10, 0);

      expect(formatConversationTimestamp(dt, now: now), 'Yesterday');
    });

    test('shows short date for older messages', () {
      final now = DateTime(2026, 8, 30, 15, 45, 0);
      final dt = DateTime(2026, 8, 20, 9, 0, 0);

      expect(formatConversationTimestamp(dt, now: now), '20/8/2026');
    });
  });

  group('funnelReminderLabel', () {
    final now = DateTime(2026, 9, 19, 12);

    test('flags the second cold-message touch on day three', () {
      final client = _funnelClient(
        ClientStage.click,
        now.subtract(const Duration(days: 3)),
      );

      final reminder = funnelReminderLabel(client, null, now: now);

      expect(reminder.label, 'Nudge #2 due');
      expect(reminder.isDue, isTrue);
    });

    test('flags the qualified demo follow-up on day seven', () {
      final client = _funnelClient(
        ClientStage.consult,
        now.subtract(const Duration(days: 7)),
      );

      final reminder = funnelReminderLabel(client, null, now: now);

      expect(reminder.label, 'Demo follow-up due');
      expect(reminder.isDue, isTrue);
    });

    test('flags qualified leads ready to close on day fifteen', () {
      final client = _funnelClient(
        ClientStage.consult,
        now.subtract(const Duration(days: 15)),
      );

      expect(
        funnelReminderLabel(client, null, now: now).label,
        'Ready to close',
      );
    });
  });

  group('Message.fromMap', () {
    test('uses legacy text fields when content is absent', () {
      final message = Message.fromMap({
        'text': 'Hello from WhatsApp',
        'direction': 'inbound',
        'createdAt': null,
      }, 'message-id');

      expect(message.content, 'Hello from WhatsApp');
    });
  });

  group('findClientByPhone', () {
    test('matches contacts by phone even when their names are identical', () {
      final firstMani = _client('first', 'Mani', '+91 91601 60748');
      final secondMani = _client('second', 'Mani', '+91 98492 10073');

      expect(
        findClientByPhone('9849210073', [firstMani, secondMani]),
        same(secondMani),
      );
    });

    test('does not select a client when a phone match is ambiguous', () {
      final firstMani = _client('first', 'Mani', '+91 91601 60748');
      final secondMani = _client('second', 'Mani', '9160160748');

      expect(findClientByPhone('9160160748', [firstMani, secondMani]), isNull);
    });
  });
}

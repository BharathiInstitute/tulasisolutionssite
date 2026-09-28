import 'package:flutter_test/flutter_test.dart';
import 'package:tulasisolutionssite/features/chat/send_error_explanation.dart';

void main() {
  test('explains Meta engagement error 131049 in plain English', () {
    final explanation = explainSendError(
      '131049: This message was not delivered to maintain healthy ecosystem engagement.',
    );

    expect(explanation.title, 'WhatsApp limited this marketing message');
    expect(explanation.summary, contains('phone number and app are not broken'));
    expect(explanation.action, contains('Do not retry immediately'));
  });

  test('explains undeliverable phone error 131026', () {
    final explanation = explainSendError('Provider error 131026');

    expect(explanation.title, 'Message could not be delivered');
    expect(explanation.action, contains('country code'));
  });

  test('explains Meta recipient experiment error 130472', () {
    final explanation = explainSendError(
      "130472: User's number is part of an experiment",
    );

    expect(
      explanation.title,
      'WhatsApp temporarily blocked delivery to this number',
    );
    expect(explanation.summary, contains('controlled by Meta'));
    expect(explanation.action, contains('Do not retry immediately'));
  });

  test('explains template errors', () {
    final missing = explainSendError('132001 template not found');
    final mismatch = explainSendError('132000 parameter count mismatch');

    expect(missing.title, 'WhatsApp template was not found');
    expect(mismatch.title, 'Template information does not match');
  });

  test('explains authorization and network failures', () {
    expect(
      explainSendError('403 Forbidden').title,
      'Messaging account authorization failed',
    );
    expect(
      explainSendError('Connection timeout').title,
      'Temporary connection problem',
    );
  });

  test('explains rejected media attachment payloads', () {
    final explanation = explainSendError(
      'attachment_url not found in request',
    );

    expect(explanation.title, 'Media attachment was rejected');
    expect(explanation.summary, contains('required format'));
  });

  test('preserves unknown technical details behind a friendly fallback', () {
    const raw = 'Provider returned unexpected code XYZ';
    final explanation = explainSendError(raw);

    expect(explanation.title, 'Message could not be sent');
    expect(explanation.technicalDetails, raw);
  });
}
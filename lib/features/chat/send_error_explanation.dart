import 'package:flutter/material.dart';

class SendErrorExplanation {
  final String title;
  final String summary;
  final String action;
  final String technicalDetails;

  const SendErrorExplanation({
    required this.title,
    required this.summary,
    required this.action,
    required this.technicalDetails,
  });
}

SendErrorExplanation explainSendError(String? rawError) {
  final raw = rawError?.trim() ?? '';
  final lower = raw.toLowerCase();

  SendErrorExplanation result(String title, String summary, String action) =>
      SendErrorExplanation(
        title: title,
        summary: summary,
        action: action,
        technicalDetails: raw.isEmpty ? 'No technical details were provided.' : raw,
      );

  if (lower.contains('131049')) {
    return result(
      'WhatsApp limited this marketing message',
      'WhatsApp chose not to deliver this message to protect the recipient from too many marketing messages. The phone number and app are not broken.',
      'Do not retry immediately. Wait several days, use a different consented channel, or ask the customer to message your business first.',
    );
  }
  if (lower.contains('130472')) {
    return result(
      'WhatsApp temporarily blocked delivery to this number',
      'Meta selected this recipient for a temporary messaging experiment, so the message was not delivered. This is controlled by Meta and does not mean the phone number is invalid.',
      'Do not retry immediately. Wait several days or contact the customer through another consented channel. The restriction may clear automatically.',
    );
  }
  if (lower.contains('131026')) {
    return result(
      'Message could not be delivered',
      'The number may not use WhatsApp, may be inactive, or may be unable to receive messages from this business.',
      'Confirm the number and country code. Contact the customer through another consented channel if needed.',
    );
  }
  if (lower.contains('131047')) {
    return result(
      'Customer reply window expired',
      'A normal message cannot be sent because more than 24 hours have passed since the customer last replied.',
      'Send an approved WhatsApp template instead, or wait for the customer to message your business.',
    );
  }
  if (lower.contains('131048')) {
    return result(
      'Too many messages were reported or ignored',
      'WhatsApp temporarily limited this sender because recent messages received poor engagement or spam feedback.',
      'Pause marketing sends, review audience consent and template quality, then resume with smaller targeted batches.',
    );
  }
  if (lower.contains('130429') ||
      lower.contains('131056') ||
      lower.contains('rate limit') ||
      lower.contains('too many requests')) {
    return result(
      'Sending limit reached',
      'WhatsApp or MSG91 temporarily limited how quickly messages can be sent.',
      'Wait before retrying and reduce the batch size or sending speed.',
    );
  }
  if (lower.contains('132000') || lower.contains('parameter')) {
    return result(
      'Template information does not match',
      'The values supplied for the WhatsApp template do not match its approved placeholders or format.',
      'Check the selected template and provide a value for every required placeholder.',
    );
  }
  if (lower.contains('132001') || lower.contains('template not found')) {
    return result(
      'WhatsApp template was not found',
      'The selected template or language is not available for this WhatsApp sender.',
      'Choose an approved template in MSG91 and confirm its name and language.',
    );
  }
  if (lower.contains('132005') || lower.contains('132015')) {
    return result(
      'WhatsApp template is paused',
      'WhatsApp paused or disabled this template because of its quality or delivery history.',
      'Open MSG91 or Meta Business Manager, review the template status, and select another approved template.',
    );
  }
  if (lower.contains('132007') || lower.contains('template format')) {
    return result(
      'WhatsApp rejected the template format',
      'The message content does not match the approved template format.',
      'Use the approved template exactly and check its variables, header, and buttons.',
    );
  }
  if (lower.contains('133010') || lower.contains('not registered')) {
    return result(
      'WhatsApp sender is not registered',
      'The business sending number is not currently registered or connected for WhatsApp messaging.',
      'Reconnect or register the WhatsApp number in MSG91 before sending again.',
    );
  }
  if (lower.contains('unauth') ||
      lower.contains('forbidden') ||
      lower.contains('permission') ||
      lower.contains('401') ||
      lower.contains('403')) {
    return result(
      'Messaging account authorization failed',
      'The app could not authenticate with MSG91 or is not allowed to perform this action.',
      'Ask an administrator to check the MSG91 credentials, sender permissions, and Firebase configuration.',
    );
  }
  if (lower.contains('no phone') || lower.contains('invalid phone')) {
    return result(
      'Phone number is missing or invalid',
      'A valid recipient number could not be found for this contact.',
      'Correct the phone number, including its country code, before retrying.',
    );
  }
  if (lower.contains('attachment_url')) {
    return result(
      'Media attachment was rejected',
      'MSG91 did not receive the uploaded media URL in the required format.',
      'Retry after the media integration is updated. The uploaded file itself does not need to be changed.',
    );
  }
  if (lower.contains('maximum retries') || lower.contains('max retries')) {
    return result(
      'Message failed after several attempts',
      'The system retried the send but the messaging provider continued to reject or fail it.',
      'Review the technical details, correct the cause, and retry manually only after it is resolved.',
    );
  }
  if (lower.contains('timeout') ||
      lower.contains('network') ||
      lower.contains('unavailable') ||
      lower.contains('connection')) {
    return result(
      'Temporary connection problem',
      'The app could not complete the request because the messaging service or network was unavailable.',
      'Wait a few minutes and retry. If it continues, check Firebase Functions and MSG91 service status.',
    );
  }
  if (lower.contains('template')) {
    return result(
      'WhatsApp template problem',
      'WhatsApp or MSG91 rejected the selected message template.',
      'Confirm that the template is approved, enabled, and has the correct variables and language.',
    );
  }

  return result(
    'Message could not be sent',
    'The messaging provider returned an error that the app does not recognize yet.',
    'Review the technical details below. Check the number and template, then retry only after correcting the cause.',
  );
}

Future<void> showSendErrorExplanationDialog(
  BuildContext context,
  SendErrorExplanation explanation,
) => showDialog<void>(
  context: context,
  builder: (context) => AlertDialog(
    icon: Icon(Icons.error_outline, color: Theme.of(context).colorScheme.error),
    title: Text(explanation.title),
    content: SingleChildScrollView(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(explanation.summary),
            const SizedBox(height: 20),
            Text('What to do', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 6),
            Text(explanation.action),
            const SizedBox(height: 20),
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              childrenPadding: EdgeInsets.zero,
              title: const Text('Technical details'),
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: SelectableText(explanation.technicalDetails),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Close'),
      ),
    ],
  ),
);
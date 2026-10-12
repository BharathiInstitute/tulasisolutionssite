import '../constants/enums.dart';

const salesStageUpdates = <ClientStage, List<String>>{
  ClientStage.click: [
    'Not contacted',
    'No response',
    'Interested',
    'Not suitable',
  ],
  ClientStage.register: [
    'Discussion pending',
    'Details sent',
    'Proposal sent',
    'Awaiting response',
  ],
  ClientStage.consult: [
    'No response',
    'Considering',
    'Changes requested',
    'Ready to proceed',
    'Not interested',
  ],
  ClientStage.client: [
    'Confirmed',
    'Awaiting payment',
    'Onboarding pending',
    'Onboarding complete',
  ],
  ClientStage.retain: [
    'Check-in pending',
    'Satisfied',
    'Needs help',
    'Renewal pending',
    'Renewed',
    'Not renewing',
  ],
  ClientStage.refer: [
    'Not asked',
    'Referral requested',
    'Referral promised',
    'Referral received',
    'Thanked',
  ],
  ClientStage.lost: [
    'Not interested',
    'Not suitable',
    'Cancelled',
    'Duplicate',
    'Invalid contact',
  ],
};

const salesStageProgress = <ClientStage, List<String>>{
  ClientStage.click: [
    'New lead',
    'Contact attempted',
    'Connected',
    'Qualified',
    'Not suitable',
  ],
  ClientStage.register: [
    'Needs discussed',
    'Meeting scheduled',
    'Meeting completed',
    'Details sent',
    'Pricing sent',
    'Proposal sent',
  ],
  ClientStage.consult: [
    'Awaiting response',
    'Considering',
    'Needs approval',
    'Changes requested',
    'Negotiating',
    'Decision promised',
  ],
  ClientStage.client: [
    'Order confirmed',
    'Awaiting payment',
    'Onboarding pending',
    'Onboarding completed',
  ],
  ClientStage.retain: [
    'Check-in due',
    'Satisfied',
    'Concern raised',
    'Concern resolved',
    'Renewal due',
    'Renewal offered',
    'Renewed',
    'Not renewing',
  ],
  ClientStage.refer: [
    'Ready to ask',
    'Referral requested',
    'Referral promised',
    'Referral received',
    'Thank-you completed',
    'Review requested',
    'Review received',
  ],
  ClientStage.lost: [
    'Not interested',
    'Not suitable',
    'Lost to competitor',
    'Cancelled',
    'Duplicate',
    'Invalid contact',
  ],
};

String salesProgressLabel(ClientStage stage, String progress) =>
    (salesStageProgress[ClientStage.fromStoredName(stage.name)]!.contains(
          progress,
        ) ||
        salesStageUpdates[ClientStage.fromStoredName(stage.name)]!.contains(
          progress,
        ))
    ? progress
    : 'Not recorded';

const salesStageActions = <ClientStage, List<String>>{
  ClientStage.click: ['Call', 'WhatsApp', 'Qualification'],
  ClientStage.register: [
    'Call',
    'WhatsApp',
    'Meeting',
    'Send details',
    'Pricing',
    'Proposal',
  ],
  ClientStage.consult: [
    'Call',
    'WhatsApp',
    'Meeting',
    'Pricing',
    'Proposal',
    'Decision follow-up',
  ],
  ClientStage.client: [
    'Call',
    'WhatsApp',
    'Payment follow-up',
    'Onboarding follow-up',
  ],
  ClientStage.retain: [
    'Call',
    'WhatsApp',
    'Customer check-in',
    'Resolve concern',
    'Renewal',
  ],
  ClientStage.refer: [
    'Call',
    'WhatsApp',
    'Referral',
    'Thank customer',
    'Request review',
  ],
  ClientStage.lost: ['Call', 'WhatsApp', 'Qualification'],
};

const salesActionOutcomes = <String, List<String>>{
  'Qualification': ['Qualified', 'Needs more information', 'Not suitable'],
  'Send details': ['Sent', 'Received', 'More information requested'],
  'Decision follow-up': [
    'Awaiting decision',
    'Approval pending',
    'Agreed',
    'Declined',
  ],
  'Onboarding follow-up': ['Scheduled', 'In progress', 'Completed', 'Delayed'],
  'Customer check-in': ['Satisfied', 'Concern raised', 'No reply'],
  'Resolve concern': ['In progress', 'Resolved', 'Escalated'],
  'Thank customer': ['Thank-you sent', 'Acknowledged', 'No reply'],
  'Request review': ['Requested', 'Promised', 'Received', 'Declined'],
  'Call': [
    'No answer',
    'Busy',
    'Phone unavailable',
    'Wrong number',
    'Connected',
  ],
  'WhatsApp': [
    'Message sent',
    'No reply',
    'Reply received',
    'Requested details',
  ],
  'Meeting': [
    'Scheduled',
    'Completed',
    'Customer unavailable',
    'Reschedule requested',
    'Cancelled',
  ],
  'Pricing': [
    'Sent',
    'Under review',
    'Changes requested',
    'Accepted',
    'Declined',
  ],
  'Proposal': [
    'Sent',
    'Under review',
    'Changes requested',
    'Accepted',
    'Declined',
  ],
  'Payment follow-up': [
    'Payment promised',
    'Part payment reported',
    'Full payment reported',
    'Delayed',
    'Disputed',
  ],
  'Renewal': ['Interested', 'Considering', 'Confirmed', 'Declined'],
  'Referral': ['Requested', 'Promised', 'Received', 'Declined'],
};

const salesCustomerResponses = [
  'Not discussed',
  'Interested',
  'Needs more information',
  'Price too high',
  'Budget unavailable',
  'Needs approval',
  'Comparing providers',
  'Not ready now',
  'Not interested',
  'Ready to proceed',
  'Satisfied',
  'Concern raised',
  'Do not contact',
];

const salesNextSteps = <String, String>{
  'No next step': '',
  'Call again': 'Call',
  'Send WhatsApp': 'WhatsApp',
  'Send details': 'Send details',
  'Send pricing': 'Pricing',
  'Send proposal': 'Proposal',
  'Revise proposal': 'Proposal',
  'Arrange meeting': 'Meeting',
  'Follow up on decision': 'Decision follow-up',
  'Follow up on payment': 'Payment follow-up',
  'Discuss renewal': 'Renewal',
  'Request referral': 'Referral',
  'Arrange onboarding': 'Onboarding follow-up',
  'Customer check-in': 'Customer check-in',
  'Resolve concern': 'Resolve concern',
  'Thank customer': 'Thank customer',
  'Request review': 'Request review',
};

const salesReminderDays = <int, String>{
  0: 'Later today',
  1: 'Tomorrow',
  2: 'In 2 days',
  3: 'In 3 days',
  5: 'In 5 days',
  7: 'In 1 week',
  14: 'In 2 weeks',
  21: 'In 3 weeks',
  28: 'In 4 weeks',
  42: 'In 6 weeks',
  56: 'In 8 weeks',
  84: 'In 12 weeks',
};

String? normalizedSalesAction(String action) {
  final normalized = action == 'Payment Follow-up'
      ? 'Payment follow-up'
      : action;
  return salesActionOutcomes.containsKey(normalized) ? normalized : null;
}

DateTime salesReminderAt(DateTime anchor, int days, int minutes) {
  if (!salesReminderDays.containsKey(days) || minutes < 0 || minutes >= 1440) {
    throw ArgumentError('Select a supported reminder interval and time.');
  }
  final local = anchor.toLocal();
  return DateTime(
    local.year,
    local.month,
    local.day + days,
    minutes ~/ 60,
    minutes % 60,
  );
}

String suggestedSalesNextStep(
  String? action,
  String? outcome,
  String response,
) {
  if (response == 'Do not contact' || response == 'Not interested') {
    return 'No next step';
  }
  if (response == 'Price too high') return 'Send pricing';
  if (response == 'Needs more information' || outcome == 'Requested details') {
    return 'Send details';
  }
  if (action == 'Call' &&
      ['No answer', 'Busy', 'Phone unavailable'].contains(outcome)) {
    return 'Call again';
  }
  if (outcome == 'Changes requested') return 'Revise proposal';
  if (action == 'Pricing' || action == 'Proposal') {
    return 'Follow up on decision';
  }
  if (action == 'Payment follow-up') {
    return outcome == 'Full payment reported'
        ? 'No next step'
        : 'Follow up on payment';
  }
  if (action == 'WhatsApp' && outcome == 'No reply') return 'Call again';
  return 'No next step';
}

String salesActivitySummary({
  required String action,
  required String outcome,
  required String response,
  required String nextStep,
  ClientStage? stage,
  String? progress,
}) => [
  action,
  if (outcome.isNotEmpty) 'Outcome: $outcome',
  'Customer response: $response',
  'Next step: $nextStep',
  if (stage != null) 'Stage: ${stage.displayName}',
  if (stage != null) 'Progress: ${salesProgressLabel(stage, progress ?? '')}',
].join(' | ');

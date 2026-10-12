// Client lifecycle stages (marketing/growth funnel)
enum ClientStage {
  reach('Leads'),
  click('Leads'),
  register('Pitch'),
  consult('Follow Up'),
  followUp('Follow Up'),
  client('Sale'),
  retain('Retain'),
  refer('Refer'),
  lost('Closed');

  final String displayName;
  const ClientStage(this.displayName);

  static ClientStage fromStoredName(String? name) {
    final normalized = switch (name) {
      'reach' || 'leads' => 'click',
      'pitch' => 'register',
      'followUp' => 'consult',
      'sale' => 'client',
      _ => name,
    };
    return values.firstWhere(
      (stage) => stage.name == normalized,
      orElse: () => ClientStage.click,
    );
  }

  static List<String> storedNamesFor(String stage) => switch (stage) {
    'click' => const ['click', 'reach'],
    'consult' => const ['consult', 'followUp'],
    _ => [stage],
  };
}

const chatFunnelStages = <ClientStage>[
  ClientStage.click,
  ClientStage.register,
  ClientStage.consult,
  ClientStage.client,
  ClientStage.retain,
  ClientStage.refer,
  ClientStage.lost,
];

// Software delivery stages
enum SoftwareStage {
  notStarted('Not Started'),
  appAssigned('App Assigned'),
  panelsEnabled('Panels Enabled'),
  freePeriodActive('Free Period Active'),
  convertedToPaid('Converted to Paid'),
  customizationLight('Customization: Light'),
  customizationBusiness('Customization: Business-Type'),
  customizationBespoke('Customization: Fully Bespoke');

  final String displayName;
  const SoftwareStage(this.displayName);
}

// Content delivery stages
enum ContentStage {
  planned('Planned'),
  inProduction('In Production'),
  delivered('Delivered'),
  approved('Approved'),
  revisionRequested('Revision Requested'),
  revisionLimitReached('Revision Limit Reached');

  final String displayName;
  const ContentStage(this.displayName);
}

// Goal stages
enum GoalStage {
  draft('Draft'),
  agreed('Agreed'),
  active('Active'),
  underReview('Under Review'),
  achieved('Achieved'),
  missedGuaranteeApplied('Missed — Guarantee Applied'),
  archived('Archived');

  final String displayName;
  const GoalStage(this.displayName);
}

// Goal types
enum GoalType {
  leads('Leads'),
  customers('Customers'),
  revenue('Revenue'),
  custom('Custom');

  final String displayName;
  const GoalType(this.displayName);
}

// Plan types
enum PlanType {
  setup('Setup'),
  subscription('Subscription');

  final String displayName;
  const PlanType(this.displayName);
}

// Manual payment verification states
enum PaymentStatus {
  pending('Pending'),
  verified('Verified'),
  rejected('Rejected');

  final String displayName;
  const PaymentStatus(this.displayName);
}

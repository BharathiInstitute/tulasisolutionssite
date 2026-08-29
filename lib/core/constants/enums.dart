// Client lifecycle stages (marketing/growth funnel)
enum ClientStage {
  reach('Reach'),
  click('Click'),
  register('Register'),
  consult('Consult'),
  followUp('Follow Up'),
  client('Sales'),
  retain('Retain'),
  refer('Refer'),
  lost('Lost');

  final String displayName;
  const ClientStage(this.displayName);
}

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

// Consultation status
enum ConsultationStatus {
  scheduled('Scheduled'),
  completed('Completed'),
  cancelled('Cancelled'),
  noShow('No Show');

  final String displayName;
  const ConsultationStatus(this.displayName);
}

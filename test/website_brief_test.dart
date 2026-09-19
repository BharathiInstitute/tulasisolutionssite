import 'package:flutter_test/flutter_test.dart';
import 'package:tulasisolutionssite/core/models/website_brief.dart';

void main() {
  test('website brief preserves sections and workflow fields', () {
    final createdAt = DateTime.utc(2026, 8, 30, 10);
    final brief = WebsiteBrief(
      id: 'plan-1',
      clientId: 'client-1',
      planId: 'plan-1',
      planName: 'Basic Website',
      status: WebsiteBriefStatus.changesRequested,
      sections: const {
        'basics': {'businessName': 'Acme', 'industry': 'Retail'},
        'pages': {
          'selected': ['Home', 'About'],
        },
      },
      reviewNote: 'Add brand colors',
      requestedSections: const ['design'],
      createdAt: createdAt,
      updatedAt: createdAt,
    );

    final restored = WebsiteBrief.fromMap('plan-1', brief.toFirestore());

    expect(restored.clientId, 'client-1');
    expect(restored.status, WebsiteBriefStatus.changesRequested);
    expect(restored.sections['basics']['businessName'], 'Acme');
    expect(restored.requestedSections, ['design']);
    expect(restored.reviewNote, 'Add brand colors');
  });

  test('completion counts populated brief sections', () {
    final now = DateTime.utc(2026, 8, 30);
    final brief = WebsiteBrief(
      id: 'plan-1',
      clientId: 'client-1',
      planId: 'plan-1',
      planName: 'Basic Website',
      sections: const {
        'basics': {'businessName': 'Acme'},
        'goals': {
          'selected': ['Generate leads'],
        },
        'pages': {},
      },
      createdAt: now,
      updatedAt: now,
    );

    expect(brief.completionPercent, 22);
    expect(brief.clientCanEdit, isTrue);
    expect(
      brief.copyWith(status: WebsiteBriefStatus.approved).clientCanEdit,
      isFalse,
    );
  });
}

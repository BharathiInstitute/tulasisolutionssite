import 'package:flutter_test/flutter_test.dart';
import 'package:tulasisolutionssite/core/models/brand_brief.dart';

void main() {
  test('brand brief preserves visual and motion decisions', () {
    final now = DateTime.utc(2026, 8, 30);
    final brief = BrandBrief(
      id: 'plan-1',
      clientId: 'client-1',
      planId: 'plan-1',
      planName: 'Brand Identity',
      status: BrandBriefStatus.changesRequested,
      sections: const {
        'logo': {
          'logoType': ['Wordmark', 'Icon'],
        },
        'visualSystem': {'primaryColor': '#167A45'},
        'motion': {
          'videoFormats': ['Reels', 'YouTube'],
        },
      },
      reviewNote: 'Add two reference videos',
      requestedSections: const ['motion'],
      createdAt: now,
      updatedAt: now,
    );

    final restored = BrandBrief.fromMap('plan-1', brief.toFirestore());

    expect(restored.status, BrandBriefStatus.changesRequested);
    expect(restored.sections['visualSystem']['primaryColor'], '#167A45');
    expect(restored.sections['motion']['videoFormats'], ['Reels', 'YouTube']);
    expect(restored.requestedSections, ['motion']);
  });

  test('completion counts all nine brand sections', () {
    final now = DateTime.utc(2026, 8, 30);
    final brief = BrandBrief(
      id: 'plan-1',
      clientId: 'client-1',
      planId: 'plan-1',
      planName: 'Brand Identity',
      sections: const {
        'business': {'name': 'Acme'},
        'motion': {'animationStyle': 'Clean and quick'},
      },
      createdAt: now,
      updatedAt: now,
    );

    expect(brief.completionPercent, 22);
    expect(brief.clientCanEdit, isTrue);
    expect(
      brief.copyWith(status: BrandBriefStatus.approved).clientCanEdit,
      isFalse,
    );
  });
}

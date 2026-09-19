import 'package:flutter_test/flutter_test.dart';
import 'package:tulasisolutionssite/core/performance/performance_models.dart';

void main() {
  const approvedChecklist = [true, true, true, true, true];

  test('flags a video below the 80 percent checklist threshold', () {
    final submission = VideoSubmission(
      id: 'video-1',
      staffId: 'staff-1',
      type: VideoType.graphics,
      submittedAt: DateTime.utc(2026, 9, 2),
      checklist: const [true, true, true, false, false],
      uploadedToCorrectFolder: true,
      signedOffBy: 'pm-1',
    );

    expect(submission.checklistPercent, .6);
    expect(submission.needsResubmission, isTrue);
    expect(submission.isApproved, isFalse);
  });

  test('ranks approved submissions by formula score and projects payout', () {
    final results = PerformanceCalculator.rank(
      staffIds: const ['staff-1', 'staff-2'],
      submissions: [
        VideoSubmission(
          id: 'video-1',
          staffId: 'staff-1',
          type: VideoType.reels,
          submittedAt: DateTime.utc(2026, 9, 2),
          checklist: approvedChecklist,
          uploadedToCorrectFolder: true,
          signedOffBy: 'pm-1',
          awardedPoints: 2,
        ),
        VideoSubmission(
          id: 'video-2',
          staffId: 'staff-2',
          type: VideoType.graphics,
          submittedAt: DateTime.utc(2026, 9, 2),
          checklist: approvedChecklist,
          uploadedToCorrectFolder: true,
          signedOffBy: 'pm-1',
          awardedPoints: 1,
        ),
      ],
      hoursByStaff: const {'staff-1': 1, 'staff-2': 2},
      presentDaysByStaff: const {'staff-1': 1, 'staff-2': 1},
    );

    expect(results.first.staffId, 'staff-1');
    expect(results.first.rank, 1);
    expect(results.first.formulaScore, 2);
    expect(results.first.projectedPayout, 2513);
    expect(results.last.rank, 2);
    expect(results.last.projectedPayout, 2510);
  });

  test('does not assign automatic points to an unscored submission', () {
    final submission = VideoSubmission(
      id: 'video-1',
      staffId: 'staff-1',
      type: VideoType.reels,
      submittedAt: DateTime.utc(2026, 9, 2),
      checklist: approvedChecklist,
      uploadedToCorrectFolder: true,
      signedOffBy: 'pm-1',
    );

    expect(submission.scorePoints, 0);
  });

  test('preserves a content name and link in Firestore data', () {
    final submission = VideoSubmission(
      id: 'video-1',
      staffId: 'staff-1',
      type: VideoType.graphics,
      submittedAt: DateTime.utc(2026, 9, 2),
      contentName: 'Ganesh Chaturthi reel',
      contentLink: 'https://example.com/reel',
    );

    final data = submission.toFirestore();
    expect(data['contentName'], 'Ganesh Chaturthi reel');
    expect(data['contentLink'], 'https://example.com/reel');
  });

  test('uses an approved point override and category in the formula score', () {
    final results = PerformanceCalculator.rank(
      staffIds: const ['staff-1'],
      submissions: [
        VideoSubmission(
          id: 'video-1',
          staffId: 'staff-1',
          type: VideoType.videos,
          submittedAt: DateTime.utc(2026, 9, 2),
          checklist: approvedChecklist,
          uploadedToCorrectFolder: true,
          signedOffBy: 'pm-1',
          pointsCategory: PerformancePointCategory.tutorial,
          awardedPoints: 3.5,
        ),
      ],
      hoursByStaff: const {'staff-1': 1},
      presentDaysByStaff: const {'staff-1': 1},
    );

    expect(results.single.reelsCount, 0);
    expect(results.single.videosCount, 1);
    expect(results.single.contentPoints, 3.5);
    expect(results.single.formulaScore, 3.5);
  });

  test('groups approved points by the submission day', () {
    final results = PerformanceCalculator.rank(
      staffIds: const ['staff-1'],
      submissions: [
        VideoSubmission(
          id: 'video-1',
          staffId: 'staff-1',
          type: VideoType.graphics,
          submittedAt: DateTime(2026, 9, 2, 9),
          checklist: approvedChecklist,
          uploadedToCorrectFolder: true,
          signedOffBy: 'pm-1',
          awardedPoints: 2,
        ),
        VideoSubmission(
          id: 'video-2',
          staffId: 'staff-1',
          type: VideoType.reels,
          submittedAt: DateTime(2026, 9, 2, 16),
          checklist: approvedChecklist,
          uploadedToCorrectFolder: true,
          signedOffBy: 'pm-1',
          awardedPoints: 3.5,
        ),
        VideoSubmission(
          id: 'video-3',
          staffId: 'staff-1',
          type: VideoType.videos,
          submittedAt: DateTime(2026, 9, 3, 10),
          checklist: approvedChecklist,
          uploadedToCorrectFolder: true,
          signedOffBy: 'pm-1',
          awardedPoints: 1,
        ),
      ],
      hoursByStaff: const {},
      presentDaysByStaff: const {},
    );

    expect(results.single.pointsByDay, {
      DateTime(2026, 9, 2): 5.5,
      DateTime(2026, 9, 3): 1,
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:jva_projecttracker/models/proposal.dart';
import 'package:jva_projecttracker/services/proposal_readiness.dart';

void main() {
  final now = DateTime.utc(2024, 6, 15);

  test(
    'readyToSubmit when status is readyForReview and every section is approved',
    () {
      final readiness = deriveProposalReadiness(
        sectionProgress: 1.0,
        status: ProposalStatus.readyForReview,
        deadline: null,
        now: now,
      );

      expect(readiness, ProposalReadiness.readyToSubmit);
    },
  );

  test('behindSchedule when the deadline has already passed', () {
    final readiness = deriveProposalReadiness(
      sectionProgress: 0.5,
      status: ProposalStatus.draft,
      deadline: now.subtract(const Duration(days: 1)),
      now: now,
    );

    expect(readiness, ProposalReadiness.behindSchedule);
  });

  test(
    'atRisk when the deadline is within the risk window and progress is low',
    () {
      final readiness = deriveProposalReadiness(
        sectionProgress: 0.4,
        status: ProposalStatus.draft,
        deadline: now.add(const Duration(days: 3)),
        now: now,
      );

      expect(readiness, ProposalReadiness.atRisk);
    },
  );

  test('onTrack when the deadline is near but progress is already high', () {
    final readiness = deriveProposalReadiness(
      sectionProgress: 0.9,
      status: ProposalStatus.draft,
      deadline: now.add(const Duration(days: 3)),
      now: now,
    );

    expect(readiness, ProposalReadiness.onTrack);
  });

  test('onTrack when there is no deadline and the proposal is still draft', () {
    final readiness = deriveProposalReadiness(
      sectionProgress: 0.2,
      status: ProposalStatus.draft,
      deadline: null,
      now: now,
    );

    expect(readiness, ProposalReadiness.onTrack);
  });

  test('onTrack when the deadline is far in the future', () {
    final readiness = deriveProposalReadiness(
      sectionProgress: 0.1,
      status: ProposalStatus.draft,
      deadline: now.add(const Duration(days: 30)),
      now: now,
    );

    expect(readiness, ProposalReadiness.onTrack);
  });
}

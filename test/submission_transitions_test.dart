import 'package:flutter_test/flutter_test.dart';
import 'package:jva_projecttracker/models/submission.dart';
import 'package:jva_projecttracker/services/submission_transitions.dart';

void main() {
  group('checkSubmissionTransition', () {
    test('preparing -> submitted is allowed (the real submit event)', () {
      final check = checkSubmissionTransition(
        from: SubmissionStatus.preparing,
        to: SubmissionStatus.submitted,
      );
      expect(check.isAllowed, isTrue);
    });

    test('preparing -> awarded is rejected (nothing was submitted yet)', () {
      final check = checkSubmissionTransition(
        from: SubmissionStatus.preparing,
        to: SubmissionStatus.awarded,
      );
      expect(check.isAllowed, isFalse);
      expect(
        check.blockReason,
        SubmissionTransitionBlockReason.notYetSubmitted,
      );
    });

    test(
      'underEvaluation -> awarded is allowed (outcome after evaluation)',
      () {
        final check = checkSubmissionTransition(
          from: SubmissionStatus.underEvaluation,
          to: SubmissionStatus.awarded,
        );
        expect(check.isAllowed, isTrue);
      },
    );

    test(
      'clarificationRequested -> lost is allowed (outcome without returning to evaluation first)',
      () {
        final check = checkSubmissionTransition(
          from: SubmissionStatus.clarificationRequested,
          to: SubmissionStatus.lost,
        );
        expect(check.isAllowed, isTrue);
      },
    );

    test('submitted -> preparing is allowed as a correction', () {
      final check = checkSubmissionTransition(
        from: SubmissionStatus.submitted,
        to: SubmissionStatus.preparing,
      );
      expect(check.isAllowed, isTrue);
    });

    test('awarded -> underEvaluation is rejected (closed state)', () {
      final check = checkSubmissionTransition(
        from: SubmissionStatus.awarded,
        to: SubmissionStatus.underEvaluation,
      );
      expect(check.isAllowed, isFalse);
      expect(check.blockReason, SubmissionTransitionBlockReason.alreadyClosed);
    });

    test(
      'lost -> awarded is rejected (cannot flip one outcome to another)',
      () {
        final check = checkSubmissionTransition(
          from: SubmissionStatus.lost,
          to: SubmissionStatus.awarded,
        );
        expect(check.isAllowed, isFalse);
        expect(
          check.blockReason,
          SubmissionTransitionBlockReason.alreadyClosed,
        );
      },
    );

    test('an arbitrary non-adjacent jump is rejected', () {
      final check = checkSubmissionTransition(
        from: SubmissionStatus.preparing,
        to: SubmissionStatus.clarificationRequested,
      );
      expect(check.isAllowed, isFalse);
      expect(
        check.blockReason,
        SubmissionTransitionBlockReason.notAllowedFromCurrentStatus,
      );
    });

    test('same-status is a no-op, always allowed', () {
      final check = checkSubmissionTransition(
        from: SubmissionStatus.underEvaluation,
        to: SubmissionStatus.underEvaluation,
      );
      expect(check.isAllowed, isTrue);
    });
  });

  group('allowedSubmissionTransitions', () {
    test('closed statuses have no further transitions', () {
      expect(allowedSubmissionTransitions(SubmissionStatus.awarded), isEmpty);
      expect(allowedSubmissionTransitions(SubmissionStatus.lost), isEmpty);
      expect(allowedSubmissionTransitions(SubmissionStatus.withdrawn), isEmpty);
    });

    test('preparing only allows submitted', () {
      expect(allowedSubmissionTransitions(SubmissionStatus.preparing), [
        SubmissionStatus.submitted,
      ]);
    });

    test(
      'underEvaluation allows clarification, both outcomes, withdrawal, and correcting back to submitted',
      () {
        final allowed = allowedSubmissionTransitions(
          SubmissionStatus.underEvaluation,
        );
        expect(allowed.toSet(), {
          SubmissionStatus.clarificationRequested,
          SubmissionStatus.awarded,
          SubmissionStatus.lost,
          SubmissionStatus.withdrawn,
          SubmissionStatus.submitted,
        });
      },
    );
  });
}

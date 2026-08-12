import 'package:jva_projecttracker/models/submission.dart';

/// Why a [SubmissionStatus] transition is unavailable, so the UI can explain
/// itself instead of just disabling a menu entry — see
/// `submission_workspace_screen.dart`'s status dropdown.
enum SubmissionTransitionBlockReason {
  /// The submission hasn't been recorded as sent yet, so an evaluation/
  /// outcome status doesn't make sense.
  notYetSubmitted,

  /// The submission has already reached a closed/terminal state
  /// (awarded/lost/withdrawn) — reopening it is a bigger business event
  /// (effectively un-awarding a deal) than a simple status correction, and
  /// isn't a transition this app models.
  alreadyClosed,

  /// Not a recognized forward step or an adjacent correction from the
  /// current status.
  notAllowedFromCurrentStatus,
}

/// The result of checking one candidate transition — either allowed, or
/// blocked with a reason the UI can render as an explanation rather than a
/// silently disabled option.
class SubmissionTransitionCheck {
  const SubmissionTransitionCheck.allowed() : blockReason = null;

  const SubmissionTransitionCheck.blocked(this.blockReason);

  final SubmissionTransitionBlockReason? blockReason;

  bool get isAllowed => blockReason == null;
}

/// The submission lifecycle's forward path — what the previous audit called
/// "the implied lifecycle," now made explicit rather than left as an
/// unenforced convention. `clarificationRequested` is optional (evaluation
/// can go straight to an outcome), so both `underEvaluation` and
/// `clarificationRequested` may move directly to `awarded`/`lost`.
const _kForwardSteps = <SubmissionStatus, List<SubmissionStatus>>{
  SubmissionStatus.preparing: [SubmissionStatus.submitted],
  SubmissionStatus.submitted: [
    SubmissionStatus.underEvaluation,
    SubmissionStatus.withdrawn,
  ],
  SubmissionStatus.underEvaluation: [
    SubmissionStatus.clarificationRequested,
    SubmissionStatus.awarded,
    SubmissionStatus.lost,
    SubmissionStatus.withdrawn,
  ],
  SubmissionStatus.clarificationRequested: [
    SubmissionStatus.underEvaluation,
    SubmissionStatus.awarded,
    SubmissionStatus.lost,
    SubmissionStatus.withdrawn,
  ],
};

/// Adjacent-step corrections — moving back to the status immediately before
/// the current one, for when a status was recorded by mistake. Deliberately
/// narrower than "any backward move": correcting `submitted` back to
/// `preparing` is a plausible slip; reopening an `awarded` submission back
/// to `underEvaluation` is not a correction, it's reversing a business
/// outcome, and isn't offered (see [SubmissionTransitionBlockReason.alreadyClosed]).
const _kCorrections = <SubmissionStatus, SubmissionStatus>{
  SubmissionStatus.submitted: SubmissionStatus.preparing,
  SubmissionStatus.underEvaluation: SubmissionStatus.submitted,
  SubmissionStatus.clarificationRequested: SubmissionStatus.underEvaluation,
};

/// Checks whether [from] → [to] is a real transition this app's submission
/// lifecycle supports — either a forward step or an adjacent correction.
/// Never allows leaving a closed state ([SubmissionStatus.isClosed]); never
/// allows jumping straight to an outcome status without having passed
/// through at least `submitted` first.
SubmissionTransitionCheck checkSubmissionTransition({
  required SubmissionStatus from,
  required SubmissionStatus to,
}) {
  if (from == to) return const SubmissionTransitionCheck.allowed();

  if (from.isClosed) {
    return const SubmissionTransitionCheck.blocked(
      SubmissionTransitionBlockReason.alreadyClosed,
    );
  }

  if (to.isClosed && from == SubmissionStatus.preparing) {
    return const SubmissionTransitionCheck.blocked(
      SubmissionTransitionBlockReason.notYetSubmitted,
    );
  }

  final forward = _kForwardSteps[from] ?? const [];
  if (forward.contains(to)) return const SubmissionTransitionCheck.allowed();

  final correction = _kCorrections[from];
  if (correction == to) return const SubmissionTransitionCheck.allowed();

  return const SubmissionTransitionCheck.blocked(
    SubmissionTransitionBlockReason.notAllowedFromCurrentStatus,
  );
}

/// Every status [from] can legally move to right now — forward steps plus
/// the one available correction, if any. Used to build the dropdown's
/// enabled options.
List<SubmissionStatus> allowedSubmissionTransitions(SubmissionStatus from) {
  if (from.isClosed) return const [];
  return [
    ...?_kForwardSteps[from],
    if (_kCorrections[from] != null) _kCorrections[from]!,
  ];
}

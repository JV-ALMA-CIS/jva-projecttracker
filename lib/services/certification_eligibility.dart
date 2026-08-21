import 'package:jva_projecttracker/models/company_intelligence/certification.dart';
import 'package:jva_projecttracker/models/opportunity.dart';

/// Severity of a computed eligibility gap — drives which [AppStatusColors]
/// a gap chip renders with (see `opportunity_workspace_screen.dart`).
enum EligibilityGapSeverity { warning, danger }

class EligibilityGap {
  const EligibilityGap({
    required this.label,
    required this.severity,
    required this.detail,
  });

  final String label;
  final EligibilityGapSeverity severity;
  final String detail;
}

/// Parses a company or tender-stated grade string into its leading integer,
/// tolerating forms like "5", "NCA5", "NCA 5", "Class 5", "5+". Returns
/// `null` when nothing numeric can be found — an unparseable grade is
/// reported as a gap rather than guessed at (see [canSatisfyNcaRequirement]).
int? parseNcaClassNumber(String? grade) {
  if (grade == null) return null;
  final match = RegExp(r'(\d+)').firstMatch(grade);
  if (match == null) return null;
  return int.tryParse(match.group(1)!);
}

/// NCA (National Construction Authority, Kenya) contractor registration is
/// graded 1–8, where a HIGHER class number means a HIGHER capability
/// ceiling (NCA 1 is the highest tier, permitted to bid on the largest
/// contracts; NCA 8 the lowest/entry tier) — counterintuitive versus most
/// "grade 1 = best" school-grading conventions, so this is spelled out
/// explicitly rather than left to be inferred from the comparison below.
/// A company holding NCA class 7 satisfies a tender requiring NCA class 5
/// (7 > 5), but NCA class 5 does NOT satisfy a requirement for NCA class 7.
///
/// Returns `true` only when both grades parse as numbers and the held
/// class is numerically >= the required class. An unparseable held or
/// required grade returns `false` — never assumed to satisfy silently.
bool canSatisfyNcaRequirement({
  required String? held,
  required String? required,
}) {
  final heldNumber = parseNcaClassNumber(held);
  final requiredNumber = parseNcaClassNumber(required);
  if (heldNumber == null || requiredNumber == null) return false;
  return heldNumber >= requiredNumber;
}

/// True when [certification] is genuinely usable today — status recorded
/// as active/pending is not enough on its own if the expiry date has
/// already passed (see [Certification.status]'s own doc comment on why the
/// two can disagree). [now] is injected for testability.
bool isCertificationCurrentlyValid(
  Certification certification, {
  required DateTime now,
}) {
  if (certification.status == CertificationStatus.expired ||
      certification.status == CertificationStatus.revoked) {
    return false;
  }
  final expiry = certification.expiryDate;
  if (expiry != null && expiry.isBefore(now)) return false;
  return true;
}

/// True when at least one currently-valid held certification satisfies
/// [requirement]. NCA requirements use the grade-aware
/// [canSatisfyNcaRequirement] comparison; every other type matches by
/// `type` equality alone when [requirement.gradeOrClass] is null, or by
/// `type` + exact case-insensitive grade match otherwise — deliberately no
/// numeric-comparison guess for non-NCA grades, since there's no
/// established "higher is better" convention to rely on for e.g. ISO
/// certificate numbers.
bool _isRequirementSatisfied(
  OpportunityCertificationRequirement requirement,
  List<Certification> validHeldCertifications,
) {
  final candidates = validHeldCertifications.where(
    (c) => c.type == requirement.type,
  );
  if (candidates.isEmpty) return false;

  if (requirement.type == CertificationType.nca) {
    return candidates.any(
      (c) => canSatisfyNcaRequirement(
        held: c.gradeOrClass,
        required: requirement.gradeOrClass,
      ),
    );
  }

  if (requirement.gradeOrClass == null ||
      requirement.gradeOrClass!.trim().isEmpty) {
    // "Must hold an active certification of this type" — type match alone
    // is enough, no grade was asked for.
    return true;
  }

  return candidates.any(
    (c) =>
        (c.gradeOrClass ?? '').trim().toLowerCase() ==
        requirement.gradeOrClass!.trim().toLowerCase(),
  );
}

/// The gap engine: for each of [requirements], reports a gap when no
/// currently-valid held certification (from [heldCertifications], filtered
/// internally to only those valid as of [now]) satisfies it. No
/// requirements → empty list, never a fabricated gap. An expired or
/// revoked certification never counts toward satisfying a requirement,
/// even if [Certification.status] still says "active."
List<EligibilityGap> computeEligibilityGaps({
  required List<OpportunityCertificationRequirement> requirements,
  required List<Certification> heldCertifications,
  required DateTime now,
}) {
  if (requirements.isEmpty) return const [];

  final validHeld = heldCertifications
      .where((c) => isCertificationCurrentlyValid(c, now: now))
      .toList();

  final gaps = <EligibilityGap>[];
  for (final requirement in requirements) {
    if (_isRequirementSatisfied(requirement, validHeld)) continue;

    final heldOfType = validHeld
        .where((c) => c.type == requirement.type)
        .toList();
    final detail = heldOfType.isEmpty
        ? 'Company holds no active ${requirement.type.label}'
        : 'Requires ${requirement.label}; company holds '
              '${heldOfType.map((c) => c.gradeOrClass ?? c.type.label).join(', ')}';

    gaps.add(
      EligibilityGap(
        label: requirement.label,
        severity: heldOfType.isEmpty
            ? EligibilityGapSeverity.danger
            : EligibilityGapSeverity.warning,
        detail: detail,
      ),
    );
  }
  return gaps;
}

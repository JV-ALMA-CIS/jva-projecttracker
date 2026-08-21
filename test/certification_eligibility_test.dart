import 'package:flutter_test/flutter_test.dart';
import 'package:jva_projecttracker/models/company_intelligence/certification.dart';
import 'package:jva_projecttracker/models/opportunity.dart';
import 'package:jva_projecttracker/services/certification_eligibility.dart';

Certification _cert({
  String id = 'cert-1',
  CertificationType type = CertificationType.nca,
  String? gradeOrClass,
  CertificationStatus status = CertificationStatus.active,
  DateTime? expiryDate,
}) {
  final now = DateTime.utc(2024, 1, 1);
  return Certification(
    id: id,
    name: 'Certification $id',
    type: type,
    gradeOrClass: gradeOrClass,
    status: status,
    expiryDate: expiryDate,
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  group('parseNcaClassNumber', () {
    test('parses a bare number', () {
      expect(parseNcaClassNumber('5'), 5);
    });

    test('parses NCA-prefixed forms', () {
      expect(parseNcaClassNumber('NCA5'), 5);
      expect(parseNcaClassNumber('NCA 5'), 5);
      expect(parseNcaClassNumber('Class 7'), 7);
    });

    test('returns null for unparseable input', () {
      expect(parseNcaClassNumber(null), isNull);
      expect(parseNcaClassNumber(''), isNull);
      expect(parseNcaClassNumber('unknown'), isNull);
    });
  });

  group('canSatisfyNcaRequirement', () {
    test('a higher held class satisfies a lower requirement', () {
      expect(canSatisfyNcaRequirement(held: '7', required: '5'), isTrue);
    });

    test('an equal held class satisfies the requirement', () {
      expect(canSatisfyNcaRequirement(held: '5', required: '5'), isTrue);
    });

    test('a lower held class does not satisfy a higher requirement', () {
      expect(canSatisfyNcaRequirement(held: '5', required: '7'), isFalse);
    });

    test('unparseable held or required grade never satisfies', () {
      expect(canSatisfyNcaRequirement(held: null, required: '5'), isFalse);
      expect(canSatisfyNcaRequirement(held: '5', required: null), isFalse);
      expect(canSatisfyNcaRequirement(held: 'unknown', required: '5'), isFalse);
    });
  });

  group('isCertificationCurrentlyValid', () {
    final now = DateTime.utc(2024, 6, 15);

    test('active with no expiry is valid', () {
      expect(isCertificationCurrentlyValid(_cert(), now: now), isTrue);
    });

    test('active with a future expiry is valid', () {
      final cert = _cert(expiryDate: now.add(const Duration(days: 30)));
      expect(isCertificationCurrentlyValid(cert, now: now), isTrue);
    });

    test('active with a past expiry is not valid', () {
      final cert = _cert(expiryDate: now.subtract(const Duration(days: 1)));
      expect(isCertificationCurrentlyValid(cert, now: now), isFalse);
    });

    test('status expired is never valid regardless of expiryDate', () {
      final cert = _cert(
        status: CertificationStatus.expired,
        expiryDate: now.add(const Duration(days: 30)),
      );
      expect(isCertificationCurrentlyValid(cert, now: now), isFalse);
    });

    test('status revoked is never valid', () {
      final cert = _cert(status: CertificationStatus.revoked);
      expect(isCertificationCurrentlyValid(cert, now: now), isFalse);
    });
  });

  group('computeEligibilityGaps', () {
    final now = DateTime.utc(2024, 6, 15);

    test('no requirements means no gaps', () {
      final gaps = computeEligibilityGaps(
        requirements: const [],
        heldCertifications: [_cert(gradeOrClass: '5')],
        now: now,
      );
      expect(gaps, isEmpty);
    });

    test('NCA 5 held vs NCA 7 required is a gap', () {
      final gaps = computeEligibilityGaps(
        requirements: const [
          OpportunityCertificationRequirement(
            type: CertificationType.nca,
            gradeOrClass: '7',
            label: 'NCA Class 7',
          ),
        ],
        heldCertifications: [_cert(gradeOrClass: '5')],
        now: now,
      );
      expect(gaps, hasLength(1));
      expect(gaps.single.label, 'NCA Class 7');
      expect(gaps.single.severity, EligibilityGapSeverity.warning);
    });

    test('NCA 7 held vs NCA 5 required is not a gap', () {
      final gaps = computeEligibilityGaps(
        requirements: const [
          OpportunityCertificationRequirement(
            type: CertificationType.nca,
            gradeOrClass: '5',
            label: 'NCA Class 5',
          ),
        ],
        heldCertifications: [_cert(gradeOrClass: '7')],
        now: now,
      );
      expect(gaps, isEmpty);
    });

    test('an expired NCA certification does not clear the gap', () {
      final gaps = computeEligibilityGaps(
        requirements: const [
          OpportunityCertificationRequirement(
            type: CertificationType.nca,
            gradeOrClass: '5',
            label: 'NCA Class 5',
          ),
        ],
        heldCertifications: [
          _cert(
            gradeOrClass: '7',
            expiryDate: now.subtract(const Duration(days: 1)),
          ),
        ],
        now: now,
      );
      expect(gaps, hasLength(1));
    });

    test('missing certification type entirely is a danger-severity gap', () {
      final gaps = computeEligibilityGaps(
        requirements: const [
          OpportunityCertificationRequirement(
            type: CertificationType.iso,
            label: 'ISO 9001',
          ),
        ],
        heldCertifications: [_cert(type: CertificationType.nca)],
        now: now,
      );
      expect(gaps, hasLength(1));
      expect(gaps.single.severity, EligibilityGapSeverity.danger);
    });

    test('non-NCA requirement with no grade is satisfied by type alone', () {
      final gaps = computeEligibilityGaps(
        requirements: const [
          OpportunityCertificationRequirement(
            type: CertificationType.tax,
            label: 'Tax Compliance',
          ),
        ],
        heldCertifications: [_cert(type: CertificationType.tax)],
        now: now,
      );
      expect(gaps, isEmpty);
    });

    test(
      'non-NCA requirement with a grade needs an exact case-insensitive match',
      () {
        final matching = computeEligibilityGaps(
          requirements: const [
            OpportunityCertificationRequirement(
              type: CertificationType.iso,
              gradeOrClass: 'ISO 9001',
              label: 'ISO 9001',
            ),
          ],
          heldCertifications: [
            _cert(type: CertificationType.iso, gradeOrClass: 'iso 9001'),
          ],
          now: now,
        );
        expect(matching, isEmpty);

        final mismatched = computeEligibilityGaps(
          requirements: const [
            OpportunityCertificationRequirement(
              type: CertificationType.iso,
              gradeOrClass: 'ISO 9001',
              label: 'ISO 9001',
            ),
          ],
          heldCertifications: [
            _cert(type: CertificationType.iso, gradeOrClass: 'ISO 14001'),
          ],
          now: now,
        );
        expect(mismatched, hasLength(1));
      },
    );

    test('multiple requirements report multiple independent gaps', () {
      final gaps = computeEligibilityGaps(
        requirements: const [
          OpportunityCertificationRequirement(
            type: CertificationType.nca,
            gradeOrClass: '7',
            label: 'NCA Class 7',
          ),
          OpportunityCertificationRequirement(
            type: CertificationType.tax,
            label: 'Tax Compliance',
          ),
        ],
        heldCertifications: [
          _cert(type: CertificationType.nca, gradeOrClass: '5'),
        ],
        now: now,
      );
      expect(gaps, hasLength(2));
    });
  });
}

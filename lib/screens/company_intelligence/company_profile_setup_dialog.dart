import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jva_projecttracker/l10n/app_strings.dart';
import 'package:jva_projecttracker/models/company_intelligence/business_unit.dart';
import 'package:jva_projecttracker/models/company_intelligence/capability.dart';
import 'package:jva_projecttracker/models/company_intelligence/industry.dart';
import 'package:jva_projecttracker/models/company_intelligence/service.dart';
import 'package:jva_projecttracker/services/providers.dart';
import 'package:jva_projecttracker/theme/app_theme.dart';

/// One editable suggested entity in the setup dialog — a name/summary pair
/// the user can accept as-is, edit, or deselect entirely before saving.
class _SuggestedEntity {
  _SuggestedEntity(this.name, this.summary) : selected = true;

  String name;
  String summary;
  bool selected;
}

/// The complementary path to `ProjectExtractionReviewScreen`'s per-document
/// "create & link" suggestion chips (see §1 Option B in the brief this
/// implements): a one-time, in-app "Set up company profile" action so
/// Company Intelligence isn't empty even before the first document is
/// uploaded/reviewed. Available to any authenticated user who can reach the
/// Company Intelligence hub — no admin role check, matching
/// firestore.rules' `isAuthenticated()` write rule on every collection this
/// writes to. Idempotent by exact name match: re-running only creates
/// entities whose name doesn't already exist in that collection.
Future<void> showCompanyProfileSetupDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (context) => const _CompanyProfileSetupDialog(),
  );
}

class _CompanyProfileSetupDialog extends ConsumerStatefulWidget {
  const _CompanyProfileSetupDialog();

  @override
  ConsumerState<_CompanyProfileSetupDialog> createState() =>
      _CompanyProfileSetupDialogState();
}

class _CompanyProfileSetupDialogState
    extends ConsumerState<_CompanyProfileSetupDialog> {
  bool _saving = false;

  // Pre-filled defaults for a construction/JV contractor, per the brief —
  // every field remains user-editable/deselectable before Save; nothing is
  // written until the user explicitly confirms.
  final List<_SuggestedEntity> _businessUnits = [
    _SuggestedEntity(
      'Construction',
      'General contracting and construction delivery.',
    ),
    _SuggestedEntity(
      'Embassy & Diplomatic Facilities',
      'Construction, renovation, and facilities work for embassies and diplomatic compounds.',
    ),
  ];
  final List<_SuggestedEntity> _capabilities = [
    _SuggestedEntity(
      'Roof Replacement & Waterproofing',
      'Roof replacement, repair, and waterproofing works.',
    ),
    _SuggestedEntity(
      'Interior Renovation & Fit-Out',
      'Interior renovation, refurbishment, and fit-out works.',
    ),
  ];
  final List<_SuggestedEntity> _industries = [
    _SuggestedEntity('Diplomatic & Embassy Compounds', ''),
  ];
  final List<_SuggestedEntity> _services = [
    _SuggestedEntity(
      'General Contracting',
      'End-to-end general contracting services.',
    ),
  ];

  Future<void> _save() async {
    setState(() => _saving = true);
    final now = DateTime.now();

    String slugify(String name) {
      final slug = name
          .trim()
          .toLowerCase()
          .replaceAll(RegExp(r'[^a-z0-9\s-]'), '')
          .replaceAll(RegExp(r'\s+'), '-');
      return slug.isEmpty ? 'entity' : slug;
    }

    final existingBusinessUnits = await ref.read(
      businessUnitsStreamProvider.future,
    );
    final existingCapabilities = await ref.read(
      capabilitiesStreamProvider.future,
    );
    final existingIndustries = await ref.read(industriesStreamProvider.future);
    final existingServices = await ref.read(servicesStreamProvider.future);

    final existingBuNames = existingBusinessUnits
        .map((b) => b.name.trim().toLowerCase())
        .toSet();
    final existingCapNames = existingCapabilities
        .map((c) => c.name.trim().toLowerCase())
        .toSet();
    final existingIndNames = existingIndustries
        .map((i) => i.name.trim().toLowerCase())
        .toSet();
    final existingSvcNames = existingServices
        .map((s) => s.name.trim().toLowerCase())
        .toSet();

    for (final e in _businessUnits) {
      if (!e.selected ||
          existingBuNames.contains(e.name.trim().toLowerCase())) {
        continue;
      }
      await ref
          .read(businessUnitServiceProvider)
          .create(
            BusinessUnit(
              id: '',
              name: e.name.trim(),
              slug: slugify(e.name),
              summary: e.summary.trim(),
              createdAt: now,
              updatedAt: now,
            ),
          );
    }

    for (final e in _capabilities) {
      if (!e.selected ||
          existingCapNames.contains(e.name.trim().toLowerCase())) {
        continue;
      }
      await ref
          .read(capabilityServiceProvider)
          .create(
            Capability(
              id: '',
              name: e.name.trim(),
              slug: slugify(e.name),
              summary: e.summary.trim(),
              createdAt: now,
              updatedAt: now,
            ),
          );
    }

    for (final e in _industries) {
      if (!e.selected ||
          existingIndNames.contains(e.name.trim().toLowerCase())) {
        continue;
      }
      await ref
          .read(industryServiceProvider)
          .create(
            Industry(
              id: '',
              name: e.name.trim(),
              createdAt: now,
              updatedAt: now,
            ),
          );
    }

    for (final e in _services) {
      if (!e.selected ||
          existingSvcNames.contains(e.name.trim().toLowerCase())) {
        continue;
      }
      await ref
          .read(serviceServiceProvider)
          .create(
            ServiceModel(
              id: '',
              name: e.name.trim(),
              slug: slugify(e.name),
              summary: e.summary.trim(),
              createdAt: now,
              updatedAt: now,
            ),
          );
    }

    if (!mounted) return;
    final strings = ref.read(appStringsProvider);
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(strings.companyProfileCreatedMessage)),
    );
  }

  Widget _buildGroup(String title, List<_SuggestedEntity> entities) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.labelLarge),
        for (final e in entities)
          CheckboxListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            value: e.selected,
            onChanged: (checked) =>
                setState(() => e.selected = checked ?? false),
            title: TextFormField(
              initialValue: e.name,
              enabled: e.selected,
              decoration: const InputDecoration(isDense: true),
              onChanged: (v) => e.name = v,
            ),
          ),
        const SizedBox(height: AppSpacing.sm),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final strings = ref.watch(appStringsProvider);

    return AlertDialog(
      title: Text(strings.setUpCompanyProfileTitle),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                strings.setUpCompanyProfileDialogHint,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: AppSpacing.md),
              _buildGroup(strings.businessUnitsTitle, _businessUnits),
              _buildGroup(strings.capabilitiesTitle, _capabilities),
              _buildGroup(strings.industriesTitle, _industries),
              _buildGroup(strings.servicesTitle, _services),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: Text(strings.cancelButton),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  height: 16,
                  width: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(strings.saveButton),
        ),
      ],
    );
  }
}

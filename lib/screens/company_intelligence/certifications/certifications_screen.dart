import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:jva_projecttracker/l10n/app_strings.dart';
import 'package:jva_projecttracker/models/company_intelligence/certification.dart';
import 'package:jva_projecttracker/screens/company_intelligence/certifications/certification_form_screen.dart';
import 'package:jva_projecttracker/services/providers.dart';
import 'package:jva_projecttracker/theme/app_page_route.dart';
import 'package:jva_projecttracker/theme/app_theme.dart';
import 'package:jva_projecttracker/widgets/adaptive_list_grid.dart';
import 'package:jva_projecttracker/widgets/empty_state.dart';
import 'package:jva_projecttracker/widgets/entity_card.dart';
import 'package:jva_projecttracker/widgets/page_back_button.dart';
import 'package:jva_projecttracker/widgets/page_header.dart';
import 'package:jva_projecttracker/widgets/status_badge.dart';

(String, Color) _statusChip(AppStrings strings, Certification c, DateTime now) {
  final expired =
      c.status == CertificationStatus.expired ||
      (c.expiryDate != null && c.expiryDate!.isBefore(now));
  if (c.status == CertificationStatus.revoked) {
    return (CertificationStatus.revoked.label, AppStatusColors.danger);
  }
  if (expired) {
    return (strings.certificationExpiredLabel, AppStatusColors.danger);
  }
  if (c.status == CertificationStatus.pending) {
    return (CertificationStatus.pending.label, AppStatusColors.warning);
  }
  return (CertificationStatus.active.label, AppStatusColors.success);
}

/// Search/filter parity fix on top of the `heroTag: null` fix — see
/// `BusinessUnitsScreen`'s doc comment. Filters by [CertificationType] and
/// by expiry, using the same effective-status logic `_statusChip` already
/// computes, so the "Expired" filter matches what the badge on each card
/// actually shows rather than a raw `CertificationStatus.expired` that
/// misses certifications whose `expiryDate` has simply lapsed without the
/// status field being updated.
class CertificationsScreen extends ConsumerStatefulWidget {
  const CertificationsScreen({super.key});

  @override
  ConsumerState<CertificationsScreen> createState() =>
      _CertificationsScreenState();
}

class _CertificationsScreenState extends ConsumerState<CertificationsScreen> {
  final _searchController = TextEditingController();
  String _query = '';
  CertificationType? _typeFilter;
  bool _expiredOnly = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Certification> _applyFilters(
    List<Certification> certifications,
    DateTime now,
  ) {
    final query = _query.trim().toLowerCase();
    return certifications.where((c) {
      if (_typeFilter != null && c.type != _typeFilter) return false;
      if (_expiredOnly) {
        final expired =
            c.status == CertificationStatus.expired ||
            (c.expiryDate != null && c.expiryDate!.isBefore(now));
        if (!expired) return false;
      }
      if (query.isEmpty) return true;
      return c.name.toLowerCase().contains(query) ||
          (c.gradeOrClass ?? '').toLowerCase().contains(query) ||
          (c.issuingBody ?? '').toLowerCase().contains(query) ||
          (c.certificateNumber ?? '').toLowerCase().contains(query) ||
          c.notes.toLowerCase().contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final strings = ref.watch(appStringsProvider);
    final certificationsAsync = ref.watch(certificationsStreamProvider);
    final now = DateTime.now();

    return Scaffold(
      floatingActionButton: FloatingActionButton(
        heroTag: null,
        onPressed: () =>
            pushSlideFade(context, const CertificationFormScreen()),
        child: const Icon(Icons.add),
      ),
      body: SafeArea(
        child: certificationsAsync.when(
          data: (certifications) {
            if (certifications.isEmpty) {
              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.lg,
                      AppSpacing.lg,
                      AppSpacing.lg,
                      0,
                    ),
                    child: PageHeader(
                      leading: PageBackButton(),
                      icon: Icons.verified_outlined,
                      title: strings.certificationsTitle,
                      subtitle: strings.certificationsSubtitle,
                      accentColor: AppEntityColors.certification,
                    ),
                  ),
                  Expanded(
                    child: EmptyState(
                      icon: Icons.verified_outlined,
                      title: strings.noCertificationsYet,
                      action: FilledButton.icon(
                        onPressed: () => pushSlideFade(
                          context,
                          const CertificationFormScreen(),
                        ),
                        icon: const Icon(Icons.add),
                        label: Text(strings.newCertificationTitle),
                      ),
                    ),
                  ),
                ],
              );
            }

            final types = {for (final c in certifications) c.type}.toList()
              ..sort((a, b) => a.name.compareTo(b.name));
            final filtered = _applyFilters(certifications, now);

            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    AppSpacing.lg,
                    AppSpacing.lg,
                    0,
                  ),
                  child: PageHeader(
                    leading: PageBackButton(),
                    icon: Icons.verified_outlined,
                    title: strings.certificationsTitle,
                    subtitle: strings.certificationsSubtitle,
                    accentColor: AppEntityColors.certification,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    AppSpacing.md,
                    AppSpacing.lg,
                    0,
                  ),
                  child: SearchBar(
                    controller: _searchController,
                    hintText: strings.searchCertificationsHint,
                    leading: const Icon(Icons.search),
                    onChanged: (v) => setState(() => _query = v),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    AppSpacing.md,
                    AppSpacing.lg,
                    0,
                  ),
                  child: Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: [
                      FilterChip(
                        label: Text(strings.filterAllLabel),
                        selected: _typeFilter == null && !_expiredOnly,
                        onSelected: (_) => setState(() {
                          _typeFilter = null;
                          _expiredOnly = false;
                        }),
                      ),
                      FilterChip(
                        label: Text(strings.certificationExpiredLabel),
                        selected: _expiredOnly,
                        onSelected: (selected) =>
                            setState(() => _expiredOnly = selected),
                      ),
                      for (final t in types)
                        FilterChip(
                          label: Text(strings.certificationTypeLabel(t)),
                          selected: _typeFilter == t,
                          onSelected: (selected) =>
                              setState(() => _typeFilter = selected ? t : null),
                        ),
                    ],
                  ),
                ),
                Expanded(
                  child: filtered.isEmpty
                      ? EmptyState(
                          icon: Icons.search_off_outlined,
                          title: strings.noCertificationsMatchFilter,
                          compact: true,
                        )
                      : AdaptiveListGrid(
                          items: filtered,
                          itemBuilder: (context, c) {
                            final (statusLabel, statusColor) = _statusChip(
                              strings,
                              c,
                              now,
                            );
                            final subtitleParts = [
                              strings.certificationTypeLabel(c.type),
                              if ((c.gradeOrClass ?? '').isNotEmpty)
                                c.gradeOrClass!,
                            ];
                            return EntityCard(
                              title: c.name,
                              subtitle: subtitleParts.join(' · '),
                              statusBadge: StatusBadge(
                                label: statusLabel,
                                color: statusColor,
                              ),
                              accentColor: AppEntityColors.certification,
                              metaChips: [
                                if (c.expiryDate != null)
                                  Chip(
                                    avatar: const Icon(
                                      Icons.event_outlined,
                                      size: 14,
                                    ),
                                    label: Text(
                                      DateFormat.yMMMd(
                                        strings.locale.toString(),
                                      ).format(c.expiryDate!),
                                    ),
                                    visualDensity: VisualDensity.compact,
                                  ),
                                if (c.issuingBody?.isNotEmpty ?? false)
                                  Chip(
                                    label: Text(c.issuingBody!),
                                    visualDensity: VisualDensity.compact,
                                  ),
                              ],
                              onTap: () => pushSlideFade(
                                context,
                                CertificationFormScreen(certificationId: c.id),
                              ),
                            );
                          },
                        ),
                ),
              ],
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stackTrace) =>
              Center(child: Text(strings.errorPrefix(error))),
        ),
      ),
    );
  }
}

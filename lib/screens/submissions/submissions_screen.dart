import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jva_projecttracker/l10n/app_strings.dart';
import 'package:jva_projecttracker/screens/submissions/submission_workspace_screen.dart';
import 'package:jva_projecttracker/services/providers.dart';
import 'package:jva_projecttracker/theme/app_page_route.dart';
import 'package:jva_projecttracker/theme/app_theme.dart';
import 'package:jva_projecttracker/widgets/empty_state.dart';
import 'package:jva_projecttracker/widgets/page_header.dart';
import 'package:jva_projecttracker/widgets/submission_status_style.dart';

/// Submission entry point.
///
/// This screen is intentionally a navigation/list screen rather than a second
/// Submission Workspace. The actual submission workflow lives in
/// [SubmissionWorkspaceScreen].
class SubmissionsScreen extends ConsumerWidget {
  const SubmissionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(appStringsProvider);
    final submissionsAsync = ref.watch(submissionsStreamProvider);

    return Scaffold(
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.lg,
              0,
            ),
            child: PageHeader(
              icon: Icons.send_outlined,
              title: strings.submissionsSectionTitle,
            ),
          ),
          Expanded(
            child: submissionsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) =>
                  Center(child: Text(strings.errorPrefix(error))),
              data: (submissions) {
                if (submissions.isEmpty) {
                  return EmptyState(
                    icon: Icons.send_outlined,
                    title: strings.noOpenSubmissions,
                    compact: false,
                  );
                }

                return ListView(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  children: [
                    for (final submission in submissions)
                      _SubmissionCard(submission: submission),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _SubmissionCard extends ConsumerWidget {
  const _SubmissionCard({required this.submission});

  final dynamic submission;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(appStringsProvider);
    final statusColor = submissionStatusColor(submission.status);

    final opportunityAsync = ref.watch(
      opportunityByIdProvider(submission.opportunityId),
    );

    final title = opportunityAsync.when(
      data: (opportunity) =>
          opportunity?.title ?? strings.submissionWorkspaceTitle,
      loading: () => strings.submissionWorkspaceTitle,
      error: (_, _) => strings.submissionWorkspaceTitle,
    );

    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        leading: CircleAvatar(
          backgroundColor: statusColor.withValues(alpha: 0.15),
          child: Icon(Icons.send_outlined, color: statusColor),
        ),
        title: Text(title, maxLines: 2, overflow: TextOverflow.ellipsis),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: AppSpacing.xs),
          child: Text(strings.submissionStatusLabel(submission.status)),
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => pushSlideFade(
          context,
          SubmissionWorkspaceScreen(opportunityId: submission.opportunityId),
        ),
      ),
    );
  }
}

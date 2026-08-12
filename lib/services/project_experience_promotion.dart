import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jva_projecttracker/models/company_intelligence/experience.dart';
import 'package:jva_projecttracker/models/library_document.dart';
import 'package:jva_projecttracker/models/project.dart';
import 'package:jva_projecttracker/services/providers.dart';

/// Deterministically maps the fields with an honest source on [project]
/// into a new `Experience`. Relationship IDs and the outcome/achievements/
/// lessons-learned narrative are never fabricated from thin air — but when
/// this project has a *reviewed* AI Knowledge Extraction
/// (`documentsForProjectProvider`, `aiExtractionStatus == reviewed`), those
/// honestly-extracted-and-human-approved values pre-fill the same fields
/// that would otherwise be left blank. Idempotent-by-caller:
/// `ProjectService.linkExperience` records the result, and both call sites
/// (project_form_screen.dart, project_workspace_screen.dart) only offer
/// this action when `project.experienceId == null`.
///
/// Extracted here specifically so the Project Workspace (which needs the
/// same "publish as Experience" action) calls this instead of
/// re-implementing it — see ProjectWorkspaceScreen's brief: "reuse the
/// existing... publishing workflow. Do not duplicate any business logic."
Future<String> promoteProjectToExperience(
  WidgetRef ref,
  Project project,
) async {
  final documents = await ref.read(
    documentsForProjectProvider(project.id).future,
  );
  LibraryDocument? reviewedExtraction;
  for (final doc in documents) {
    if (doc.aiExtractionStatus == DocumentExtractionStatus.reviewed) {
      reviewedExtraction = doc;
      break;
    }
  }

  final now = DateTime.now();
  // Experience.summary/outcome have no separate "scope" field of their own,
  // so when the project's own description is empty, scopeOfWorks is the
  // next-best honest source — both come from the project record itself
  // (never invented), just picked in order of how well each actually reads
  // as a one-paragraph summary.
  final summaryOrOutcome = project.description.trim().isNotEmpty
      ? project.description
      : project.scopeOfWorks;

  final experienceId = await ref
      .read(experienceServiceProvider)
      .create(
        Experience(
          id: '',
          title: project.name,
          summary: summaryOrOutcome,
          outcome: summaryOrOutcome,
          clientName: project.client.isEmpty ? null : project.client,
          fundingSource: project.fundingAgency.isEmpty
              ? null
              : project.fundingAgency,
          country: reviewedExtraction?.aiExtractedCountry,
          startDate: project.startDate,
          endDate: project.endDate,
          contractValue: project.contractValueAmount,
          currency: project.contractValueCurrency,
          tags: [project.category.label],
          businessUnitIds: project.businessUnitIds,
          productIds: project.productIds,
          capabilityIds: project.capabilityIds,
          technologyIds: project.technologyIds,
          industryIds: project.industryIds,
          achievements:
              reviewedExtraction?.aiExtractedKeyAchievements ?? const [],
          lessonsLearned:
              reviewedExtraction?.aiExtractedLessonsLearned ?? const [],
          createdAt: now,
          updatedAt: now,
        ),
      );

  await ref
      .read(projectServiceProvider)
      .linkExperience(project.id, experienceId);
  return experienceId;
}

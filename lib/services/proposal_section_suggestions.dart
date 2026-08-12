import 'package:jva_projecttracker/models/company_intelligence/capability.dart';
import 'package:jva_projecttracker/models/company_intelligence/experience.dart';
import 'package:jva_projecttracker/models/company_intelligence/knowledge_article.dart';
import 'package:jva_projecttracker/models/company_intelligence/technology.dart';
import 'package:jva_projecttracker/models/opportunity.dart';
import 'package:jva_projecttracker/models/proposal_section.dart';

/// Which kind of gap a [ProposalSectionSuggestion] flags — drives its
/// localized label in `AppStrings.suggestionLabel`. Kept as a category
/// rather than free text so this pure derivation layer never has to know
/// about localization (see `lib/l10n/app_strings.dart`).
enum SuggestionCategory {
  missingExperience,
  missingTechnology,
  relevantKnowledgeArticle,
  capabilityAlignment,
}

class ProposalSectionSuggestion {
  const ProposalSectionSuggestion({
    required this.category,
    required this.entityName,
  });

  final SuggestionCategory category;
  final String entityName;
}

const _kMaxSuggestions = 5;

String? _nameFor<T>(
  List<T> items,
  String Function(T) idOf,
  String Function(T) nameOf,
  String id,
) {
  for (final item in items) {
    if (idOf(item) == id) return nameOf(item);
  }
  return null;
}

/// Derives lightweight, deterministic "you might be missing..." suggestions
/// for one proposal section — pure set-differences between the
/// opportunity's own classification-layer knowledge-graph IDs and this
/// section's AI-generation provenance (`aiSource*Ids`). No new Firestore
/// reads, no new AI call — satisfies "avoid creating another independent AI
/// pipeline" literally. Empty before the section has ever been AI-generated
/// (nothing to compare against yet).
List<ProposalSectionSuggestion> deriveSectionSuggestions({
  required Opportunity opportunity,
  required ProposalSection section,
  required List<Experience> experiences,
  required List<Technology> technologies,
  required List<KnowledgeArticle> knowledgeArticles,
  required List<Capability> capabilities,
}) {
  if (section.aiGeneratedAt == null) return const [];

  final suggestions = <ProposalSectionSuggestion>[];

  for (final id in opportunity.experienceIds) {
    if (section.aiSourceExperienceIds.contains(id)) continue;
    final name = _nameFor(experiences, (e) => e.id, (e) => e.title, id);
    if (name != null) {
      suggestions.add(
        ProposalSectionSuggestion(
          category: SuggestionCategory.missingExperience,
          entityName: name,
        ),
      );
    }
  }

  for (final id in opportunity.technologyIds) {
    if (section.aiSourceTechnologyIds.contains(id)) continue;
    final name = _nameFor(technologies, (t) => t.id, (t) => t.name, id);
    if (name != null) {
      suggestions.add(
        ProposalSectionSuggestion(
          category: SuggestionCategory.missingTechnology,
          entityName: name,
        ),
      );
    }
  }

  for (final id in opportunity.knowledgeArticleIds) {
    if (section.aiSourceKnowledgeArticleIds.contains(id)) continue;
    final name = _nameFor(knowledgeArticles, (k) => k.id, (k) => k.title, id);
    if (name != null) {
      suggestions.add(
        ProposalSectionSuggestion(
          category: SuggestionCategory.relevantKnowledgeArticle,
          entityName: name,
        ),
      );
    }
  }

  for (final id in opportunity.capabilityIds) {
    if (section.aiSourceCapabilityIds.contains(id)) continue;
    final name = _nameFor(capabilities, (c) => c.id, (c) => c.name, id);
    if (name != null) {
      suggestions.add(
        ProposalSectionSuggestion(
          category: SuggestionCategory.capabilityAlignment,
          entityName: name,
        ),
      );
    }
  }

  return suggestions.take(_kMaxSuggestions).toList();
}

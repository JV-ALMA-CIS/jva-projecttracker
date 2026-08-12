import 'package:flutter_test/flutter_test.dart';
import 'package:jva_projecttracker/models/company_intelligence/capability.dart';
import 'package:jva_projecttracker/models/company_intelligence/experience.dart';
import 'package:jva_projecttracker/models/company_intelligence/knowledge_article.dart';
import 'package:jva_projecttracker/models/company_intelligence/technology.dart';
import 'package:jva_projecttracker/models/opportunity.dart';
import 'package:jva_projecttracker/models/proposal_section.dart';
import 'package:jva_projecttracker/services/proposal_section_suggestions.dart';

void main() {
  final now = DateTime.utc(2024, 1, 1);

  Opportunity opportunity({
    List<String> experienceIds = const [],
    List<String> technologyIds = const [],
    List<String> knowledgeArticleIds = const [],
    List<String> capabilityIds = const [],
  }) {
    return Opportunity(
      id: 'opp-1',
      title: 'Road tender',
      description: '',
      sourceUrl: 'https://example.com/1',
      discoveredAt: now,
      updatedAt: now,
      experienceIds: experienceIds,
      technologyIds: technologyIds,
      knowledgeArticleIds: knowledgeArticleIds,
      capabilityIds: capabilityIds,
    );
  }

  ProposalSection section({
    DateTime? aiGeneratedAt,
    List<String> aiSourceExperienceIds = const [],
    List<String> aiSourceTechnologyIds = const [],
    List<String> aiSourceKnowledgeArticleIds = const [],
    List<String> aiSourceCapabilityIds = const [],
  }) {
    return ProposalSection(
      id: 'section-1',
      proposalId: 'proposal-1',
      order: 0,
      type: ProposalSectionType.executiveSummary,
      title: 'Executive Summary',
      aiGeneratedAt: aiGeneratedAt,
      aiSourceExperienceIds: aiSourceExperienceIds,
      aiSourceTechnologyIds: aiSourceTechnologyIds,
      aiSourceKnowledgeArticleIds: aiSourceKnowledgeArticleIds,
      aiSourceCapabilityIds: aiSourceCapabilityIds,
      createdAt: now,
      updatedAt: now,
    );
  }

  test('returns nothing before the section has ever been AI-generated', () {
    final suggestions = deriveSectionSuggestions(
      opportunity: opportunity(experienceIds: const ['experience-1']),
      section: section(aiGeneratedAt: null),
      experiences: [
        Experience(
          id: 'experience-1',
          title: 'Road project',
          createdAt: now,
          updatedAt: now,
        ),
      ],
      technologies: const [],
      knowledgeArticles: const [],
      capabilities: const [],
    );

    expect(suggestions, isEmpty);
  });

  test(
    'flags a missing experience the opportunity references but the section does not',
    () {
      final suggestions = deriveSectionSuggestions(
        opportunity: opportunity(experienceIds: const ['experience-1']),
        section: section(aiGeneratedAt: now),
        experiences: [
          Experience(
            id: 'experience-1',
            title: 'Road project',
            createdAt: now,
            updatedAt: now,
          ),
        ],
        technologies: const [],
        knowledgeArticles: const [],
        capabilities: const [],
      );

      expect(suggestions, hasLength(1));
      expect(suggestions.single.category, SuggestionCategory.missingExperience);
      expect(suggestions.single.entityName, 'Road project');
    },
  );

  test('does not flag an experience the section already cites', () {
    final suggestions = deriveSectionSuggestions(
      opportunity: opportunity(experienceIds: const ['experience-1']),
      section: section(
        aiGeneratedAt: now,
        aiSourceExperienceIds: const ['experience-1'],
      ),
      experiences: [
        Experience(
          id: 'experience-1',
          title: 'Road project',
          createdAt: now,
          updatedAt: now,
        ),
      ],
      technologies: const [],
      knowledgeArticles: const [],
      capabilities: const [],
    );

    expect(suggestions, isEmpty);
  });

  test(
    'flags missing technology, knowledge article and capability references',
    () {
      final suggestions = deriveSectionSuggestions(
        opportunity: opportunity(
          technologyIds: const ['tech-1'],
          knowledgeArticleIds: const ['article-1'],
          capabilityIds: const ['cap-1'],
        ),
        section: section(aiGeneratedAt: now),
        experiences: const [],
        technologies: [
          Technology(
            id: 'tech-1',
            name: 'Flutter',
            slug: 'flutter',
            createdAt: now,
            updatedAt: now,
          ),
        ],
        knowledgeArticles: [
          KnowledgeArticle(
            id: 'article-1',
            title: 'Case Study #12',
            createdAt: now,
            updatedAt: now,
          ),
        ],
        capabilities: [
          Capability(
            id: 'cap-1',
            name: 'Structural Engineering',
            slug: 'structural-engineering',
            createdAt: now,
            updatedAt: now,
          ),
        ],
      );

      expect(suggestions, hasLength(3));
      expect(
        suggestions.map((s) => s.category),
        containsAll([
          SuggestionCategory.missingTechnology,
          SuggestionCategory.relevantKnowledgeArticle,
          SuggestionCategory.capabilityAlignment,
        ]),
      );
    },
  );

  test('caps the number of suggestions at 5', () {
    final suggestions = deriveSectionSuggestions(
      opportunity: opportunity(
        experienceIds: const [
          'experience-1',
          'experience-2',
          'experience-3',
          'experience-4',
          'experience-5',
          'experience-6',
        ],
      ),
      section: section(aiGeneratedAt: now),
      experiences: [
        for (var i = 1; i <= 6; i++)
          Experience(
            id: 'experience-$i',
            title: 'Project $i',
            createdAt: now,
            updatedAt: now,
          ),
      ],
      technologies: const [],
      knowledgeArticles: const [],
      capabilities: const [],
    );

    expect(suggestions, hasLength(5));
  });
}

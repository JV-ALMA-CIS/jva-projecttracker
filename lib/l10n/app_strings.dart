import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jva_projecttracker/models/application.dart';
import 'package:jva_projecttracker/models/discovery_run.dart';
import 'package:jva_projecttracker/models/executive_summary.dart';
import 'package:jva_projecttracker/models/opportunity.dart';
import 'package:jva_projecttracker/models/submission.dart';
import 'package:jva_projecttracker/models/submission_communication.dart';
import 'package:jva_projecttracker/models/library_document.dart';
import 'package:jva_projecttracker/models/tender_source.dart';
import 'package:jva_projecttracker/models/tender_sync_run.dart';
import 'package:jva_projecttracker/services/document_suggestions.dart';
import 'package:jva_projecttracker/services/knowledge_health.dart';
import 'package:jva_projecttracker/services/proposal_readiness.dart';
import 'package:jva_projecttracker/services/proposal_section_suggestions.dart';
import 'package:jva_projecttracker/models/project.dart';
import 'package:jva_projecttracker/models/project_deliverable.dart';
import 'package:jva_projecttracker/models/project_risk.dart';
import 'package:jva_projecttracker/models/proposal.dart';
import 'package:jva_projecttracker/models/proposal_approval.dart';
import 'package:jva_projecttracker/models/proposal_section.dart';
import 'package:jva_projecttracker/models/recommendation.dart';
import 'package:jva_projecttracker/models/user_profile.dart';
import 'package:jva_projecttracker/services/providers.dart';
import 'package:jva_projecttracker/services/submission_timeline.dart';
import 'package:jva_projecttracker/services/submission_validation.dart';

/// All static UI chrome text (nav, titles, labels, buttons, empty/error
/// states) in English and Italian. Business data (project names, AI-
/// generated contract/application content) is never translated here — only
/// the app's own interface.
///
/// Implemented as compile-time-checked getters rather than a stringly-typed
/// map, so a typo'd key can't silently fall through at runtime.
class AppStrings {
  const AppStrings(this.locale);

  final Locale locale;

  bool get _it => locale.languageCode == 'it';

  // Navigation
  String get navDashboard => _it ? 'Cruscotto' : 'Dashboard';
  String get navProjects => _it ? 'Progetti storici' : 'Historical Projects';
  String get navApplications => _it ? 'Applicazioni' : 'Applications';
  String get navOpportunities => _it ? 'Opportunità' : 'Opportunities';
  String get navCompanyIntelligence =>
      _it ? 'Intelligenza aziendale' : 'Company Intelligence';

  // App-wide
  String get appTitle => 'JVA Project Tracker';
  String get saveButton => _it ? 'Salva' : 'Save';
  String get deleteTooltip => _it ? 'Elimina' : 'Delete';
  String get requiredValidator => _it ? 'Obbligatorio' : 'Required';
  String errorPrefix(Object error) => _it ? 'Errore: $error' : 'Error: $error';
  String authenticationError(Object error) =>
      _it ? 'Errore di autenticazione: $error' : 'Authentication error: $error';

  // Command palette
  String get commandPaletteTooltip =>
      _it ? 'Ricerca (Ctrl+K)' : 'Search (Ctrl+K)';
  String get commandPaletteHint => _it
      ? 'Cerca opportunità, dati aziendali, azioni…'
      : 'Search opportunities, company data, actions…';
  String get commandPaletteNoResults => _it ? 'Nessun risultato' : 'No results';
  String get commandPaletteGoToGroup => _it ? 'Vai a' : 'Go to';
  String get commandPaletteOpportunitiesGroup => navOpportunities;
  String get commandPaletteCompanyIntelligenceGroup => navCompanyIntelligence;
  String get commandPaletteQuickActionsGroup =>
      _it ? 'Azioni rapide' : 'Quick actions';

  // Dashboard
  String get dashboardTitle => navDashboard;
  String get dashboardSubtitle => _it
      ? 'Ecco cosa succede nella tua pipeline oggi.'
      : "Here's what's happening across your pipeline today.";
  String dashboardGreeting(String name) {
    final hour = DateTime.now().hour;
    final period = hour < 12
        ? (_it ? 'Buongiorno' : 'Good morning')
        : hour < 18
        ? (_it ? 'Buon pomeriggio' : 'Good afternoon')
        : (_it ? 'Buonasera' : 'Good evening');
    return name.isEmpty ? period : '$period, $name';
  }

  String get atRiskLabel => _it ? 'A rischio' : 'At risk';
  String get needsYourAttentionSectionTitle =>
      _it ? 'Richiede la tua attenzione' : 'Needs Your Attention';
  String get youreAllCaughtUpMessage =>
      _it ? 'Tutto in ordine, per ora.' : "You're all caught up for now.";
  String get whyThisMattersLabel => _it ? 'Perché' : 'Why';
  String get submissionStatusOverviewLabel =>
      _it ? 'Panoramica stato invii' : 'Submission status overview';
  String get noActiveProjectsMessage => _it
      ? 'Nessun progetto aggiudicato è attualmente in consegna.'
      : 'No awarded projects are currently being delivered.';
  String get noAiRecommendationsGroundedMessage => _it
      ? 'Le raccomandazioni AI compariranno man mano che le opportunità vengono valutate rispetto alla Company Intelligence verificata.'
      : 'AI recommendations will appear as opportunities are evaluated against verified Company Intelligence.';
  String get needsAttentionSectionTitle =>
      _it ? 'Richiede attenzione' : 'Needs attention';
  String get noUrgentAlerts =>
      _it ? 'Niente di urgente al momento.' : 'Nothing urgent right now.';
  String get pipelineSnapshotSectionTitle =>
      _it ? 'Panoramica pipeline' : 'Pipeline snapshot';
  String get activeProposalsSectionTitle =>
      _it ? 'Proposte in corso' : 'Active proposals';
  String get noActiveProposals =>
      _it ? 'Nessuna proposta ancora avviata.' : 'No proposals started yet.';
  String get recentActivitySectionTitle =>
      _it ? 'Attività recente' : 'Recent activity';
  String get noRecentActivity =>
      _it ? 'Nessuna attività ancora.' : 'No activity yet.';
  String get statRunning => _it ? 'In corso' : 'Running';
  String get statPlanned => _it ? 'Pianificati' : 'Planned';
  String get statPast => _it ? 'Conclusi' : 'Past';
  String get statApplicationsBuilt =>
      _it ? 'Applicazioni sviluppate' : 'Applications built';
  String get topOpportunityMatches =>
      _it ? 'Migliori corrispondenze opportunità' : 'Top opportunity matches';
  String get noOpportunitiesOnDashboard => _it
      ? 'Nessuna opportunità ancora scoperta. Avvia una ricerca dalla scheda Opportunità.'
      : 'No opportunities discovered yet. Run a search from the Opportunities tab.';

  // Projects list
  String get projectsTitle => navProjects;
  String get projectsSubtitle => _it
      ? 'Archivio verificato dei progetti JV ALMA CIS e delle relative evidenze.'
      : 'Verified archive of JV ALMA CIS projects and supporting evidence.';
  String get noProjectsYet => _it
      ? 'Nessun progetto ancora. Tocca + per aggiungerne uno.'
      : 'No projects yet. Tap + to add one.';

  // Project form
  String get newProjectTitle => _it ? 'Nuovo progetto' : 'New Project';
  // Project form
  String get editProjectTitle => _it ? 'Modifica progetto' : 'Edit Project';
  String get deleteProjectConfirmBody => _it
      ? 'Eliminare questo progetto? L\'azione non può essere annullata.'
      : 'Delete this project? This cannot be undone.';
  String get projectDeletedMessage =>
      _it ? 'Progetto eliminato.' : 'Project deleted.';
  String get sectionDetails => _it ? 'Dettagli' : 'Details';
  String get fieldProjectName => _it ? 'Nome del progetto' : 'Project name';
  String get fieldClient => _it ? 'Cliente' : 'Client';
  String get fieldFundingAgency => _it ? 'Ente finanziatore' : 'Funding agency';
  String get fieldDescription => _it ? 'Descrizione' : 'Description';
  String get sectionClassification =>
      _it ? 'Classificazione' : 'Classification';
  String get fieldCategory => _it ? 'Categoria' : 'Category';
  String get contractorRoleFieldLabel =>
      _it ? 'Ruolo dell\'appaltatore' : 'Contractor role';
  String get clientTypeFieldLabel => _it ? 'Tipo di cliente' : 'Client type';
  String get fieldStatus => _it ? 'Stato' : 'Status';
  String get sectionScopeScale => _it ? 'Ambito e scala' : 'Scope & Scale';
  String get fieldLocation => _it ? 'Ubicazione / sito' : 'Location / site';
  String get fieldProjectSize =>
      _it ? 'Dimensione del progetto' : 'Project size';
  String get projectSizeHelper => _it
      ? 'es. 12.500 mq · 4,2 km · 80 unità'
      : 'e.g. 12,500 sq.m · 4.2 km · 80 units';
  String get fieldScopeOfWorks => _it ? 'Ambito dei lavori' : 'Scope of works';
  String get fieldCurrency => _it ? 'Valuta' : 'Currency';
  String get fieldContractValue =>
      _it ? 'Valore del contratto' : 'Contract value';
  String get fetchingRates =>
      _it ? 'Recupero tassi in tempo reale…' : 'Fetching live rates…';
  String liveRatesCaption(String parts) => _it
      ? '≈ $parts  (tassi in tempo reale via open.er-api.com)'
      : '≈ $parts  (live rates via open.er-api.com)';
  String get sectionNotes => _it ? 'Note' : 'Notes';
  String get fieldNotes => _it ? 'Note' : 'Notes';

  // Applications list
  String get applicationsTitle => navApplications;
  String get noApplicationsYet => _it
      ? 'Nessuna applicazione ancora catalogata. Tocca + per aggiungerne una.'
      : 'No applications catalogued yet. Tap + to add one.';

  // Application form
  String get newApplicationTitle =>
      _it ? 'Nuova applicazione' : 'New Application';
  String get editApplicationTitle =>
      _it ? 'Modifica applicazione' : 'Edit Application';
  String get fieldApplicationName =>
      _it ? 'Nome dell\'applicazione' : 'Application name';
  String get sectionMarketDiscovery =>
      _it ? 'Ricerca di mercato e usabilità' : 'Market & usability discovery';
  String get discoverButton => _it ? 'Scopri' : 'Discover';
  String get discoveryCaption => _it
      ? 'Suggerisce ambiti di mercato/usabilità realistici per questa app, basati su ricerche web e sulla storia di progetti e applicazioni dell\'azienda.'
      : 'Suggests real-world market/usability fields for this app, grounded '
            'in web search and the company\'s own project & application '
            'history.';
  String get selectedAreasLabel =>
      _it ? 'Ambiti selezionati' : 'Selected areas';
  String get acceptTooltip => _it ? 'Accetta' : 'Accept';
  String get dismissTooltip => _it ? 'Ignora' : 'Dismiss';
  String get sectionPlatformTech =>
      _it ? 'Piattaforma e tecnologia' : 'Platform & technology';
  String get fieldPlatforms =>
      _it ? 'Piattaforme (separate da virgola)' : 'Platforms (comma separated)';
  String get fieldTechStack => _it
      ? 'Stack tecnologico (separato da virgola)'
      : 'Tech stack (comma separated)';
  String get fieldRepoUrl => _it ? 'URL repository' : 'Repo URL';
  String get fieldLiveUrl => _it ? 'URL live' : 'Live URL';
  String discoveryFailed(Object error) =>
      _it ? 'Ricerca fallita: $error' : 'Discovery failed: $error';

  // Company Intelligence
  String get companyIntelligenceTitle => navCompanyIntelligence;
  String get companyIntelligenceSubtitle => _it
      ? 'Ciò che l\'azienda sa, e quanto è connesso alla pipeline delle opportunità.'
      : 'What the company knows, and how connected it is to the opportunity pipeline.';
  String get executiveSummarySectionTitle =>
      _it ? 'Riepilogo esecutivo' : 'Executive summary';
  String get totalKnowledgeItemsLabel =>
      _it ? 'Elementi di conoscenza' : 'Knowledge items';
  String get capabilityGapsLabel =>
      _it ? 'Lacune di competenze' : 'Capability gaps';
  String get updatedRecentlyLabel =>
      _it ? 'Aggiornati di recente' : 'Updated recently';
  String recentlyUpdatedLabel(String name, String date) => _it
      ? 'Aggiornato di recente: $name · $date'
      : 'Recently updated: $name · $date';
  String get noKnowledgeItemsYetLabel =>
      _it ? 'Nessun elemento ancora registrato' : 'No items recorded yet';
  String relatedOpportunitiesCountLabel(int count) =>
      _it ? '$count opportunità collegate' : '$count related opportunities';
  String knowledgeHealthLabel(KnowledgeHealth h) {
    return switch (h) {
      KnowledgeHealth.covered => _it ? 'Ben coperto' : 'Well covered',
      KnowledgeHealth.attention =>
        _it ? 'Richiede attenzione' : 'Needs attention',
      KnowledgeHealth.gap => _it ? 'Lacuna di competenze' : 'Capability gap',
      KnowledgeHealth.noData => _it ? 'Nessun dato' : 'No data yet',
    };
  }

  String get businessUnitsTitle => _it ? 'Business unit' : 'Business units';
  String get businessUnitsSubtitle => _it
      ? 'Le linee di business dell\'azienda e ciò che le rappresenta nel grafo aziendale.'
      : 'The company\'s lines of business and what they own in the knowledge graph.';
  String get noBusinessUnitsYet => _it
      ? 'Nessuna business unit ancora registrata.'
      : 'No business units registered yet.';
  String get businessUnitDetailsTitle =>
      _it ? 'Dettagli business unit' : 'Business unit details';
  String get fieldBusinessUnitName =>
      _it ? 'Nome business unit' : 'Business unit name';
  String get fieldBusinessUnitSlug => _it ? 'Slug' : 'Slug';
  String get fieldBusinessUnitSummary => _it ? 'Riepilogo' : 'Summary';
  String get fieldBusinessUnitDescription =>
      _it ? 'Descrizione' : 'Description';
  String get fieldBusinessUnitStatus => _it ? 'Stato' : 'Status';
  String get newBusinessUnitTitle =>
      _it ? 'Nuova business unit' : 'New Business Unit';
  String get editBusinessUnitTitle =>
      _it ? 'Modifica business unit' : 'Edit Business Unit';
  String get productsTitle => _it ? 'Prodotti' : 'Products';
  String get noProductsYet => _it
      ? 'Nessun prodotto ancora registrato.'
      : 'No products registered yet.';
  String get newProductTitle => _it ? 'Nuovo prodotto' : 'New Product';
  String get editProductTitle => _it ? 'Modifica prodotto' : 'Edit Product';
  String get fieldProductName => _it ? 'Nome prodotto' : 'Product name';
  String get fieldProductSlug => _it ? 'Slug' : 'Slug';
  String get fieldProductSummary => _it ? 'Riepilogo' : 'Summary';
  String get fieldProductBusinessUnit =>
      _it ? 'Business unit' : 'Business unit';
  String get productsSubtitle => _it
      ? 'Piattaforme software e offerte commerciali dell\'azienda.'
      : 'The company\'s software platforms and commercial offerings.';
  String get productFormHintMessage => _it
      ? 'Registra qui piattaforme software e prodotti commerciali (es. Kilimo Mkononi, CoffeeCore). Le consegne di singoli progetti vanno registrate in Progetti o Esperienze.'
      : 'Register software platforms and commercial products here (e.g. Kilimo Mkononi, CoffeeCore). Individual project deliveries belong under Projects or Experiences.';
  String get advancedSectionLabel => _it ? 'Avanzate' : 'Advanced';
  String get fieldProductStoreUrl =>
      _it ? 'Link store / sito' : 'Store / listing URL';
  String get openStoreLinkButton => _it ? 'Apri link' : 'Open link';
  String get noBusinessUnitsForProductMessage => _it
      ? 'Nessuna business unit trovata. Creane una prima di registrare un prodotto.'
      : 'No business units found yet. Create one before registering a product.';
  String get goToBusinessUnitsButton =>
      _it ? 'Vai a Business Unit' : 'Go to Business Units';
  String get deleteProductConfirmBody => _it
      ? 'Eliminare questo prodotto? L\'azione non può essere annullata.'
      : 'Delete this product? This cannot be undone.';
  String get servicesTitle => _it ? 'Servizi' : 'Services';
  String get servicesSubtitle => _it
      ? 'Servizi professionali offerti oltre ai prodotti software.'
      : 'Professional services the company offers alongside its software products.';
  String get noServicesYet => _it
      ? 'Nessun servizio ancora registrato.'
      : 'No services registered yet.';
  String get newServiceTitle => _it ? 'Nuovo servizio' : 'New Service';
  String get editServiceTitle => _it ? 'Modifica servizio' : 'Edit Service';
  String get fieldServiceName => _it ? 'Nome servizio' : 'Service name';
  String get fieldServiceSlug => _it ? 'Slug' : 'Slug';
  String get fieldServiceSummary => _it ? 'Riepilogo' : 'Summary';
  String get capabilitiesTitle => _it ? 'Competenze' : 'Capabilities';
  String get capabilitiesSubtitle => _it
      ? 'Ciò che l\'azienda sa fare bene — la base delle valutazioni di corrispondenza.'
      : 'What the company is actually good at — the basis for fit scoring.';
  String get noCapabilitiesYet => _it
      ? 'Nessuna competenza ancora registrata.'
      : 'No capabilities registered yet.';
  String get newCapabilityTitle => _it ? 'Nuova competenza' : 'New Capability';
  String get editCapabilityTitle =>
      _it ? 'Modifica competenza' : 'Edit Capability';
  String get fieldCapabilityName => _it ? 'Nome competenza' : 'Capability name';
  String get fieldCapabilitySlug => _it ? 'Slug' : 'Slug';
  String get fieldCapabilitySummary => _it ? 'Riepilogo' : 'Summary';
  String get fieldCapabilityBusinessRelevance =>
      _it ? 'Rilevanza per il business' : 'Business relevance';
  String get fieldCapabilityKeywords => _it
      ? 'Parole chiave (separate da virgola)'
      : 'Keywords (comma separated)';
  String get fieldCapabilityTags =>
      _it ? 'Tag (separati da virgola)' : 'Tags (comma separated)';
  String get technologiesTitle => _it ? 'Tecnologie' : 'Technologies';
  String get technologiesSubtitle => _it
      ? 'Lo stack tecnico dietro le competenze e i prodotti dell\'azienda.'
      : 'The technical stack behind the company\'s capabilities and products.';
  String get noTechnologiesYet => _it
      ? 'Nessuna tecnologia ancora registrata.'
      : 'No technologies registered yet.';
  String get noTechnologiesMatchFilter => _it
      ? 'Nessuna tecnologia corrisponde alla ricerca.'
      : 'No technologies match your search.';
  String get searchTechnologiesHint =>
      _it ? 'Cerca tecnologie…' : 'Search technologies…';
  String get filterAllLabel => _it ? 'Tutti' : 'All';
  String get newTechnologyTitle => _it ? 'Nuova tecnologia' : 'New Technology';
  String get editTechnologyTitle =>
      _it ? 'Modifica tecnologia' : 'Edit Technology';
  String get fieldTechnologyName => _it ? 'Nome tecnologia' : 'Technology name';
  String get fieldTechnologySlug => _it ? 'Slug' : 'Slug';
  String get fieldTechnologySummary => _it ? 'Riepilogo' : 'Summary';
  String get fieldTechnologyCategory => _it ? 'Categoria' : 'Category';
  String get fieldTechnologyVendor => _it ? 'Fornitore' : 'Vendor';
  String get fieldTechnologyWebsite => _it ? 'Sito web' : 'Website';
  String get fieldTechnologyKeywords => _it
      ? 'Parole chiave (separate da virgola)'
      : 'Keywords (comma separated)';
  String get fieldTechnologyTags =>
      _it ? 'Tag (separati da virgola)' : 'Tags (comma separated)';
  String get fieldTechnologyNotes => _it ? 'Note' : 'Notes';
  String get sectionKeywordsTags =>
      _it ? 'Parole chiave e tag' : 'Keywords & tags';
  String get sectionRelationships => _it ? 'Relazioni' : 'Relationships';
  String get relatedBusinessUnitsLabel =>
      _it ? 'Business unit collegate' : 'Related business units';
  String get relatedProductsLabel =>
      _it ? 'Prodotti collegati' : 'Related products';
  String get relatedCapabilitiesLabel =>
      _it ? 'Competenze collegate' : 'Related capabilities';
  String get relatedTechnologiesLabel =>
      _it ? 'Tecnologie collegate' : 'Related technologies';
  String get industriesTitle => _it ? 'Settori' : 'Industries';
  String get industriesSubtitle => _it
      ? 'I settori in cui l\'azienda opera o punta a espandersi.'
      : 'The sectors the company operates in or is targeting.';
  String get noIndustriesYet => _it
      ? 'Nessun settore ancora registrato.'
      : 'No industries registered yet.';
  String get noIndustriesMatchFilter => _it
      ? 'Nessun settore corrisponde alla ricerca.'
      : 'No industries match your search.';
  String get searchIndustriesHint =>
      _it ? 'Cerca settori…' : 'Search industries…';
  String get newIndustryTitle => _it ? 'Nuovo settore' : 'New Industry';
  String get editIndustryTitle => _it ? 'Modifica settore' : 'Edit Industry';
  String get fieldIndustryName => _it ? 'Nome settore' : 'Industry name';
  String get fieldIndustrySector => _it ? 'Comparto' : 'Sector';
  String get fieldIndustryTags =>
      _it ? 'Tag (separati da virgola)' : 'Tags (comma separated)';
  String get relatedIndustriesLabel =>
      _it ? 'Settori collegati' : 'Related industries';

  // Experiences
  String get experiencesTitle => _it ? 'Esperienze' : 'Experiences';
  String get experiencesSubtitle => _it
      ? 'Referenze concrete di delivery passata a supporto delle offerte future.'
      : 'Concrete past-delivery evidence to back up future bids.';
  String get noExperiencesYet => _it
      ? 'Nessuna esperienza ancora registrata.'
      : 'No experiences registered yet.';
  String get noExperiencesMatchFilter => _it
      ? 'Nessuna esperienza corrisponde alla ricerca.'
      : 'No experiences match your search.';
  String get searchExperiencesHint =>
      _it ? 'Cerca esperienze…' : 'Search experiences…';
  String get newExperienceTitle => _it ? 'Nuova esperienza' : 'New Experience';
  String get editExperienceTitle =>
      _it ? 'Modifica esperienza' : 'Edit Experience';
  String get fieldExperienceTitle => _it ? 'Titolo' : 'Title';
  String get fieldExperienceSummary => _it ? 'Riepilogo' : 'Summary';
  String get fieldPartner => _it ? 'Partner' : 'Partner';
  String get fieldCountry => _it ? 'Paese' : 'Country';
  String get fieldRegion => _it ? 'Regione' : 'Region';
  String get fieldStartDate => _it ? 'Data di inizio' : 'Start date';
  String get fieldEndDate => _it ? 'Data di fine' : 'End date';
  String get fieldFundingSource =>
      _it ? 'Fonte di finanziamento' : 'Funding source';
  String get fieldOutcome => _it ? 'Esito' : 'Outcome';
  String get fieldAchievements => _it
      ? 'Risultati raggiunti (una riga per elemento)'
      : 'Achievements (one per line)';
  String get fieldLessonsLearned => _it
      ? 'Lezioni apprese (una riga per elemento)'
      : 'Lessons learned (one per line)';
  String get fieldExperienceTags =>
      _it ? 'Tag (separati da virgola)' : 'Tags (comma separated)';
  String get sectionClientLocation =>
      _it ? 'Cliente e ubicazione' : 'Client & location';
  String get sectionEngagementDetails =>
      _it ? 'Dettagli dell\'incarico' : 'Engagement details';
  String get sectionOutcomes =>
      _it ? 'Risultati e lezioni' : 'Outcomes & lessons';
  String get relatedServicesLabel =>
      _it ? 'Servizi collegati' : 'Related services';
  String get relatedExperiencesLabel =>
      _it ? 'Esperienze collegate' : 'Related experiences';

  // Knowledge Base
  String get knowledgeBaseTitle =>
      _it ? 'Base di conoscenza' : 'Knowledge Base';
  String get knowledgeBaseSubtitle => _it
      ? 'Articoli e note interne che alimentano classificazione e proposte AI.'
      : 'Internal articles and notes that power AI classification and proposals.';
  String get noKnowledgeArticlesYet => _it
      ? 'Nessun articolo ancora registrato.'
      : 'No knowledge articles registered yet.';
  String get noKnowledgeArticlesMatchFilter => _it
      ? 'Nessun articolo corrisponde alla ricerca.'
      : 'No knowledge articles match your search.';
  String get searchKnowledgeHint =>
      _it ? 'Cerca nella base di conoscenza…' : 'Search the knowledge base…';
  String get newKnowledgeArticleTitle => _it ? 'Nuovo articolo' : 'New Article';
  String get editKnowledgeArticleTitle =>
      _it ? 'Modifica articolo' : 'Edit Article';
  String get fieldArticleTitle => _it ? 'Titolo' : 'Title';
  String get fieldArticleSummary => _it ? 'Riepilogo' : 'Summary';
  String get fieldArticleContent => _it ? 'Contenuto' : 'Content';
  String get fieldArticleTags =>
      _it ? 'Tag (separati da virgola)' : 'Tags (comma separated)';
  String get suggestedCategoriesLabel =>
      _it ? 'Categorie suggerite' : 'Suggested categories';

  // Opportunities
  String get opportunitiesTitle => navOpportunities;
  String get opportunitiesSubtitle => _it
      ? 'Scopri, valuta e dai priorità alle potenziali opportunità.'
      : 'Discover, evaluate and prioritize potential opportunities.';
  String get noOpportunitiesDiscovered => _it
      ? 'Nessun opportunità ancora scoperta.'
      : 'No opportunities discovered yet.';
  String get searchNowButton => _it ? 'Cerca ora' : 'Search now';
  String get searchTooltip =>
      _it ? 'Cerca nuove opportunità' : 'Search for new opportunities';
  String foundOpportunities(int count) => _it
      ? 'Trovate $count nuove opportunità'
      : 'Found $count new opportunities';
  String searchFailed(Object error) =>
      _it ? 'Ricerca fallita: $error' : 'Search failed: $error';
  String get fitReasoningLabel =>
      _it ? 'Motivazione della corrispondenza' : 'Fit reasoning';
  String get openSourceButton => _it ? 'Apri fonte' : 'Open source';
  String get openWorkspaceButton =>
      _it ? 'Apri area di lavoro' : 'Open workspace';
  String get aiOverviewSectionTitle => _it ? 'Panoramica IA' : 'AI overview';

  // Opportunities — Business Unit navigation & faceted filters (Phase 2)
  String get searchOpportunitiesHint =>
      _it ? 'Cerca opportunità…' : 'Search opportunities…';
  String get noOpportunitiesInBusinessUnit => _it
      ? 'Nessuna opportunità in questa unità aziendale.'
      : 'No opportunities in this business unit.';
  String get noOpportunitiesMatchFilters => _it
      ? 'Nessuna opportunità corrisponde a questi filtri.'
      : 'No opportunities match these filters.';
  String get clearFiltersButton => _it ? 'Cancella filtri' : 'Clear filters';
  String get filtersButtonLabel => _it ? 'Filtri' : 'Filters';
  String get stageFilterLabel => _it ? 'Fase pipeline' : 'Pipeline stage';
  String get valueFilterLabel => _it ? 'Valore stimato' : 'Estimated value';
  String get valueBandUnder50k => _it ? 'Sotto 50k' : 'Under 50k';
  String get valueBandFrom50kTo250k => _it ? '50k–250k' : '50k–250k';
  String get valueBandFrom250kTo1m => _it ? '250k–1M' : '250k–1M';
  String get valueBandOver1m => _it ? '1M+' : '1M+';
  String get valueBandUnknown => _it ? 'Non specificato' : 'Unknown';
  String get deadlineFilterLabel => _it ? 'Scadenza' : 'Deadline';
  String get deadlineOverdueFilterLabel => _it ? 'Scaduto' : 'Overdue';
  String get deadlineWithin7DaysLabel =>
      _it ? 'Entro 7 giorni' : 'Within 7 days';
  String get deadlineWithin14DaysLabel =>
      _it ? 'Entro 14 giorni' : 'Within 14 days';
  String get deadlineWithin30DaysLabel =>
      _it ? 'Entro 30 giorni' : 'Within 30 days';
  String get deadlineNoneFilterLabel =>
      _it ? 'Nessuna scadenza' : 'No deadline';
  String get fitScoreFilterLabel => _it ? 'Punteggio di fit' : 'Fit score';
  String get buyerTypeFilterLabel => _it ? 'Tipo di ente' : 'Buyer type';
  String get buyerTypeGovernment => _it ? 'Governo' : 'Government';
  String get buyerTypeDevelopmentPartner =>
      _it ? 'Partner di sviluppo' : 'Development partner';
  String get buyerTypeUnAgency => _it ? 'Agenzia ONU' : 'UN agency';
  String get buyerTypeNgo => _it ? 'ONG' : 'NGO';
  String get buyerTypePrivateSector =>
      _it ? 'Settore privato' : 'Private sector';
  String get buyerTypeUnknown => _it ? 'Sconosciuto' : 'Unknown';

  // Opportunity Business Unit assignment (Business Workflow Governance)
  String get businessUnitsSectionLabel =>
      _it ? 'Unità aziendali' : 'Business units';
  String get noBusinessUnitsAssignedMessage => _it
      ? 'Nessuna unità aziendale assegnata ancora.'
      : 'No business units assigned yet.';
  String get assignBusinessUnitsTooltip => _it
      ? '2. Assegna unità aziendali alle opportunità (amministratore) — esegui prima "Popola unità aziendali"'
      : '2. Assign business units to opportunities (admin) — run "Seed business units" first';
  String businessUnitBackfillResultMessage(int updated, int skipped) => _it
      ? '$updated opportunità aggiornate, $skipped saltate'
      : '$updated opportunities updated, $skipped skipped';
  String get seedBusinessUnitsTooltip => _it
      ? '1. Popola unità aziendali (amministratore)'
      : '1. Seed business units (admin)';
  String businessUnitSeedResultMessage(int created, int skipped) => _it
      ? '$created unità aziendali create, $skipped già esistenti'
      : '$created business units created, $skipped already existed';

  // Delivery & Wins (Business Workflow Governance — won-tender visibility)
  String get activeDeliveryTabLabel =>
      _it ? 'Consegna attiva' : 'Active delivery';
  String get historicalTabLabel => _it ? 'Storico' : 'Historical';
  String get noActiveDeliveryProjectsMessage => _it
      ? 'Nessun progetto in consegna attiva al momento.'
      : 'No projects in active delivery right now.';
  String get noHistoricalProjectsMessage =>
      _it ? 'Nessun progetto storico ancora.' : 'No historical projects yet.';
  String get awardedWonFilterLabel => _it ? 'Aggiudicate' : 'Awarded / Won';
  String get projectStartedLabel =>
      _it ? 'Progetto avviato' : 'Project started';
  String get startProjectNeededLabel =>
      _it ? 'Avvio progetto necessario' : 'Start project needed';
  String get openProjectButton => _it ? 'Apri progetto' : 'Open project';
  String get deliveryAndWinsSectionTitle =>
      _it ? 'Consegna e aggiudicazioni' : 'Delivery & wins';
  String get noDeliveryAndWinsMessage => _it
      ? 'Nessuna gara aggiudicata in attesa e nessun progetto in consegna attiva.'
      : 'No awarded tenders waiting on a start and no projects in active delivery.';

  // Opportunity Discovery Engine (Milestone 3.7)
  String get inboxTitle => _it ? 'Posta in arrivo' : 'Opportunity Inbox';
  String get inboxTooltip => _it ? 'Posta in arrivo' : 'Inbox';
  String get inboxEmptyMessage => _it
      ? 'Nessuna opportunità in attesa di revisione.'
      : 'No opportunities waiting for review.';
  String get acceptButton => _it ? 'Accetta' : 'Accept';
  String get ignoreButton => _it ? 'Ignora' : 'Ignore';
  String get archiveButton => _it ? 'Archivia' : 'Archive';
  String possibleDuplicateOf(String title) => _it
      ? 'Possibile duplicato di "$title"'
      : 'Possible duplicate of "$title"';

  String get discoverySourcesTitle =>
      _it ? 'Fonti di scoperta' : 'Discovery Sources';
  String get discoverySourcesTooltip => _it ? 'Fonti' : 'Sources';
  String get noDiscoverySourcesMessage => _it
      ? 'Nessuna fonte configurata ancora.'
      : 'No discovery sources configured yet.';
  String get addSourceTitle => _it ? 'Aggiungi fonte' : 'Add source';
  String get editSourceTitle => _it ? 'Modifica fonte' : 'Edit source';
  String get fieldSourceName => _it ? 'Nome della fonte' : 'Source name';
  String get fieldSourceType => _it ? 'Tipo di fonte' : 'Source type';
  String get fieldSearchQuery =>
      _it ? 'Query di ricerca (facoltativa)' : 'Search query (optional)';
  String get runNowButton => _it ? 'Esegui ora' : 'Run now';
  String get notYetAutomatedTooltip => _it
      ? 'Non ancora automatizzata — usa l\'importazione manuale'
      : 'Not yet automated — use manual entry';
  String runCreatedOpportunities(int count) => _it
      ? 'Esecuzione completata: $count nuove opportunità.'
      : 'Run completed: $count new opportunities.';
  String runFailed(Object error) =>
      _it ? 'Esecuzione fallita: $error' : 'Run failed: $error';
  String get addOpportunityManuallyTitle =>
      _it ? 'Aggiungi opportunità manualmente' : 'Add opportunity manually';
  String get fieldSourceUrl =>
      _it ? 'URL fonte (facoltativo)' : 'Source URL (optional)';
  String get fieldOpportunityTitle =>
      _it ? 'Titolo dell\'opportunità' : 'Opportunity title';
  String get addButton => _it ? 'Aggiungi' : 'Add';

  String get discoveryHistoryTitle =>
      _it ? 'Cronologia delle scoperte' : 'Discovery History';
  String get discoveryHistoryTooltip => _it ? 'Cronologia' : 'History';
  String get noDiscoveryRunsMessage => _it
      ? 'Nessuna esecuzione di scoperta ancora registrata.'
      : 'No discovery runs recorded yet.';
  String discoveryRunSummary(int created, int duplicates) => _it
      ? '$created create, $duplicates duplicati saltati'
      : '$created created, $duplicates duplicates skipped';

  // Opportunity classification (Milestone 3.1 — Opportunity Intelligence
  // foundation; these fields are manually edited for now, ahead of a future
  // AI classification pass).
  String get editClassificationTooltip =>
      _it ? 'Modifica classificazione' : 'Edit classification';
  String get editClassificationTitle =>
      _it ? 'Classificazione opportunità' : 'Opportunity classification';
  String get fieldClassificationStatus =>
      _it ? 'Stato di classificazione' : 'Classification status';
  String get fieldClassificationSummary =>
      _it ? 'Riepilogo della classificazione' : 'Classification summary';
  String get fieldOpportunityType =>
      _it ? 'Tipo di opportunità' : 'Opportunity type';
  String get fieldEstimatedBudget =>
      _it ? 'Budget stimato' : 'Estimated budget';
  String get fieldEstimatedDuration =>
      _it ? 'Durata stimata' : 'Estimated duration';
  String get fieldEstimatedComplexity =>
      _it ? 'Complessità stimata' : 'Estimated complexity';
  String get fieldConfidenceScore =>
      _it ? 'Punteggio di fiducia' : 'Confidence score';
  String get fieldRiskLevel => _it ? 'Livello di rischio' : 'Risk level';
  String get fieldPriority => _it ? 'Priorità' : 'Priority';
  String get relatedKnowledgeArticlesLabel =>
      _it ? 'Articoli collegati' : 'Related knowledge articles';
  String get relatedCompanyKnowledgeLabel =>
      _it ? 'Conoscenza aziendale collegata' : 'Related company knowledge';
  String confidenceScoreChipLabel(int score) =>
      _it ? 'Fiducia: $score%' : 'Confidence: $score%';
  String relatedKnowledgeCount(int count) =>
      _it ? '$count elementi collegati' : '$count related items';
  String get notSetLabel => _it ? 'Non impostato' : 'Not set';
  String get cancelButton => _it ? 'Annulla' : 'Cancel';
  String get confirmButton => _it ? 'Conferma' : 'Confirm';

  // AI Opportunity Classification (Milestone 3.3)
  String get runAiClassificationButton =>
      _it ? 'Esegui classificazione AI' : 'Run AI Classification';
  String get aiClassificationSucceeded =>
      _it ? 'Classificazione AI completata.' : 'AI classification completed.';
  String aiClassificationFailed(Object error) => _it
      ? 'Classificazione AI fallita: $error'
      : 'AI classification failed: $error';
  String lastAiReviewLabel(String date) =>
      _it ? 'Ultima revisione AI: $date' : 'Last AI review: $date';
  String get neverReviewedByAiLabel =>
      _it ? 'Non ancora esaminato dall\'AI' : 'Not yet reviewed by AI';

  // AI Opportunity Match Analysis (Milestone 3.4)
  String get matchAnalysisScreenTitle =>
      _it ? 'Analisi di corrispondenza' : 'Match Analysis';
  String get matchAnalysisTooltip => _it ? 'Corrispondenza' : 'Match';
  String get runMatchAnalysisButton =>
      _it ? 'Esegui analisi di corrispondenza' : 'Run Match Analysis';
  String get matchAnalysisSucceeded => _it
      ? 'Analisi di corrispondenza completata.'
      : 'Match analysis completed.';
  String matchAnalysisFailed(Object error) => _it
      ? 'Analisi di corrispondenza fallita: $error'
      : 'Match analysis failed: $error';
  String lastMatchAnalysisLabel(String date) => _it
      ? 'Ultima analisi di corrispondenza: $date'
      : 'Last match analysis: $date';
  String get neverAnalyzedLabel =>
      _it ? 'Non ancora analizzato' : 'Not yet analyzed';
  String get noMatchAnalysisYet => _it
      ? 'Esegui l\'analisi di corrispondenza per vedere quanto bene questa opportunità corrisponde a JV ALMA CIS.'
      : 'Run match analysis to see how well this opportunity matches JV ALMA CIS.';
  String get overallMatchScoreLabel =>
      _it ? 'Punteggio complessivo' : 'Overall match score';
  String get categoryBreakdownLabel =>
      _it ? 'Dettaglio per categoria' : 'Category breakdown';
  String get businessUnitScoreLabel => _it ? 'Business unit' : 'Business units';
  String get productScoreLabel => _it ? 'Prodotti' : 'Products';
  String get serviceScoreLabel => _it ? 'Servizi' : 'Services';
  String get capabilityScoreLabel => _it ? 'Competenze' : 'Capabilities';
  String get technologyScoreLabel => _it ? 'Tecnologie' : 'Technologies';
  String get industryScoreLabel => _it ? 'Settori' : 'Industries';
  String get experienceScoreLabel => _it ? 'Esperienze' : 'Experiences';
  String get knowledgeScoreLabel =>
      _it ? 'Base di conoscenza' : 'Knowledge base';
  String get strengthsLabel => _it ? 'Punti di forza' : 'Strengths';
  String get gapsLabel => _it ? 'Lacune' : 'Gaps';
  String get risksLabel => _it ? 'Rischi' : 'Risks';
  String get nextActionsLabel =>
      _it ? 'Prossime azioni suggerite' : 'Suggested next actions';
  String get recommendedProductsLabel =>
      _it ? 'Prodotti consigliati' : 'Recommended products';
  String get recommendedBusinessUnitsLabel =>
      _it ? 'Business unit consigliate' : 'Recommended business units';
  String get recommendedExperiencesLabel =>
      _it ? 'Esperienze consigliate' : 'Recommended experiences';
  String get recommendedKnowledgeLabel =>
      _it ? 'Conoscenza consigliata' : 'Recommended knowledge';
  String get strategicRecommendationLabel =>
      _it ? 'Raccomandazione strategica' : 'Strategic recommendation';

  // AI Strategic Review (Milestone 3.5)
  String get strategicReviewScreenTitle =>
      _it ? 'Revisione strategica' : 'Strategic Review';
  String get strategicReviewTooltip => _it ? 'Strategia' : 'Strategy';
  String get runStrategicReviewButton =>
      _it ? 'Esegui revisione strategica' : 'Run Strategic Review';
  String get strategicReviewSucceeded =>
      _it ? 'Revisione strategica completata.' : 'Strategic review completed.';
  String strategicReviewFailed(Object error) => _it
      ? 'Revisione strategica fallita: $error'
      : 'Strategic review failed: $error';
  String lastStrategicReviewLabel(String date) => _it
      ? 'Ultima revisione strategica: $date'
      : 'Last strategic review: $date';
  String get neverReviewedStrategicallyLabel =>
      _it ? 'Non ancora esaminato' : 'Not yet reviewed';
  String get noStrategicReviewYet => _it
      ? 'Esegui la revisione strategica per ottenere una raccomandazione esecutiva su questa opportunità.'
      : 'Run a strategic review to get an executive recommendation on this opportunity.';
  String get executiveRecommendationLabel =>
      _it ? 'Raccomandazione esecutiva' : 'Executive recommendation';
  String get aiRecommendationLabel =>
      _it ? 'Raccomandazione AI' : 'AI Recommendation';
  String get yourDecisionLabel => _it ? 'La tua decisione' : 'Your Decision';
  String get recordDecisionButton =>
      _it ? 'Registra decisione' : 'Record Decision';
  String get decisionReasonFieldLabel =>
      _it ? 'Motivazione (facoltativa)' : 'Reason (optional)';
  String get noDecisionRecordedYetMessage => _it
      ? 'Nessuna decisione ancora registrata su questa opportunità.'
      : 'No decision has been recorded on this opportunity yet.';
  String decisionRecordedByLabel(String by, String date) =>
      _it ? 'Deciso da $by · $date' : 'Decided by $by · $date';
  String get decisionAgreesWithAiLabel => _it
      ? 'In linea con la raccomandazione AI'
      : 'Agrees with AI recommendation';
  String get decisionOverridesAiLabel => _it
      ? 'In disaccordo con la raccomandazione AI — la raccomandazione AI resta invariata come contesto storico.'
      : 'Overrides the AI recommendation — the AI recommendation remains unchanged as historical context.';
  String get decisionRecordedMessage =>
      _it ? 'Decisione registrata.' : 'Decision recorded.';
  String get submissionNeedsActionSubtitle => _it
      ? 'Questo invio ha elementi bloccanti da risolvere.'
      : 'This submission has blockers that need resolving.';
  String get opportunityAwaitingTriageSubtitle => _it
      ? 'Scoperta ma non ancora esaminata.'
      : 'Discovered but not yet triaged.';
  String get executiveSummaryLabel =>
      _it ? 'Sintesi esecutiva' : 'Executive summary';
  String get strategicStrengthsLabel =>
      _it ? 'Punti di forza strategici' : 'Strategic strengths';
  String get strategicWeaknessesLabel =>
      _it ? 'Punti deboli strategici' : 'Strategic weaknesses';
  String get strategicRisksLabel => _it ? 'Rischi' : 'Risks';
  String get mitigationStrategiesLabel =>
      _it ? 'Strategie di mitigazione' : 'Mitigation strategies';
  String get competitiveAdvantagesLabel =>
      _it ? 'Vantaggi competitivi' : 'Competitive advantages';
  String get missingRequirementsLabel =>
      _it ? 'Requisiti mancanti' : 'Missing requirements';
  String get nextRecommendedActionsLabel =>
      _it ? 'Prossime azioni consigliate' : 'Next recommended actions';
  String get proposalPositioningStrategyLabel => _it
      ? 'Strategia di posizionamento della proposta'
      : 'Proposal positioning strategy';
  String get recommendedServicesLabel =>
      _it ? 'Servizi consigliati' : 'Recommended services';
  String get recommendedCapabilitiesLabel =>
      _it ? 'Competenze consigliate' : 'Recommended capabilities';
  String get recommendedTechnologiesLabel =>
      _it ? 'Tecnologie consigliate' : 'Recommended technologies';
  String strategicReviewRecommendationLabel(
    StrategicReviewRecommendation recommendation,
  ) {
    switch (recommendation) {
      case StrategicReviewRecommendation.pursue:
        return _it ? 'Perseguire' : 'Pursue';
      case StrategicReviewRecommendation.pursueWithCaution:
        return _it ? 'Perseguire con cautela' : 'Pursue with Caution';
      case StrategicReviewRecommendation.doNotPursue:
        return _it ? 'Non perseguire' : 'Do Not Pursue';
    }
  }

  // AI Recommendations (Milestone 3.6)
  String get recommendationsScreenTitle =>
      _it ? 'Raccomandazioni AI' : 'AI Recommendations';
  String get aiRecommendationsSectionTitle =>
      _it ? 'Raccomandazioni AI' : 'AI Recommendations';
  String get viewAllRecommendationsButton => _it ? 'Vedi tutte' : 'View all';
  String get refreshRecommendationsButton =>
      _it ? 'Aggiorna raccomandazioni' : 'Refresh Recommendations';
  String recommendationsRefreshSucceeded(int count) {
    if (count == 0) {
      return _it
          ? 'Nessuna nuova raccomandazione al momento.'
          : 'No new recommendations right now.';
    }
    return _it
        ? '$count nuove raccomandazioni generate.'
        : '$count new recommendations generated.';
  }

  String recommendationsRefreshFailed(Object error) => _it
      ? 'Aggiornamento raccomandazioni fallito: $error'
      : 'Refreshing recommendations failed: $error';
  String get noActiveRecommendations => _it
      ? 'Nessuna raccomandazione attiva. Aggiorna per far analizzare all\'AI il portafoglio opportunità.'
      : 'No active recommendations. Refresh to have AI analyze your opportunity portfolio.';
  String get noDismissedRecommendations => _it
      ? 'Nessuna raccomandazione ignorata.'
      : 'No dismissed recommendations.';
  String get noActionedRecommendations => _it
      ? 'Nessuna raccomandazione già gestita.'
      : 'No actioned recommendations yet.';
  String get dismissRecommendationTooltip => _it ? 'Ignora' : 'Dismiss';
  String get markActionedTooltip =>
      _it ? 'Segna come gestita' : 'Mark actioned';
  String get recommendationDismissed =>
      _it ? 'Raccomandazione ignorata.' : 'Recommendation dismissed.';
  String get recommendationActioned => _it
      ? 'Raccomandazione segnata come gestita.'
      : 'Recommendation marked as actioned.';
  String get relatedOpportunitiesLabel =>
      _it ? 'Opportunità collegate' : 'Related opportunities';
  String get recommendedIndustriesLabel =>
      _it ? 'Settori consigliati' : 'Recommended industries';
  String get filterActiveLabel => _it ? 'Attive' : 'Active';
  String get filterActionedLabel => _it ? 'Gestite' : 'Actioned';
  String get filterDismissedLabel => _it ? 'Ignorate' : 'Dismissed';
  String recommendationCategoryLabel(RecommendationCategory c) {
    if (!_it) return c.label;
    return switch (c) {
      RecommendationCategory.priorityOpportunity => 'Opportunità prioritaria',
      RecommendationCategory.atRiskOpportunity => 'Opportunità a rischio',
      RecommendationCategory.capabilityGap => 'Lacuna di competenze',
      RecommendationCategory.resourceAllocation => 'Allocazione risorse',
      RecommendationCategory.general => 'Generale',
    };
  }

  // AI Notifications (Milestone 3.7)
  String get notificationCenterTitle => _it ? 'Notifiche' : 'Notifications';
  String get notificationBellTooltip => _it ? 'Notifiche' : 'Notifications';
  String get markAllReadButton =>
      _it ? 'Segna tutte come lette' : 'Mark all read';
  String get noNotificationsYet => _it
      ? 'Tutto in ordine. Nessuna notifica al momento.'
      : "You're all caught up. Nothing needs your attention right now.";
  String get recommendationsGroupLabel =>
      _it ? 'Raccomandazioni' : 'Recommendations';
  String get upcomingDeadlinesGroupLabel =>
      _it ? 'Scadenze in arrivo' : 'Upcoming deadlines';
  String deadlineOverdueLabel(int daysAgo) => _it
      ? 'Scadenza superata da ${daysAgo}g'
      : 'Deadline passed ${daysAgo}d ago';
  String get deadlineDueTodayLabel => _it ? 'Scade oggi' : 'Deadline is today';
  String deadlineDueInLabel(int daysLeft) =>
      _it ? 'Scade tra ${daysLeft}g' : 'Deadline in ${daysLeft}d';

  // Proposal Workspace (Milestone 4.1)
  String get proposalTooltip => _it ? 'Proposta' : 'Proposal';
  String get proposalWorkspaceTitle =>
      _it ? 'Area di lavoro proposta' : 'Proposal Workspace';
  String get createProposalEmptyStateTitle =>
      _it ? 'Inizia la tua proposta' : "Let's start your proposal";
  String get createProposalEmptyStateBody => _it
      ? 'Crea una proposta strutturata con le sezioni standard, pronta da compilare.'
      : "We'll scaffold a structured proposal with standard sections, ready for you to fill in.";
  String get createProposalButton => _it ? 'Crea proposta' : 'Create Proposal';
  String sectionsCompletedLabel(int approved, int total) => _it
      ? '$approved di $total sezioni approvate'
      : '$approved of $total sections approved';
  String get markReadyForReviewButton =>
      _it ? 'Segna pronta per revisione' : 'Mark ready for review';
  String get reopenForEditingButton =>
      _it ? 'Riapri per modifiche' : 'Reopen for editing';
  String get addSectionButton => _it ? 'Aggiungi sezione' : 'Add section';
  String get fieldSectionTitle => _it ? 'Titolo sezione' : 'Section title';
  String get sectionContentHint =>
      _it ? 'Inizia a scrivere questa sezione…' : 'Start writing this section…';
  String get sectionEmptyPreview => _it
      ? 'Non ancora iniziata — tocca per scrivere'
      : 'Not started — tap to write';
  String get markSectionApprovedButton =>
      _it ? 'Segna come approvata' : 'Mark approved';
  String get reopenSectionButton => _it ? 'Riapri' : 'Reopen';
  String get deleteSectionConfirmTitle =>
      _it ? 'Eliminare la sezione?' : 'Delete this section?';
  String get deleteSectionConfirmBody => _it
      ? 'Questa azione non può essere annullata.'
      : 'This action cannot be undone.';
  String proposalStatusLabel(ProposalStatus status) {
    if (!_it) return status.label;
    return switch (status) {
      ProposalStatus.draft => 'Bozza',
      ProposalStatus.readyForReview => 'Pronta per revisione',
      ProposalStatus.finalized => 'Finalizzata',
    };
  }

  // AI Proposal Workspace (Milestone 4.1 redesign)
  String proposalReadinessLabel(ProposalReadiness r) {
    return switch (r) {
      ProposalReadiness.readyToSubmit =>
        _it ? 'Pronta per l\'invio' : 'Ready to submit',
      ProposalReadiness.onTrack => _it ? 'In linea' : 'On track',
      ProposalReadiness.atRisk => _it ? 'A rischio' : 'At risk',
      ProposalReadiness.behindSchedule =>
        _it ? 'In ritardo' : 'Behind schedule',
    };
  }

  String proposalLastUpdatedLabel(String date) =>
      _it ? 'Ultimo aggiornamento: $date' : 'Last updated: $date';

  String get aiProposalSummarySectionTitle =>
      _it ? 'Riepilogo IA della proposta' : 'AI Proposal Summary';
  String get aiSummaryFromStrategicReviewCaption => _it
      ? 'Dalla revisione strategica dell\'opportunità'
      : 'From the opportunity\'s strategic review';
  String get noStrategicReviewForProposalPrompt => _it
      ? 'Esegui una revisione strategica dall\'area di lavoro dell\'opportunità per vedere qui la guida dell\'IA.'
      : 'Run a strategic review from the Opportunity Workspace to see AI guidance here.';
  String get proposalReadinessAssessmentTitle =>
      _it ? 'Valutazione di completamento' : 'Proposal readiness assessment';
  String incompleteSectionsCountLabel(int count) =>
      _it ? '$count sezioni da completare' : '$count sections still incomplete';
  String unassignedSectionsCountLabel(int count) => _it
      ? '$count sezioni senza responsabile'
      : '$count sections have no owner assigned';
  String get allSectionsCompleteLabel =>
      _it ? 'Tutte le sezioni sono complete.' : 'All sections are complete.';

  String get proposalProgressSectionTitle =>
      _it ? 'Avanzamento della proposta' : 'Proposal Progress';

  String get aiStatusNotYetAssistedLabel =>
      _it ? 'IA: non ancora assistita' : 'AI: not yet assisted';
  String get regenerateWithAiTooltip =>
      _it ? 'Rigenera con IA' : 'Regenerate with AI';
  String get comingInFutureMilestoneTooltip => _it
      ? 'Disponibile in un prossimo aggiornamento'
      : 'Coming in a future milestone';

  String get teamCollaborationSectionTitle =>
      _it ? 'Collaborazione del team' : 'Team Collaboration';
  String get proposalOwnerLabel => _it ? 'Responsabile' : 'Owner';
  String get unassignedLabel => _it ? 'Non assegnato' : 'Unassigned';
  String approvalStageInPreparationLabel(String owner) =>
      _it ? 'In preparazione · $owner' : 'In preparation · $owner';
  String get approvalStageAwaitingReviewLabel =>
      _it ? 'In attesa di revisione del team' : 'Awaiting team review';
  String get outstandingActionsSectionLabel =>
      _it ? 'Azioni in sospeso' : 'Outstanding actions';
  String get noOutstandingActionsLabel => _it
      ? 'Nessuna azione in sospeso — ottimo lavoro!'
      : 'Nothing outstanding — great work!';
  String sectionNeedsCompletionLabel(String title) =>
      _it ? 'Completare: $title' : 'Complete: $title';
  String sectionNeedsOwnerLabel(String title) =>
      _it ? 'Assegnare un responsabile: $title' : 'Assign an owner: $title';

  String get proposalTimelineSectionTitle => _it ? 'Cronologia' : 'Timeline';
  String timelineProposalCreatedLabel(String date) =>
      _it ? 'Proposta creata · $date' : 'Proposal created · $date';
  String timelineMarkedReadyLabel(String date) => _it
      ? 'Segnata pronta per revisione · $date'
      : 'Marked ready for review · $date';
  String timelineLastActivityLabel(String date) =>
      _it ? 'Ultima attività · $date' : 'Last activity · $date';

  String get aiAssistantPanelSectionTitle =>
      _it ? 'Assistente IA' : 'AI Assistant';
  String get regenerateSectionActionLabel =>
      _it ? 'Rigenera sezione' : 'Regenerate section';
  String get improveWritingActionLabel =>
      _it ? 'Migliora il testo' : 'Improve writing';
  String get identifyRisksActionLabel =>
      _it ? 'Individua i rischi' : 'Identify risks';
  String get suggestMissingContentActionLabel =>
      _it ? 'Suggerisci contenuti mancanti' : 'Suggest missing content';
  String get explainRecommendationsActionLabel =>
      _it ? 'Spiega le raccomandazioni' : 'Explain recommendations';

  String proposalSectionStatusLabel(ProposalSectionStatus status) {
    if (!_it) return status.label;
    return switch (status) {
      ProposalSectionStatus.notStarted => 'Non iniziata',
      ProposalSectionStatus.aiDrafted => 'Bozza IA',
      ProposalSectionStatus.edited => 'Modificata',
      ProposalSectionStatus.approved => 'Approvata',
    };
  }

  String proposalSectionTypeLabel(ProposalSectionType type) {
    if (!_it) return type.label;
    return switch (type) {
      ProposalSectionType.executiveSummary => 'Riepilogo esecutivo',
      ProposalSectionType.understandingOfRequirements =>
        'Comprensione dei requisiti',
      ProposalSectionType.companyProfile => 'Profilo aziendale',
      ProposalSectionType.technicalApproach => 'Approccio tecnico',
      ProposalSectionType.methodology => 'Metodologia',
      ProposalSectionType.workPlan => 'Piano di lavoro',
      ProposalSectionType.companyExperience => 'Esperienza rilevante',
      ProposalSectionType.teamQualifications => 'Team e competenze',
      ProposalSectionType.productsAndTechnologies => 'Prodotti e tecnologie',
      ProposalSectionType.riskManagement => 'Gestione del rischio',
      ProposalSectionType.pricingApproach => 'Approccio ai prezzi',
      ProposalSectionType.sustainability => 'Sostenibilità',
      ProposalSectionType.innovation => 'Innovazione',
      ProposalSectionType.valueProposition => 'Proposta di valore',
      ProposalSectionType.conclusion => 'Conclusione',
      ProposalSectionType.custom => 'Sezione personalizzata',
    };
  }

  // AI Proposal Generation Engine (Milestone 4.2)
  String get generateWithAiButton => _it ? 'Genera con IA' : 'Generate with AI';
  String get regenerateButton => _it ? 'Rigenera' : 'Regenerate';
  String get improveButton => _it ? 'Migliora' : 'Improve';
  String get expandButton => _it ? 'Espandi' : 'Expand';
  String get shortenButton => _it ? 'Accorcia' : 'Shorten';
  String get restorePreviousVersionButton =>
      _it ? 'Ripristina versione precedente' : 'Restore previous version';
  String get overwriteConfirmTitle =>
      _it ? 'Sovrascrivere le modifiche?' : 'Overwrite your changes?';
  String get overwriteConfirmBody => _it
      ? 'Questa sezione contiene modifiche manuali. La versione attuale verrà salvata e potrà essere ripristinata.'
      : 'This section has manual changes. The current version will be saved and can be restored.';
  String get generatedFromLabel => _it ? 'Generato da' : 'Generated from';
  String lastAiGenerationLabel(String date) =>
      _it ? 'Ultima generazione IA: $date' : 'Last AI generation: $date';
  String get manuallyEditedLabel =>
      _it ? 'Modificata manualmente dal team' : 'Manually edited by the team';
  String get suggestionsSectionLabel => _it ? 'Suggerimenti' : 'Suggestions';
  String suggestionLabel(SuggestionCategory category, String entityName) {
    return switch (category) {
      SuggestionCategory.missingExperience =>
        _it
            ? 'Esperienza mancante: $entityName'
            : 'Missing experience: $entityName',
      SuggestionCategory.missingTechnology =>
        _it
            ? 'Tecnologia mancante: $entityName'
            : 'Missing technology: $entityName',
      SuggestionCategory.relevantKnowledgeArticle =>
        _it
            ? 'Articolo pertinente: $entityName'
            : 'Relevant article: $entityName',
      SuggestionCategory.capabilityAlignment =>
        _it
            ? 'Competenza correlata: $entityName'
            : 'Related capability: $entityName',
    };
  }

  String proposalGenerationFailed(Object error) =>
      _it ? 'Generazione IA fallita: $error' : 'AI generation failed: $error';

  // Document Library & Submission Readiness (Milestone 4.3)
  String documentCategoryLabel(DocumentCategory category) {
    if (!_it) return category.label;
    return switch (category) {
      DocumentCategory.companyRegistration => 'Registrazione aziendale',
      DocumentCategory.taxCertificate => 'Certificato fiscale',
      DocumentCategory.license => 'Licenza',
      DocumentCategory.technicalCertification => 'Certificazione tecnica',
      DocumentCategory.isoCertificate => 'Certificato ISO',
      DocumentCategory.insurance => 'Assicurazione',
      DocumentCategory.cv => 'CV',
      DocumentCategory.companyProfile => 'Profilo aziendale',
      DocumentCategory.financialStatement => 'Bilancio',
      DocumentCategory.referenceLetter => 'Lettera di referenza',
      DocumentCategory.previousProjectEvidence =>
        'Evidenza di progetti precedenti',
      DocumentCategory.technicalBrochure => 'Brochure tecnica',
      DocumentCategory.other => 'Altro',
    };
  }

  String documentStatusLabel(DocumentStatus status) {
    if (!_it) return status.label;
    return switch (status) {
      DocumentStatus.active => 'Attivo',
      DocumentStatus.pendingReview => 'In revisione',
      DocumentStatus.needsUpdate => 'Da aggiornare',
      DocumentStatus.archived => 'Archiviato',
    };
  }

  String get documentLibraryTitle =>
      _it ? 'Libreria documenti' : 'Document Library';
  String get searchDocumentsHint =>
      _it ? 'Cerca documenti…' : 'Search documents…';
  String get noDocumentsYet => _it
      ? 'Nessun documento ancora caricato. Tocca + per aggiungerne uno.'
      : 'No documents uploaded yet. Tap + to add one.';
  String get noDocumentsMatchFilter => _it
      ? 'Nessun documento corrisponde alla ricerca.'
      : 'No documents match your search.';
  String get addDocumentTitle => _it ? 'Aggiungi documento' : 'Add document';
  String get uploadProjectDocumentTitle =>
      _it ? 'Carica documento del progetto' : 'Upload Project Document';
  String get addDocumentButton => _it ? 'Aggiungi' : 'Add';
  String get fieldDocumentTitle =>
      _it ? 'Titolo del documento' : 'Document title';
  String get fieldDocumentCategory => _it ? 'Categoria' : 'Category';
  String get fieldDocumentVersion => _it ? 'Versione' : 'Version';
  String get fieldIssueDate => _it ? 'Data di emissione' : 'Issue date';
  String get fieldExpiryDate => _it ? 'Data di scadenza' : 'Expiry date';
  String get chooseFileButton => _it ? 'Scegli file' : 'Choose file';
  String get noFileChosenLabel =>
      _it ? 'Nessun file selezionato' : 'No file chosen';
  String get documentDetailsTitle =>
      _it ? 'Dettagli documento' : 'Document Details';
  String get linkedProposalsLabel =>
      _it ? 'Proposte collegate' : 'Linked proposals';

  String get submissionReadinessSectionTitle =>
      _it ? 'Prontezza per l\'invio' : 'Submission Readiness';
  String get submissionReadyLabel =>
      _it ? 'Pronta per l\'invio' : 'Ready to submit';
  String get submissionNotReadyLabel =>
      _it ? 'Documenti mancanti' : 'Documents missing';
  String requiredDocumentsCountLabel(int count) =>
      _it ? '$count richiesti' : '$count required';
  String uploadedDocumentsCountLabel(int count) =>
      _it ? '$count caricati' : '$count uploaded';
  String missingDocumentsCountLabel(int count) =>
      _it ? '$count mancanti' : '$count missing';
  String expiredDocumentsCountLabel(int count) =>
      _it ? '$count scaduti' : '$count expired';
  String pendingReviewDocumentsCountLabel(int count) =>
      _it ? '$count in revisione' : '$count pending review';
  String needsUpdateDocumentsCountLabel(int count) =>
      _it ? '$count da aggiornare' : '$count need updating';
  String get manageDocumentsButton =>
      _it ? 'Gestisci documenti' : 'Manage documents';
  String get noSuggestionsLabel =>
      _it ? 'Nessun suggerimento al momento.' : 'No suggestions right now.';

  String documentSuggestionTitle(DocumentSuggestion suggestion) {
    return suggestion.documentTitle ??
        documentCategoryLabel(suggestion.missingCategory!);
  }

  String documentSuggestionReason(DocumentSuggestion suggestion) {
    return switch (suggestion.category) {
      DocumentSuggestionCategory.missingMandatoryDocument =>
        _it
            ? 'Richiesto per l\'invio ma non ancora collegato a questa proposta.'
            : 'Required for submission but not yet linked to this proposal.',
      DocumentSuggestionCategory.expiringCertificate =>
        suggestion.daysUntilExpiry == 0
            ? (_it ? 'Scade oggi.' : 'Expires today.')
            : (_it
                  ? 'Scade tra ${suggestion.daysUntilExpiry} giorni.'
                  : 'Expires in ${suggestion.daysUntilExpiry} day${suggestion.daysUntilExpiry == 1 ? '' : 's'}.'),
      DocumentSuggestionCategory.similarPreviousProposal =>
        _it
            ? 'Usato in un\'altra proposta per un settore simile.'
            : 'Used in another proposal for a similar industry.',
      DocumentSuggestionCategory.relevantTechnicalBrochure =>
        _it
            ? 'Documenta una tecnologia con cui questa opportunità è classificata.'
            : 'Documents a technology this opportunity is classified against.',
      DocumentSuggestionCategory.recommendedExperienceDocument =>
        _it
            ? 'Documenta un\'esperienza passata con cui questa opportunità è classificata.'
            : 'Documents a past experience this opportunity is classified against.',
    };
  }

  // Opportunity pipeline (Milestone 3.2)
  String get pipelineScreenTitle =>
      _it ? 'Pipeline opportunità' : 'Opportunity pipeline';
  String get pipelineTooltip => _it ? 'Pipeline' : 'Pipeline';
  String get currentStageLabel => _it ? 'Fase attuale' : 'Current stage';
  String get changeStageButton => _it ? 'Cambia fase' : 'Change stage';
  String get selectNewStageLabel =>
      _it ? 'Seleziona la nuova fase' : 'Select the new stage';
  String get transitionNoteLabel =>
      _it ? 'Nota (facoltativa)' : 'Note (optional)';
  String get pipelineHistoryTitle =>
      _it ? 'Cronologia della pipeline' : 'Pipeline history';
  String get noEventsYet => _it
      ? 'Nessuna transizione di fase ancora registrata.'
      : 'No stage transitions recorded yet.';
  String get fieldAssignedTo => _it ? 'Assegnato a' : 'Assigned to';
  String get fieldReviewNotes => _it ? 'Note di revisione' : 'Review notes';
  String get fieldQualificationNotes =>
      _it ? 'Note di qualificazione' : 'Qualification notes';
  String get fieldSubmittedDate => _it ? 'Data di invio' : 'Submitted date';
  String get fieldDecisionDate => _it ? 'Data di decisione' : 'Decision date';
  String get fieldClosedReason => _it ? 'Motivo di chiusura' : 'Closed reason';
  String get sectionPipelineDetails =>
      _it ? 'Dettagli della pipeline' : 'Pipeline details';

  // Settings
  String get settingsTitle => _it ? 'Impostazioni' : 'Settings';
  String get settingsTooltip => settingsTitle;
  String get sectionAppearance => _it ? 'Aspetto' : 'Appearance';
  String get themeSystem => _it ? 'Sistema' : 'System';
  String get themeLight => _it ? 'Chiaro' : 'Light';
  String get themeDark => _it ? 'Scuro' : 'Dark';
  String get fontLabel => _it ? 'Carattere' : 'Font';
  String get sectionLanguage => _it ? 'Lingua' : 'Language';
  String get languageEnglish => 'English';
  String get languageItalian => 'Italiano';
  String get sectionProfile => _it ? 'Profilo' : 'Profile';
  String get signedInAs => _it ? 'Accesso effettuato come' : 'Signed in as';
  String get roleLabel => _it ? 'Ruolo' : 'Role';
  String get signOutButton => _it ? 'Esci' : 'Sign out';

  // Auth
  String get fieldEmail => _it ? 'Email' : 'Email';
  String get fieldPassword => _it ? 'Password' : 'Password';
  String get fieldConfirmPassword =>
      _it ? 'Conferma password' : 'Confirm password';
  String get emailRequired =>
      _it ? 'L\'email è obbligatoria' : 'Email is required';
  String get passwordRequired =>
      _it ? 'La password è obbligatoria' : 'Password is required';
  String get useAtLeast6Chars =>
      _it ? 'Usa almeno 6 caratteri' : 'Use at least 6 characters';
  String get passwordsDoNotMatch =>
      _it ? 'Le password non coincidono' : 'Passwords do not match';
  String get signInButton => _it ? 'Accedi' : 'Sign in';
  String get forgotPassword =>
      _it ? 'Password dimenticata?' : 'Forgot password?';
  String get createAccountButton =>
      _it ? 'Crea un account' : 'Create an account';
  String get createAccountTitle => _it ? 'Crea account' : 'Create account';
  String get enterEmailFirst =>
      _it ? 'Inserisci prima la tua email.' : 'Enter your email above first.';
  String passwordResetSent(String email) => _it
      ? 'Email di reimpostazione inviata a $email'
      : 'Password reset email sent to $email';
  String get invalidEmail => _it
      ? 'Questo indirizzo email non è valido.'
      : 'That email address looks invalid.';
  String get accountDisabled => _it
      ? 'Questo account è stato disabilitato.'
      : 'This account has been disabled.';
  String get incorrectCredentials =>
      _it ? 'Email o password errati.' : 'Incorrect email or password.';
  String get emailAlreadyInUse => _it
      ? 'Esiste già un account per questa email.'
      : 'An account already exists for that email.';
  String get weakPassword => _it
      ? 'La password è troppo debole (usa almeno 6 caratteri).'
      : 'Password is too weak (use at least 6 characters).';
  String get signInFailed => _it ? 'Accesso fallito.' : 'Sign-in failed.';
  String get signUpFailed => _it ? 'Registrazione fallita.' : 'Sign-up failed.';

  // Enum labels — parallel to each model's English-only `.label` getter,
  // used wherever a status/category is shown to the user.
  String projectStatusLabel(ProjectStatus s) {
    if (!_it) return s.label;
    return switch (s) {
      ProjectStatus.planned => 'Pianificato',
      ProjectStatus.running => 'In corso',
      ProjectStatus.past => 'Concluso',
    };
  }

  String projectCategoryLabel(ProjectCategory c) {
    if (!_it) return c.label;
    return switch (c) {
      ProjectCategory.residential => 'Residenziale',
      ProjectCategory.roads => 'Strade',
      ProjectCategory.waterSanitation => 'Acqua e igiene',
      ProjectCategory.commercial => 'Commerciale',
      ProjectCategory.industrial => 'Industriale',
      ProjectCategory.other => 'Altro',
    };
  }

  String contractorRoleLabel(ContractorRole r) {
    if (!_it) return r.label;
    return switch (r) {
      ContractorRole.mainContractor => 'Appaltatore principale',
      ContractorRole.subcontractor => 'Subappaltatore',
      ContractorRole.consultant => 'Consulente',
    };
  }

  String clientTypeLabel(ClientType c) {
    if (!_it) return c.label;
    return switch (c) {
      ClientType.government => 'Pubblico',
      ClientType.privateClient => 'Privato',
      ClientType.ngo => 'ONG',
    };
  }

  String applicationStatusLabel(ApplicationStatus s) {
    if (!_it) return s.label;
    return switch (s) {
      ApplicationStatus.active => 'Attiva',
      ApplicationStatus.maintenance => 'Manutenzione',
      ApplicationStatus.deprecated => 'Deprecata',
    };
  }

  String opportunityStatusLabel(OpportunityStatus s) {
    if (!_it) return s.label;
    return switch (s) {
      OpportunityStatus.discovered => 'Scoperto',
      OpportunityStatus.reviewing => 'In revisione',
      OpportunityStatus.applied => 'Candidato',
      OpportunityStatus.won => 'Vinto',
      OpportunityStatus.lost => 'Perso',
      OpportunityStatus.dismissed => 'Respinto',
      OpportunityStatus.archived => 'Archiviato',
    };
  }

  String discoverySourceTypeLabel(DiscoverySourceType t) {
    if (!_it) return t.label;
    return switch (t) {
      DiscoverySourceType.governmentProcurement => 'Appalti pubblici',
      DiscoverySourceType.developmentOrganization =>
        'Organizzazioni di sviluppo',
      DiscoverySourceType.unProcurement => 'Appalti ONU',
      DiscoverySourceType.ngo => 'Opportunità ONG',
      DiscoverySourceType.privateSector => 'Gare private',
      DiscoverySourceType.rss => 'Feed RSS',
      DiscoverySourceType.api => 'API',
      DiscoverySourceType.manual => 'Importazione manuale',
    };
  }

  String discoveryRunStatusLabel(DiscoveryRunStatus s) {
    if (!_it) return s.label;
    return switch (s) {
      DiscoveryRunStatus.running => 'In corso',
      DiscoveryRunStatus.completed => 'Completata',
      DiscoveryRunStatus.failed => 'Fallita',
    };
  }

  String discoveryRunTriggerLabel(DiscoveryRunTrigger t) {
    if (!_it) return t.label;
    return switch (t) {
      DiscoveryRunTrigger.manual => 'Manuale',
      DiscoveryRunTrigger.scheduled => 'Pianificata',
    };
  }

  String tenderSourceCategoryLabel(TenderSourceCategory c) {
    if (!_it) return c.label;
    return switch (c) {
      TenderSourceCategory.governmentAgency => 'Ente governativo',
      TenderSourceCategory.countyGovernment => 'Governo di contea',
      TenderSourceCategory.developmentPartner => 'Partner di sviluppo',
      TenderSourceCategory.unAgency => 'Agenzia ONU',
      TenderSourceCategory.ngo => 'ONG',
      TenderSourceCategory.privateSector => 'Settore privato',
      TenderSourceCategory.customEnterprise => 'Impresa personalizzata',
    };
  }

  String tenderDiscoveryMethodLabel(TenderDiscoveryMethod m) {
    if (!_it) return m.label;
    return switch (m) {
      TenderDiscoveryMethod.api => 'API',
      TenderDiscoveryMethod.rss => 'Feed RSS',
      TenderDiscoveryMethod.htmlScraping => 'Web scraping',
      TenderDiscoveryMethod.email => 'Casella email',
      TenderDiscoveryMethod.manual => 'Importazione manuale',
    };
  }

  String tenderSourceStatusLabel(TenderSourceStatus s) {
    if (!_it) return s.label;
    return switch (s) {
      TenderSourceStatus.active => 'Attiva',
      TenderSourceStatus.paused => 'In pausa',
      TenderSourceStatus.offline => 'Offline',
      TenderSourceStatus.error => 'Errore',
    };
  }

  String tenderSyncRunStatusLabel(TenderSyncRunStatus s) {
    if (!_it) return s.label;
    return switch (s) {
      TenderSyncRunStatus.running => 'In corso',
      TenderSyncRunStatus.completed => 'Completata',
      TenderSyncRunStatus.failed => 'Fallita',
    };
  }

  String tenderSyncTriggerLabel(TenderSyncTrigger t) {
    if (!_it) return t.label;
    return switch (t) {
      TenderSyncTrigger.manual => 'Manuale',
      TenderSyncTrigger.scheduled => 'Pianificata',
    };
  }

  // --- Add as a new section, e.g. after the Discovery Sources/History strings ---

  // Discovery Dashboard (Milestone 3.8b)
  String get discoveryDashboardTitle =>
      _it ? 'Motore di Discovery' : 'Discovery Engine';
  String get discoveryHealthLabel =>
      _it ? 'Salute della discovery' : 'Discovery Health';
  String get activeSourcesLabel => _it ? 'Fonti attive' : 'Active Sources';
  String get offlineSourcesLabel => _it ? 'Fonti offline' : 'Offline Sources';
  String get syncErrorsLabel =>
      _it ? 'Errori di sincronizzazione' : 'Sync Errors';
  String get importedTodayLabel =>
      _it ? 'Importate oggi' : 'Opportunities Imported Today';
  String get awaitingAiReviewLabel =>
      _it ? 'In attesa di revisione AI' : 'Awaiting AI Review';
  String get duplicateOpportunitiesLabel =>
      _it ? 'Opportunità duplicate' : 'Duplicate Opportunities';
  String get aiRecommendedLabel =>
      _it ? 'Raccomandate dall\'AI' : 'AI Recommended';
  String get averageWinRateLabel =>
      _it ? 'Tasso di successo medio' : 'Average Win Rate';
  String get lastSynchronizationLabel =>
      _it ? 'Ultima sincronizzazione' : 'Last Synchronization';
  String get nextSynchronizationLabel =>
      _it ? 'Prossima sincronizzazione' : 'Next Synchronization';
  String get noSyncDataYetMessage =>
      _it ? 'Nessuna sincronizzazione ancora' : 'No syncs yet';
  String get noTenderSourcesConfiguredMessage => _it
      ? 'Nessuna fonte gara configurata ancora'
      : 'No tender sources configured yet';
  String get recentSyncActivityLabel =>
      _it ? 'Attività di sincronizzazione recente' : 'Recent Sync Activity';
  String get outOfSourcesLabel => _it ? 'su' : 'of';

  // Milestone 3.8c — Tender Source Workspace.
  // Reuses existing getters where possible: fieldSourceName, fieldSearchQuery,
  // fieldCategory, fieldCountry, cancelButton, saveButton, addButton,
  // runNowButton, errorPrefix.

  String get tenderSourcesTitle => _it ? 'Fonti Gare' : 'Tender Sources';
  String get seedProductionSourcesButton =>
      _it ? 'Popola fonti reali' : 'Seed Production Sources';
  String seedResultMessage(int created, int skipped) => _it
      ? '$created nuove fonti create, $skipped già esistenti'
      : '$created new sources created, $skipped already existed';
  String get addTenderSourceTitle =>
      _it ? 'Aggiungi fonte gara' : 'Add Tender Source';
  String get editTenderSourceTitle =>
      _it ? 'Modifica fonte gara' : 'Edit Tender Source';
  String get fieldOrganization => _it ? 'Organizzazione' : 'Organization';
  String get fieldDiscoveryMethod =>
      _it ? 'Metodo di discovery' : 'Discovery Method';
  String get fieldWebsite => _it ? 'Sito web' : 'Website';
  String get fieldSyncFrequency => _it
      ? 'Frequenza di sincronizzazione (minuti)'
      : 'Sync Frequency (minutes)';
  String get fieldTags => _it ? 'Tag' : 'Tags';
  String get fieldFeedUrl => _it ? 'URL del feed RSS' : 'RSS Feed URL';
  String get fieldPageUrl => _it ? 'URL della pagina' : 'Page URL';
  String get fieldEndpointUrl => _it ? 'URL dell\'endpoint' : 'Endpoint URL';
  String get fieldApiModeLabel => _it ? 'Modalità API' : 'API Mode';
  String get apiModeAiSearch => _it ? 'Ricerca AI' : 'AI Search';
  String get apiModeRestJson => _it ? 'REST JSON' : 'REST JSON';
  String get fieldItemSelector => _it ? 'Selettore elemento' : 'Item Selector';
  String get fieldTitleSelector => _it ? 'Selettore titolo' : 'Title Selector';
  String get fieldSourceUrlSelector =>
      _it ? 'Selettore URL' : 'Source URL Selector';
  String get fieldDescriptionSelector =>
      _it ? 'Selettore descrizione' : 'Description Selector';
  String get fieldDeadlineSelector =>
      _it ? 'Selettore scadenza' : 'Deadline Selector';
  String get testConnectionButton =>
      _it ? 'Verifica connessione' : 'Test Connection';
  String get testingConnectionLabel => _it ? 'Verifica in corso…' : 'Testing…';
  String get deleteSourceButton => _it ? 'Elimina fonte' : 'Delete Source';
  String get deleteSourceConfirmMessage => _it
      ? 'Eliminare questa fonte gara? Le opportunità già importate non verranno rimosse.'
      : 'Delete this tender source? Opportunities already imported won\'t be removed.';
  String get pauseSourceButton => _it ? 'Metti in pausa' : 'Pause';
  String get resumeSourceButton => _it ? 'Riprendi' : 'Resume';
  String get organizationProfileLabel =>
      _it ? 'Profilo organizzazione' : 'Organization Profile';
  String get syncHistoryLabel =>
      _it ? 'Cronologia sincronizzazioni' : 'Synchronization History';
  String get aiQualityScoreLabel =>
      _it ? 'Punteggio qualità AI' : 'AI Quality Score';
  String get historicalWinRateLabel =>
      _it ? 'Tasso di successo storico' : 'Historical Win Rate';
  String get opportunitiesImportedLabel =>
      _it ? 'Opportunità importate' : 'Opportunities Imported';
  String get avgOpportunitiesPerMonthLabel =>
      _it ? 'Media opportunità/mese' : 'Avg. Opportunities / Month';
  String get noAiQualityScoreYetMessage =>
      _it ? 'Non ancora calcolato' : 'Not yet calculated';
  String get sourceCreatedLabel => _it ? 'Fonte creata' : 'Source created';
  String get importHistoryComingSoonMessage => _it
      ? 'La cronologia importazioni per fonte arriverà in un prossimo aggiornamento.'
      : 'Per-source import history is coming in a future update.';

  // Milestone 3.8d — Tender Analytics. Reuses winRateLabel (already defined
  // below, for the Proposal win-rate feature) rather than redeclaring it.

  String get tenderAnalyticsTitle => _it ? 'Analisi Gare' : 'Tender Analytics';
  String get discoveredLabel => _it ? 'Scoperte' : 'Discovered';
  String get pursuedLabel => _it ? 'Perseguite' : 'Pursued';
  String get winsLabel => _it ? 'Vinte' : 'Wins';
  String get lossesLabel => _it ? 'Perse' : 'Losses';
  String get totalContractValueWonLabel =>
      _it ? 'Valore totale contratti vinti' : 'Total Contract Value Won';
  String get averageAiConfidenceLabel =>
      _it ? 'Confidenza AI media' : 'Average AI Confidence';
  String get monthlyTrendLabel => _it ? 'Andamento mensile' : 'Monthly Trend';
  String get bestPerformingSectorsLabel =>
      _it ? 'Settori migliori' : 'Best-Performing Sectors';
  String get bestPerformingBusinessUnitsLabel =>
      _it ? 'Unità aziendali migliori' : 'Best-Performing Business Units';
  String get bestPerformingSourcesLabel =>
      _it ? 'Fonti migliori' : 'Best-Performing Sources';
  String get importHistoryLabel =>
      _it ? 'Cronologia importazioni' : 'Import History';
  String get noOutcomeRecordedYetMessage =>
      _it ? 'Nessun esito registrato' : 'No outcome recorded yet';
  String get noAnalyticsDataYetMessage => _it
      ? 'Nessun dato disponibile ancora — verrà popolato man mano che le fonti importano opportunità.'
      : 'No data yet — this fills in as sources import opportunities.';

  String classificationStatusLabel(ClassificationStatus s) {
    if (!_it) return s.label;
    return switch (s) {
      ClassificationStatus.notClassified => 'Non classificato',
      ClassificationStatus.processing => 'In elaborazione',
      ClassificationStatus.classified => 'Classificato',
      ClassificationStatus.needsReview => 'Richiede revisione',
    };
  }

  String estimatedComplexityLabel(EstimatedComplexity c) {
    if (!_it) return c.label;
    return switch (c) {
      EstimatedComplexity.low => 'Bassa',
      EstimatedComplexity.medium => 'Media',
      EstimatedComplexity.high => 'Alta',
    };
  }

  String riskLevelLabel(RiskLevel r) {
    if (!_it) return r.label;
    return switch (r) {
      RiskLevel.low => 'Basso',
      RiskLevel.medium => 'Medio',
      RiskLevel.high => 'Alto',
    };
  }

  String opportunityPriorityLabel(OpportunityPriority p) {
    if (!_it) return p.label;
    return switch (p) {
      OpportunityPriority.low => 'Bassa',
      OpportunityPriority.medium => 'Media',
      OpportunityPriority.high => 'Alta',
    };
  }

  String pipelineStageLabel(OpportunityPipelineStage s) {
    if (!_it) return s.label;
    return switch (s) {
      OpportunityPipelineStage.discovered => 'Scoperta',
      OpportunityPipelineStage.classified => 'Classificata',
      OpportunityPipelineStage.reviewed => 'Revisionata',
      OpportunityPipelineStage.qualified => 'Qualificata',
      OpportunityPipelineStage.approved => 'Approvata',
      OpportunityPipelineStage.proposalStarted => 'Proposta avviata',
      OpportunityPipelineStage.proposalReady => 'Proposta pronta',
      OpportunityPipelineStage.submitted => 'Inviata',
      OpportunityPipelineStage.evaluation => 'In valutazione',
      OpportunityPipelineStage.negotiation => 'In negoziazione',
      OpportunityPipelineStage.awarded => 'Aggiudicata',
      OpportunityPipelineStage.lost => 'Persa',
      OpportunityPipelineStage.projectStarted => 'Progetto avviato',
      OpportunityPipelineStage.completed => 'Completata',
    };
  }

  String userRoleLabel(UserRole r) {
    if (!_it) return r.label;
    return switch (r) {
      UserRole.admin => 'Amministratore',
      UserRole.user => 'Utente',
    };
  }

  // Executive Dashboard (Milestone 5.1)
  String get navAnalytics => _it ? 'Analisi' : 'Analytics';
  String get executiveDashboardTitle =>
      _it ? 'Cruscotto esecutivo' : 'Executive Dashboard';
  String get executiveDashboardSubtitle => _it
      ? 'Come sta andando la pipeline aziendale, in 30 secondi.'
      : "How the business pipeline is doing, in 30 seconds.";

  String get aiExecutiveSummaryTitle =>
      _it ? 'Sintesi esecutiva AI' : 'AI Executive Summary';
  String get regenerateSummaryButton =>
      _it ? 'Rigenera sintesi' : 'Regenerate summary';
  String get neverGeneratedSummaryMessage => _it
      ? 'Nessuna sintesi generata finora. Tocca "Rigenera sintesi" per crearne una.'
      : 'No summary generated yet. Tap "Regenerate summary" to create one.';
  String lastGeneratedLabel(String date) =>
      _it ? 'Ultima generazione: $date' : 'Last generated: $date';
  String get executiveSummarySucceeded =>
      _it ? 'Sintesi esecutiva aggiornata.' : 'Executive summary updated.';
  String executiveSummaryFailed(Object error) => _it
      ? 'Generazione della sintesi non riuscita: $error'
      : 'Executive summary generation failed: $error';

  String get kpiActiveOpportunities =>
      _it ? 'Opportunità attive' : 'Active opportunities';
  String get kpiPipelineValue => _it ? 'Valore pipeline' : 'Pipeline value';
  String get kpiWinRate => _it ? 'Tasso di successo' : 'Win rate';
  String get kpiLossRate => _it ? 'Tasso di perdita' : 'Loss rate';
  String get kpiRevenueForecast =>
      _it ? 'Previsione di ricavi' : 'Revenue forecast';
  String get kpiProposalsReadyForReview =>
      _it ? 'Proposte pronte per revisione' : 'Proposals ready for review';
  String get kpiAverageProposalReadiness =>
      _it ? 'Prontezza media delle proposte' : 'Average proposal readiness';
  String decidedOpportunitiesCaption(int decided) =>
      _it ? '$decided opportunità decise' : '$decided opportunities decided';
  String ofTotalProposalsCaption(int total) =>
      _it ? 'su $total proposte totali' : 'of $total total proposals';

  String get sectionOpportunitiesByStage =>
      _it ? 'Opportunità per fase' : 'Opportunities by stage';
  String get sectionOpportunitiesByBusinessUnit => _it
      ? 'Opportunità per unità di business'
      : 'Opportunities by business unit';
  String get sectionOpportunitiesByIndustry =>
      _it ? 'Opportunità per settore' : 'Opportunities by industry';
  String get sectionTeamWorkload =>
      _it ? 'Carico di lavoro del team' : 'Team workload';

  String get sectionUpcomingSubmissions =>
      _it ? 'Prossime scadenze di invio' : 'Upcoming submissions';
  String get noUpcomingSubmissions => _it
      ? 'Nessuna scadenza di invio nei prossimi giorni.'
      : 'No submission deadlines coming up.';
  String get sectionHighRiskOpportunities =>
      _it ? 'Opportunità ad alto rischio' : 'High-risk opportunities';
  String get noHighRiskOpportunities => _it
      ? 'Nessuna opportunità attiva ad alto rischio al momento.'
      : 'No active high-risk opportunities right now.';
  String get sectionHighConfidenceOpportunities => _it
      ? 'Opportunità ad alta affidabilità'
      : 'High-confidence opportunities';
  String get noHighConfidenceOpportunities => _it
      ? 'Nessuna opportunità ad alta affidabilità al momento.'
      : 'No high-confidence opportunities right now.';
  String daysUntilDeadlineLabel(int days) {
    if (days == 0) return _it ? 'Scade oggi' : 'Due today';
    if (days == 1) return _it ? 'Scade domani' : 'Due tomorrow';
    return _it ? 'Scade tra $days giorni' : 'Due in $days days';
  }

  String executiveInsightSeverityLabel(ExecutiveInsightSeverity s) {
    if (!_it) return s.label;
    return switch (s) {
      ExecutiveInsightSeverity.info => 'Informazione',
      ExecutiveInsightSeverity.watch => 'Da monitorare',
      ExecutiveInsightSeverity.risk => 'Rischio',
    };
  }

  // Submission Workspace (Milestone 4.5)
  String get submissionWorkspaceTitle =>
      _it ? 'Area di lavoro invio' : 'Submission Workspace';
  String get noProposalForSubmissionMessage => _it
      ? 'Crea prima una proposta per avviare l\'invio.'
      : 'Create a proposal first to start a submission.';
  String get createSubmissionEmptyStateTitle =>
      _it ? 'Nessun invio avviato' : 'No submission started yet';
  String get createSubmissionEmptyStateBody => _it
      ? 'Avvia un invio quando sei pronto a presentare questa proposta.'
      : 'Start a submission when you\'re ready to submit this proposal.';
  String get createSubmissionButton => _it ? 'Avvia invio' : 'Start submission';
  String get openProposalWorkspaceButton =>
      _it ? 'Apri area di lavoro proposta' : 'Open Proposal Workspace';

  String submissionStatusLabel(SubmissionStatus s) {
    if (!_it) return s.label;
    return switch (s) {
      SubmissionStatus.preparing => 'In preparazione',
      SubmissionStatus.submitted => 'Inviata',
      SubmissionStatus.underEvaluation => 'In valutazione',
      SubmissionStatus.clarificationRequested => 'Chiarimento richiesto',
      SubmissionStatus.awarded => 'Aggiudicata',
      SubmissionStatus.lost => 'Persa',
      SubmissionStatus.withdrawn => 'Ritirata',
    };
  }

  String get submissionStatusClosedMessage => _it
      ? 'Questo invio ha raggiunto uno stato definitivo (Aggiudicata, Persa o Ritirata) e non può essere riaperto qui — si tratterebbe di annullare un esito già registrato, non di una correzione.'
      : 'This submission has reached a final state (Awarded, Lost, or Withdrawn) and cannot be reopened here — that would mean reversing a recorded outcome, not correcting a mistake.';
  String get submissionStatusNotYetSubmittedMessage => _it
      ? 'Registra prima l\'invio effettivo prima di impostare un esito di valutazione.'
      : 'Record the actual submission before setting an evaluation outcome.';

  String submissionMethodLabel(SubmissionMethod m) {
    if (!_it) return m.label;
    return switch (m) {
      SubmissionMethod.portal => 'Portale',
      SubmissionMethod.email => 'Email',
      SubmissionMethod.physical => 'Fisico',
      SubmissionMethod.other => 'Altro',
    };
  }

  String communicationTypeLabel(CommunicationType t) {
    if (!_it) return t.label;
    return switch (t) {
      CommunicationType.meeting => 'Riunione',
      CommunicationType.email => 'Email',
      CommunicationType.clarification => 'Chiarimento',
      CommunicationType.addendum => 'Addendum',
      CommunicationType.reminder => 'Promemoria',
    };
  }

  String get sectionExecutiveSummary =>
      _it ? 'Sintesi esecutiva' : 'Executive Summary';
  String get sectionSubmissionBlockers =>
      _it ? 'Blocchi all\'invio' : 'Submission Blockers';
  String get noSubmissionBlockersMessage => _it
      ? 'Nessun blocco rilevato — pronto per l\'invio.'
      : 'No blockers detected — ready to submit.';
  String get sectionClientCommunication =>
      _it ? 'Comunicazione con il cliente' : 'Client Communication';
  String get noCommunicationsLoggedMessage => _it
      ? 'Nessuna comunicazione registrata finora.'
      : 'No communications logged yet.';
  String get logCommunicationButton =>
      _it ? 'Registra comunicazione' : 'Log communication';
  String get logCommunicationTitle =>
      _it ? 'Registra comunicazione' : 'Log communication';
  String get fieldCommunicationType =>
      _it ? 'Tipo di comunicazione' : 'Communication type';
  String get fieldSubject => _it ? 'Oggetto' : 'Subject';
  String get fieldDate => _it ? 'Data' : 'Date';
  String get sectionRelatedKnowledge =>
      _it ? 'Conoscenza correlata' : 'Related Knowledge';
  String get previousWinningProposalsLabel =>
      _it ? 'Proposte vinte in precedenza' : 'Previous winning proposals';
  String get noPreviousWinningProposalsMessage => _it
      ? 'Nessuna proposta vinta correlata trovata.'
      : 'No related previous wins found.';
  String get submissionOwnerLabel =>
      _it ? 'Responsabile invio' : 'Submission owner';
  String get referenceNumberLabel =>
      _it ? 'Numero di riferimento' : 'Reference number';
  String get evaluationDateLabel =>
      _it ? 'Data di valutazione' : 'Evaluation date';

  // Project Delivery Workspace (Milestone 5.1, new roadmap)
  String get projectWorkspaceTitle =>
      _it ? 'Area di lavoro progetto' : 'Project Workspace';
  String get overallHealthLabel => _it ? 'Salute generale' : 'Overall health';
  String get scheduleHealthLabel => _it ? 'Programma' : 'Schedule';
  String get budgetHealthLabel => _it ? 'Budget' : 'Budget';
  String get riskHealthLabel => _it ? 'Rischio' : 'Risk';
  String get expectedCompletionLabel =>
      _it ? 'Completamento previsto' : 'Expected completion';
  String get actualCompletionLabel => _it ? 'Completato il' : 'Completed on';
  String get projectOnTrackMessage => _it
      ? 'Il progetto procede secondo i piani — nessun problema rilevato.'
      : 'The project is on track — no issues detected.';
  String get healthOnTrackLabel => _it ? 'In linea' : 'On track';
  String get healthAtRiskLabel => _it ? 'A rischio' : 'At risk';
  String get healthUnknownLabel => _it ? 'Non disponibile' : 'Not set';
  String get healthCriticalLabel => _it ? 'Critico' : 'Critical';
  String get timelineSectionTitle => _it ? 'Cronologia' : 'Timeline';
  String get addMilestoneButton => _it ? 'Aggiungi traguardo' : 'Add Milestone';
  String get noMilestonesMessage =>
      _it ? 'Nessun traguardo aggiunto finora.' : 'No milestones added yet.';
  String get deliverablesSectionTitle => _it ? 'Consegne' : 'Deliverables';
  String get addDeliverableButton =>
      _it ? 'Aggiungi consegna' : 'Add Deliverable';
  String get noDeliverablesMessage =>
      _it ? 'Nessuna consegna aggiunta finora.' : 'No deliverables added yet.';
  String get overdueLabel => _it ? 'In ritardo' : 'Overdue';
  String get blockedLabel => _it ? 'Bloccate' : 'Blocked';
  String get pendingLabel => _it ? 'In sospeso' : 'Pending';
  String get completedLabel => _it ? 'Completate' : 'Completed';
  String get editMilestoneTitle =>
      _it ? 'Modifica traguardo' : 'Edit Milestone';
  String get editDeliverableTitle =>
      _it ? 'Modifica consegna' : 'Edit Deliverable';
  String get editRiskTitle => _it ? 'Modifica rischio' : 'Edit Risk';
  String get fieldTitle => _it ? 'Titolo' : 'Title';
  String get fieldDueDate => _it ? 'Scadenza' : 'Due date';
  String get fieldMarkCompleted =>
      _it ? 'Segna come completato' : 'Mark completed';
  String get fieldDeliverableStatus => _it ? 'Stato' : 'Status';
  String get fieldBlockedReason => _it ? 'Motivo del blocco' : 'Blocked reason';
  String get fieldSeverity => _it ? 'Gravità' : 'Severity';
  String get fieldLikelihood => _it ? 'Probabilità' : 'Likelihood';
  String get fieldRiskStatus => _it ? 'Stato' : 'Status';
  String get fieldOwner => _it ? 'Responsabile' : 'Owner';
  String get fieldMitigationActions => _it
      ? 'Azioni di mitigazione (una riga per elemento)'
      : 'Mitigation actions (one per line)';
  String get createFromExtractedSectionLabel => _it
      ? 'Crea da testo estratto (facoltativo)'
      : 'Create from extracted text (optional)';
  String get createFromExtractedHint => _it
      ? 'Tocca un elemento estratto dal documento per precompilare il titolo, oppure inserisci i dettagli manualmente qui sotto.'
      : 'Tap an item extracted from the document to pre-fill the title below, or enter details manually.';
  String get noExtractedItemsForThisSection => _it
      ? 'Nessun testo pertinente trovato nel documento estratto.'
      : 'No relevant text found in the extracted document.';
  String get suggestedNewEntitiesSectionTitle => _it
      ? 'Suggerimenti — non ancora nel grafo aziendale'
      : 'Suggested — not yet in the company graph';
  String get suggestedNewEntitiesHint => _it
      ? 'Il documento sembra descrivere un tipo di lavoro senza una corrispondenza esistente. Tocca "Crea e collega" per aggiungerlo all\'Intelligenza aziendale e collegarlo a questo progetto, oppure ignora il suggerimento.'
      : 'The document seems to describe a kind of work with no existing match. Tap "Create & link" to add it to Company Intelligence and link it to this project, or dismiss the suggestion.';
  String get createAndLinkButton => _it ? 'Crea e collega' : 'Create & link';
  String get dismissSuggestionButton => _it ? 'Ignora' : 'Dismiss';
  String get suggestionCreatedAndLinkedLabel =>
      _it ? 'Creato e collegato' : 'Created & linked';
  String get setUpCompanyProfileTitle =>
      _it ? 'Configura il profilo aziendale' : 'Set up company profile';
  String get setUpCompanyProfileEmptyStateMessage => _it
      ? 'L\'Intelligenza aziendale è vuota. Aggiungi alcune business unit, competenze, settori e servizi di base per iniziare a collegare i progetti.'
      : 'Company Intelligence is empty. Add a few core business units, capabilities, industries and services to start linking projects.';
  String get setUpCompanyProfileButton =>
      _it ? 'Configura profilo aziendale' : 'Set up company profile';
  String get setUpCompanyProfileDialogHint => _it
      ? 'Suggerimenti pensati per un\'impresa edile — deseleziona o modifica quelli che non si applicano prima di salvare.'
      : 'Suggestions tailored for a construction contractor — deselect or edit any that don\'t apply before saving.';
  String get companyProfileCreatedMessage =>
      _it ? 'Profilo aziendale creato.' : 'Company profile created.';
  String riskSeverityLabel(RiskSeverity s) {
    if (!_it) return s.label;
    return switch (s) {
      RiskSeverity.low => 'Bassa',
      RiskSeverity.medium => 'Media',
      RiskSeverity.high => 'Alta',
      RiskSeverity.critical => 'Critica',
    };
  }

  String riskLikelihoodLabel(RiskLikelihood l) {
    if (!_it) return l.label;
    return switch (l) {
      RiskLikelihood.low => 'Bassa',
      RiskLikelihood.medium => 'Media',
      RiskLikelihood.high => 'Alta',
    };
  }

  String riskStatusLabel(RiskStatus s) {
    if (!_it) return s.label;
    return switch (s) {
      RiskStatus.open => 'Aperto',
      RiskStatus.mitigated => 'Mitigato',
      RiskStatus.closed => 'Chiuso',
    };
  }

  String deliverableStatusLabel(ProjectDeliverableStatus s) {
    if (!_it) return s.label;
    return switch (s) {
      ProjectDeliverableStatus.pending => 'In sospeso',
      ProjectDeliverableStatus.completed => 'Completata',
      ProjectDeliverableStatus.blocked => 'Bloccata',
    };
  }

  String get projectsNeedingAttentionSectionTitle =>
      _it ? 'Progetti che richiedono attenzione' : 'Projects needing attention';
  String get noProjectsNeedAttentionMessage => _it
      ? 'Tutti i progetti attivi procedono senza problemi.'
      : 'All active projects are on track.';
  String get deliveryWorkspaceSectionTitle => _it
      ? 'Area di lavoro operativa (post-aggiudicazione)'
      : 'Operational Delivery Workspace (post-award)';
  String get deliveryWorkspaceSectionCaption => _it
      ? 'Tracciamento della consegna per un progetto aggiudicato: budget, team, tappe, deliverable, rischi e attività.'
      : 'Delivery tracking for an awarded project: budget, team, milestones, deliverables, risks, and activity.';
  String get deliveryTrackingOptionalSectionTitle => _it
      ? 'Tracciamento della consegna (facoltativo per progetti passati)'
      : 'Delivery tracking (optional for past projects)';
  String get deliveryTrackingOptionalSectionCaption => _it
      ? 'Questo progetto è archiviato come prova di gara. Budget, tappe, deliverable, rischi e attività restano disponibili qui sotto se necessario.'
      : 'This project is archived as bid evidence. Budget, milestones, deliverables, risks, and activity remain available below if needed.';
  String get evidenceOverviewSectionTitle =>
      _it ? 'Panoramica delle prove' : 'Evidence overview';
  String get teamSectionTitle => _it ? 'Team' : 'Team';
  String get projectManagerLabel =>
      _it ? 'Responsabile di progetto' : 'Project manager';
  String get teamMembersLabel => _it ? 'Membri del team' : 'Team members';
  String get workloadLabel => _it ? 'Carico di lavoro' : 'Workload';
  String get recentActivityLabel =>
      _it ? 'Attività recente' : 'Recent activity';
  String get budgetSectionTitle => _it ? 'Budget' : 'Budget';
  String get editBudgetButton => _it ? 'Modifica budget' : 'Edit Budget';
  String get editButton => _it ? 'Modifica' : 'Edit';
  String get currentExpenditureLabel =>
      _it ? 'Spesa attuale' : 'Current expenditure';
  String get forecastAmountLabel =>
      _it ? 'Costo finale previsto' : 'Forecast final cost';
  String get risksSectionTitle => _it ? 'Rischi' : 'Risks';
  String get addRiskButton => _it ? 'Aggiungi rischio' : 'Add Risk';
  String get noRisksMessage =>
      _it ? 'Nessun rischio registrato.' : 'No risks recorded.';
  String get documentsSectionTitle => _it ? 'Documenti' : 'Documents';
  String get documentLibraryIntegrationPendingMessage => _it
      ? 'L\'integrazione con la Libreria Documenti per i progetti sarà collegata in un follow-up rapido.'
      : 'Document Library integration for projects will be wired in a quick follow-up.';
  String get relatedKnowledgeSectionTitle =>
      _it ? 'Conoscenza correlata' : 'Related Knowledge';
  String get similarProjectsLabel =>
      _it ? 'Progetti simili' : 'Similar projects';
  String get noSimilarProjectsMessage =>
      _it ? 'Nessun progetto simile trovato.' : 'No similar projects found.';
  String get lessonsLearnedSectionTitle =>
      _it ? 'Lezioni apprese' : 'Lessons Learned';
  String get lessonsLearnedHint => _it
      ? 'Successi, insuccessi, raccomandazioni, conoscenza riutilizzabile...'
      : 'Successes, failures, recommendations, reusable knowledge...';
  String get publishAsExperienceButton => _it
      ? 'Pubblica come esperienza aziendale'
      : 'Publish as Company Experience';
  String get alreadyPublishedAsExperienceLabel => _it
      ? 'Già pubblicato come esperienza aziendale'
      : 'Already published as Company Experience';

  String get importProjectFromDocumentTitle =>
      _it ? 'Importa da documento' : 'Import from document';
  String get importProjectFromDocumentCaption => _it
      ? 'Carica un contratto, lettera di aggiudicazione o proposta. L\'IA estrae i dettagli del progetto.'
      : 'Upload a contract, award letter, or proposal. AI extracts the project details.';
  String get importProjectButton => _it ? 'Importa' : 'Import';
  String get importProjectCreatingLabel =>
      _it ? 'Creazione progetto…' : 'Creating project…';
  String get importProjectUploadingLabel =>
      _it ? 'Caricamento documento…' : 'Uploading document…';
  String get importProjectExtractingLabel =>
      _it ? 'Estrazione AI in corso…' : 'Extracting with AI…';
  String get newProjectManualCaption => _it
      ? 'Inserisci i dettagli del progetto manualmente'
      : 'Enter project details manually';

  // Product Workspace (first of 7 remaining Company Intelligence workspaces)
  String get noProductDataMessage => _it
      ? 'Nessun dato collegato a questo prodotto ancora.'
      : 'No data linked to this product yet.';
  String get productAiHeadlineNoReviewMessage => _it
      ? 'Nessuna opportunità con revisione strategica completata per questo prodotto ancora.'
      : 'No opportunity with a completed strategic review for this product yet.';

  // Service Workspace (2nd of 7 remaining Company Intelligence workspaces)
  String get noServiceDataMessage => _it
      ? 'Nessun dato collegato a questo servizio ancora.'
      : 'No data linked to this service yet.';
  String get serviceAiHeadlineNoReviewMessage => _it
      ? 'Nessuna opportunità con revisione strategica completata per questo servizio ancora.'
      : 'No opportunity with a completed strategic review for this service yet.';
  String get aiSummaryFailedMessage => _it
      ? 'Generazione della sintesi AI non riuscita. Riprova.'
      : 'AI summary generation failed. Please try again.';

  // Capability Workspace (3rd of 7 remaining Company Intelligence workspaces)
  String get noCapabilityDataMessage => _it
      ? 'Nessun dato collegato a questa capacità ancora.'
      : 'No data linked to this capability yet.';
  String get capabilityAiHeadlineNoReviewMessage => _it
      ? 'Nessuna opportunità con revisione strategica completata per questa capacità ancora.'
      : 'No opportunity with a completed strategic review for this capability yet.';

  // Company Intelligence Workspace shared strings (Product/Service/
  // Capability/Technology/Industry/Experience/Knowledge Article workspaces
  // all reuse these) — added after a full cross-check against
  // product_workspace_screen.dart/service_workspace_screen.dart confirmed
  // they were referenced but never actually defined.
  String get aiExpertiseSummaryTitle =>
      _it ? 'Sintesi AI di competenza' : 'AI Expertise Summary';
  String get generateAiSummaryButton =>
      _it ? 'Genera sintesi AI' : 'Generate AI summary';
  String get refreshAiSummaryButton =>
      _it ? 'Aggiorna sintesi AI' : 'Refresh AI summary';
  String get generatingAiSummaryLabel =>
      _it ? 'Generazione in corso…' : 'Generating…';
  String get noAiExpertiseSummaryMessage => _it
      ? 'Nessuna sintesi AI generata finora. Tocca "Genera sintesi AI" per crearne una.'
      : 'No AI summary generated yet. Tap "Generate AI summary" to create one.';
  String get activeOpportunitiesLabel =>
      _it ? 'Opportunità attive' : 'Active opportunities';
  String get winRateLabel => _it ? 'Tasso di successo' : 'Win rate';
  String get noWinRateYetLabel =>
      _it ? 'Nessuna decisione ancora' : 'No decisions yet';
  String get openSubmissionsLabel => _it ? 'Invii aperti' : 'Open submissions';
  String get averageFitScoreLabel =>
      _it ? 'Punteggio medio di idoneità' : 'Average fit score';
  String get activeOpportunitiesSectionTitle =>
      _it ? 'Opportunità attive' : 'Active Opportunities';
  String get proposalPipelineSectionTitle =>
      _it ? 'Proposte in corso' : 'Proposal Pipeline';
  String get submissionsSectionTitle => _it ? 'Invii' : 'Submissions';
  String get submissionsSubtitle => _it
      ? 'Segui le proposte attraverso revisione, approvazione e invio.'
      : 'Track proposals through review, approval and submission.';
  String get activeProjectsSectionTitle =>
      _it ? 'Progetti attivi' : 'Active Projects';
  String get completedProjectsSectionTitle =>
      _it ? 'Progetti completati' : 'Completed Projects';

  // Technology Workspace (4th of 7 remaining Company Intelligence workspaces)
  String get noTechnologyDataMessage => _it
      ? 'Nessun dato collegato a questa tecnologia ancora.'
      : 'No data linked to this technology yet.';
  String get technologyAiHeadlineNoReviewMessage => _it
      ? 'Nessuna opportunità con revisione strategica completata per questa tecnologia ancora.'
      : 'No opportunity with a completed strategic review for this technology yet.';

  // Industry Workspace (5th of 7 remaining Company Intelligence workspaces)
  String get noIndustryDataMessage => _it
      ? 'Nessun dato collegato a questo settore ancora.'
      : 'No data linked to this industry yet.';
  String get industryAiHeadlineNoReviewMessage => _it
      ? 'Nessuna opportunità con revisione strategica completata per questo settore ancora.'
      : 'No opportunity with a completed strategic review for this industry yet.';

  // Experience Workspace (6th of 7 remaining Company Intelligence workspaces)
  String get noExperienceDataMessage => _it
      ? 'Nessun dato collegato a questa esperienza ancora.'
      : 'No data linked to this experience yet.';
  String get experienceAiHeadlineNoReviewMessage => _it
      ? 'Nessuna opportunità con revisione strategica completata per questa esperienza ancora.'
      : 'No opportunity with a completed strategic review for this experience yet.';
  String get outcomeLabel => _it ? 'Risultato' : 'Outcome';
  String get achievementsLabel => _it ? 'Risultati raggiunti' : 'Achievements';
  String get promotedFromProjectLabel =>
      _it ? 'Promosso dal progetto' : 'Promoted from project';

  // Knowledge Article Workspace (7th and final Company Intelligence workspace)
  String get noKnowledgeArticleDataMessage => _it
      ? 'Nessun dato collegato a questo articolo ancora.'
      : 'No data linked to this article yet.';
  String get knowledgeArticleAiHeadlineNoReviewMessage => _it
      ? 'Nessuna opportunità con revisione strategica completata per questo articolo ancora.'
      : 'No opportunity with a completed strategic review for this article yet.';
  String get showMoreButton => _it ? 'Mostra di più' : 'Show more';
  String get showLessButton => _it ? 'Mostra di meno' : 'Show less';

  // Opportunity <-> Project link (opportunity_workspace_screen.dart).
  // "Project" is used both as a short label when a project already exists
  // (opportunity_workspace_screen.dart) and as a section header above the
  // publish-as-experience action for past projects (project_form_screen.dart)
  // — both read naturally with the same generic word, so one getter covers
  // both rather than adding a near-duplicate.
  String get projectSectionTitle => _it ? 'Progetto' : 'Project';
  String get startProjectButton =>
      _it ? 'Avvia un progetto' : 'Start a Project';
  String get noProjectYetPrompt => _it
      ? 'Nessun progetto avviato — tocca per crearne uno da questa opportunità.'
      : 'No project started yet — tap to create one from this opportunity.';
  String get projectRequiresAwardMessage => _it
      ? 'Impossibile avviare il progetto: questa opportunità non è più nello stato Aggiudicata. Aggiorna lo stato dell\'opportunità prima di riprovare.'
      : 'Cannot start project: this opportunity is no longer in the Awarded state. Refresh the opportunity\'s status before trying again.';

  // Historical Project Upload & AI Knowledge Extraction
  // (project_form_screen.dart, project_extraction_review_screen.dart,
  // upload_project_document_dialog.dart). Upload -> Extract -> Review ->
  // Approve, per the Opportunities-become-Projects intelligence loop.
  String get aiKnowledgeExtractionSectionTitle =>
      _it ? 'Estrazione di conoscenza AI' : 'AI Knowledge Extraction';
  String get uploadDocumentButton =>
      _it ? 'Carica documento' : 'Upload document';
  String get noProjectDocumentsMessage =>
      _it ? 'Nessun documento caricato ancora.' : 'No documents uploaded yet.';
  String get extractingLabel => _it ? 'Estrazione in corso…' : 'Extracting…';
  String get extractKnowledgeButton =>
      _it ? 'Estrai conoscenza' : 'Extract knowledge';
  String get reviewAndApplyButton =>
      _it ? 'Rivedi e applica' : 'Review & apply';
  String get extractionFailedMessage => _it
      ? 'Estrazione della conoscenza non riuscita. Riprova.'
      : 'Knowledge extraction failed. Please try again.';
  String get extractionAppliedMessage => _it
      ? 'Informazioni estratte applicate al progetto.'
      : 'Extracted information applied to the project.';
  String get projectExtractionReviewTitle =>
      _it ? 'Rivedi conoscenza estratta' : 'Review Extracted Knowledge';
  String get extractionBasicInfoSectionTitle =>
      _it ? 'Informazioni di base' : 'Basic Information';
  String get extractionRelationshipsSectionTitle =>
      _it ? 'Relazioni suggerite' : 'Suggested Relationships';
  String get extractionNarrativeSectionTitle =>
      _it ? 'Dettagli narrativi' : 'Narrative Details';
  String get applyButton => _it ? 'Applica' : 'Apply';
  String get alreadySetFieldNote => _it ? 'Già impostato' : 'Already set';
  String get fieldContractDuration =>
      _it ? 'Durata del contratto' : 'Contract duration';
  String get noExtractionDataMessage => _it
      ? 'Nessun dato estratto in questa categoria.'
      : 'No extracted data in this category.';
  String get teamDisciplinesLabel =>
      _it ? 'Discipline del team' : 'Team disciplines';
  String get deliverablesLabel => _it ? 'Consegne' : 'Deliverables';
  String get equipmentLabel => _it ? 'Attrezzatura' : 'Equipment';
  String get extractionRisksLabel =>
      _it ? 'Rischi riscontrati' : 'Risks encountered';
  String get successFactorsLabel =>
      _it ? 'Fattori di successo' : 'Success factors';
  String get extractionLessonsLearnedLabel =>
      _it ? 'Lezioni apprese' : 'Lessons learned';
  String get certificationsLabel => _it ? 'Certificazioni' : 'Certifications';
  String get standardsLabel => _it ? 'Standard' : 'Standards';
  String get keyAchievementsLabel =>
      _it ? 'Risultati chiave' : 'Key achievements';
  String sourceOpportunityLabel(String opportunityTitle) => _it
      ? 'Da opportunità: $opportunityTitle'
      : 'From opportunity: $opportunityTitle';

  // "Add as Experience" here is project_form_screen.dart's own past-project
  // promotion flow — deliberately a separate getter from the existing
  // publishAsExperienceButton (Project Delivery Workspace's own, similarly
  // named action), since they're two different screens/flows that happen
  // to do a similar thing; renaming either to share one getter would risk
  // changing wording in a screen I didn't write and can't verify against.
  String get addAsExperienceButton =>
      _it ? 'Aggiungi come esperienza aziendale' : 'Add as Company Experience';
  String get viewExperienceButton =>
      _it ? 'Visualizza esperienza' : 'View Experience';
  String get addAsExperienceConfirmTitle => _it
      ? 'Pubblicare questo progetto come esperienza aziendale?'
      : 'Publish this project as a Company Experience?';
  String get addAsExperienceConfirmBody => _it
      ? 'Questo crea una nuova voce Esperienza nell\'Intelligenza aziendale a partire dai dettagli di questo progetto. Potrai modificarla in seguito.'
      : 'This creates a new Experience entry in Company Intelligence from '
            'this project\'s details. You can edit it afterward.';
  String get experienceCreatedFromProjectMessage => _it
      ? 'Esperienza creata da questo progetto.'
      : 'Experience created from this project.';

  /// NOTE: `library_document.dart` (the file defining `DocumentExtractionStatus`)
  /// wasn't available to verify its full set of enum values against — only
  /// `.none` and `.reviewed` were confirmed in the files that use this
  /// getter. Written with equality checks rather than a `switch` so it
  /// compiles and degrades gracefully (generic fallback text) for any
  /// additional status value, rather than risking a non-exhaustive-switch
  /// build error from guessing member names that don't exist. If there's a
  /// distinct "extracted, not yet reviewed" status, tell me its exact name
  /// and I'll give it its own precise label.
  String documentExtractionStatusLabel(DocumentExtractionStatus status) {
    if (status == DocumentExtractionStatus.none) {
      return _it ? 'Non estratto' : 'Not extracted';
    }
    if (status == DocumentExtractionStatus.reviewed) {
      return _it ? 'Revisionato e applicato' : 'Reviewed & applied';
    }
    return _it
        ? 'Estrazione in corso o completata'
        : 'Extraction in progress or complete';
  }

  // Submission Workspace (Milestone 4.4)
  String get commandPaletteSubmissionsGroup => _it ? 'Invii' : 'Submissions';
  String get commandPaletteProposalsGroup => _it ? 'Proposte' : 'Proposals';
  String get noOpenSubmissions =>
      _it ? 'Nessun invio aperto' : 'No open submissions';
  String get submissionOverviewSectionTitle =>
      _it ? 'Panoramica invio' : 'Submission Overview';
  String get submissionTimelineSectionTitle =>
      _it ? 'Cronologia invio' : 'Submission Timeline';
  String get executiveSubmissionSummaryTitle =>
      _it ? 'Sintesi esecutiva' : 'Executive Summary';
  String submissionReadinessScoreLabel(num percent) =>
      _it ? 'Punteggio di prontezza: $percent%' : 'Readiness score: $percent%';
  String blockersCountLabel(int count) =>
      _it ? '$count bloccanti' : '$count blocker${count == 1 ? '' : 's'}';
  String approvalsPendingCountLabel(int count) => _it
      ? '$count approvazioni in sospeso'
      : '$count approval${count == 1 ? '' : 's'} pending';
  String get openSubmissionWorkspaceButton =>
      _it ? 'Apri area di lavoro invio' : 'Open Submission Workspace';

  String get validationStatusSectionTitle =>
      _it ? 'Stato di validazione' : 'Validation Status';
  String get validationAllClearMessage => _it
      ? 'Tutti i controlli superati — pronto per l\'invio.'
      : 'All checks passed — ready to submit.';
  String get validationBlockedBannerMessage => _it
      ? 'Alcuni controlli bloccano l\'invio. Risolvili prima di procedere.'
      : 'Some checks are blocking submission. Resolve them before proceeding.';
  String validationCheckLabel(ValidationCheckId id) {
    return switch (id) {
      ValidationCheckId.sectionsComplete =>
        _it ? 'Sezioni complete' : 'Sections complete',
      ValidationCheckId.documentsAttached =>
        _it ? 'Documenti allegati' : 'Documents attached',
      ValidationCheckId.requiredSignatures =>
        _it ? 'Firme richieste' : 'Required signatures',
      ValidationCheckId.metadataComplete =>
        _it ? 'Metadati completi' : 'Metadata complete',
      ValidationCheckId.budgetComplete =>
        _it ? 'Budget completo' : 'Budget complete',
    };
  }

  String validationCheckExplanation(ValidationCheckId id) {
    return switch (id) {
      ValidationCheckId.sectionsComplete =>
        _it
            ? 'Tutte le sezioni della proposta sono state completate.'
            : 'All proposal sections have been completed.',
      ValidationCheckId.documentsAttached =>
        _it
            ? 'I documenti richiesti sono stati allegati alla proposta.'
            : 'Required documents have been attached to the proposal.',
      ValidationCheckId.requiredSignatures =>
        _it
            ? 'Tutti i ruoli richiesti hanno approvato la proposta.'
            : 'All required roles have signed off on the proposal.',
      ValidationCheckId.metadataComplete =>
        _it
            ? 'Le informazioni essenziali della proposta sono complete.'
            : 'Essential proposal information is complete.',
      ValidationCheckId.budgetComplete =>
        _it
            ? 'Le informazioni finanziarie sono complete.'
            : 'Financial information is complete.',
    };
  }

  String get internalApprovalsSectionTitle =>
      _it ? 'Approvazioni interne' : 'Internal Approvals';
  String approvalRoleLabel(ApprovalRole role) {
    if (!_it) return role.label;
    return switch (role) {
      ApprovalRole.technicalLead => 'Responsabile tecnico',
      ApprovalRole.finance => 'Finanza',
      ApprovalRole.legal => 'Legale',
      ApprovalRole.businessDevelopment => 'Sviluppo commerciale',
      ApprovalRole.executiveManagement => 'Direzione esecutiva',
    };
  }

  String approvalDecisionLabel(ApprovalDecision decision) {
    if (!_it) return decision.label;
    return switch (decision) {
      ApprovalDecision.pending => 'In sospeso',
      ApprovalDecision.approved => 'Approvato',
      ApprovalDecision.rejected => 'Rifiutato',
    };
  }

  String get recordApprovalTitle =>
      _it ? 'Registra approvazione' : 'Record Approval';
  String get fieldApproverName =>
      _it ? 'Nome dell\'approvatore' : 'Approver name';
  String get fieldApprovalComment => _it ? 'Commento' : 'Comment';
  String get rejectButton => _it ? 'Rifiuta' : 'Reject';
  String get approveButton => _it ? 'Approva' : 'Approve';

  String get aiSubmissionReviewSectionTitle =>
      _it ? 'Revisione AI invio' : 'AI Submission Review';
  String get regenerateAiReviewButton =>
      _it ? 'Rigenera revisione' : 'Regenerate review';
  String get runAiReviewButton => _it ? 'Esegui revisione' : 'Run AI review';
  String get neverReviewedMessage =>
      _it ? 'Nessuna revisione AI eseguita finora.' : 'No AI review run yet.';
  String get aiReviewFailedMessage => _it
      ? 'Impossibile eseguire la revisione AI. Riprova.'
      : 'Failed to run AI review. Please try again.';
  String submissionReviewReadinessLabel(SubmissionReviewReadiness r) {
    if (!_it) return r.label;
    return switch (r) {
      SubmissionReviewReadiness.ready => 'Pronto',
      SubmissionReviewReadiness.needsWork => 'Richiede lavoro',
      SubmissionReviewReadiness.notReady => 'Non pronto',
    };
  }

  String lastReviewedLabel(String formattedDate) => _it
      ? 'Ultima revisione: $formattedDate'
      : 'Last reviewed: $formattedDate';
  String get missingEvidenceLabel =>
      _it ? 'Prove mancanti' : 'Missing evidence';
  String get weakSectionsLabel => _it ? 'Sezioni deboli' : 'Weak sections';
  String get strongSectionsLabel => _it ? 'Sezioni forti' : 'Strong sections';
  String get complianceConcernsLabel =>
      _it ? 'Problemi di conformità' : 'Compliance concerns';
  String get recommendedImprovementsLabel =>
      _it ? 'Miglioramenti consigliati' : 'Recommended improvements';

  String get submitBlockedTooltip => _it
      ? 'Risolvi i controlli bloccanti prima di inviare.'
      : 'Resolve blocking checks before submitting.';
  String get submitProposalButton => _it ? 'Invia proposta' : 'Submit Proposal';
  String get submitProposalConfirmTitle =>
      _it ? 'Inviare questa proposta?' : 'Submit this proposal?';
  String get submitProposalConfirmBody => _it
      ? 'Questa azione contrassegna la proposta come inviata al cliente. Assicurati che tutti i controlli richiesti siano superati.'
      : 'This marks the proposal as submitted to the client. Make sure all '
            'required checks have passed.';

  /// The Proposal Workspace header's "Submitted" indicator once a proposal
  /// reaches [ProposalStatus.finalized] — deliberately its own getter rather
  /// than reusing [proposalStatusLabel], since that label is about proposal
  /// authoring completeness, not the submission event this indicator shows.
  String get submittedStatusLabel => _it ? 'Inviata' : 'Submitted';

  String submissionMilestoneLabel(SubmissionMilestone milestone) {
    return switch (milestone) {
      SubmissionMilestone.proposalCreated =>
        _it ? 'Proposta creata' : 'Proposal created',
      SubmissionMilestone.aiGenerated =>
        _it ? 'Contenuto AI generato' : 'AI content generated',
      SubmissionMilestone.documentsReady =>
        _it ? 'Documenti pronti' : 'Documents ready',
      SubmissionMilestone.internalReview =>
        _it ? 'Revisione interna' : 'Internal review',
      SubmissionMilestone.managementApproval =>
        _it ? 'Approvazione dirigenziale' : 'Management approval',
      SubmissionMilestone.submissionReady =>
        _it ? 'Pronto per l\'invio' : 'Submission ready',
      SubmissionMilestone.submitted => _it ? 'Inviata' : 'Submitted',
      SubmissionMilestone.evaluation => _it ? 'In valutazione' : 'Evaluation',
      SubmissionMilestone.awardedOrLost =>
        _it ? 'Aggiudicata/Persa' : 'Awarded/Lost',
    };
  }

  // Project Workspace linked-entity chips
  String get sourceOpportunityChipLabel =>
      _it ? 'Da opportunità' : 'From opportunity';
  String get linkedExperienceChipLabel =>
      _it ? 'Esperienza collegata' : 'Linked experience';

  // Company Intelligence — Business Unit Workspace
  String get noBusinessUnitDataMessage => _it
      ? 'Nessun dato disponibile per questa unità aziendale.'
      : 'No data available for this Business Unit yet.';
  String get businessUnitAiHeadlineNoReviewMessage => _it
      ? 'Nessuna analisi AI eseguita finora.'
      : 'No AI review has been run yet.';

  // Dashboard
  String get viewCompanyIntelligenceButton =>
      _it ? 'Visualizza intelligenza aziendale' : 'View Company Intelligence';
}

final appStringsProvider = Provider<AppStrings>(
  (ref) => AppStrings(ref.watch(appLocaleProvider)),
);
